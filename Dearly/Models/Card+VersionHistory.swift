//
//  Card+VersionHistory.swift
//  Dearly
//
//  Created on 1/21/26.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.dearly.app", category: "VersionHistory")

extension Card {
    
    // MARK: - Constants
    
    private static let maxVersions: Int = 10
    
    // MARK: - Snapshot Management
    
    /// Adds a new snapshot to the version history and prunes old versions
    func addSnapshot(metadataChanges: [MetadataChange], imageChanges: [ImageChange]) {
        guard !metadataChanges.isEmpty || !imageChanges.isEmpty else { return }
        
        if versionHistory == nil {
            versionHistory = []
        }
        
        let nextVersionNumber = (versionHistory?.map { $0.versionNumber }.max() ?? 0) + 1
        
        let snapshot = CardVersionSnapshot(
            versionNumber: nextVersionNumber,
            editedAt: Date(),
            metadataChanges: metadataChanges,
            imageChanges: imageChanges
        )
        
        versionHistory?.append(snapshot)
        pruneHistory(using: ImageStorageService.shared)
    }
    
    /// Prunes old versions beyond the limit
    func pruneHistory(using imageStorage: ImageStorageService) {
        guard var history = versionHistory, history.count > Self.maxVersions else { return }
        
        history.sort { $0.versionNumber < $1.versionNumber }
        
        let countToRemove = history.count - Self.maxVersions
        let versionsToRemove = Array(history.prefix(countToRemove))
        
        for version in versionsToRemove {
            deleteVersionFiles(for: version, using: imageStorage)
        }
        
        history.removeFirst(countToRemove)
        self.versionHistory = history
        
        logger.info("Pruned \(countToRemove) old version(s)")
    }
    
    // MARK: - Restore & Delete
    
    /// Deletes a specific snapshot and its files
    func deleteSnapshot(_ snapshot: CardVersionSnapshot, using imageStorage: ImageStorageService = .shared) {
        guard let index = versionHistory?.firstIndex(where: { $0.id == snapshot.id }) else {
            logger.warning("Snapshot not found for deletion: \(snapshot.id)")
            return
        }
        
        deleteVersionFiles(for: snapshot, using: imageStorage)
        versionHistory?.remove(at: index)
        logger.info("Deleted snapshot v\(snapshot.versionNumber)")
    }
    
    /// Restores card to a previous version
    func restore(to snapshot: CardVersionSnapshot, using imageStorage: ImageStorageService = .shared) {
        var newMetadataChanges: [MetadataChange] = []
        var newImageChanges: [ImageChange] = []
        
        // Restore all metadata fields
        for change in snapshot.metadataChanges {
            guard let previousValue = change.previousValue else { continue }
            
            switch change.field {
            case .sender:
                if previousValue != self.sender {
                    newMetadataChanges.append(MetadataChange(
                        field: .sender,
                        previousValue: self.sender,
                        newValue: previousValue
                    ))
                    self.sender = previousValue.isEmpty ? nil : previousValue
                }
                
            case .occasion:
                if previousValue != self.occasion {
                    newMetadataChanges.append(MetadataChange(
                        field: .occasion,
                        previousValue: self.occasion,
                        newValue: previousValue
                    ))
                    self.occasion = previousValue.isEmpty ? nil : previousValue
                }
                
            case .notes:
                if previousValue != self.notes {
                    newMetadataChanges.append(MetadataChange(
                        field: .notes,
                        previousValue: self.notes,
                        newValue: previousValue
                    ))
                    self.notes = previousValue.isEmpty ? nil : previousValue
                }
                
            case .dateReceived:
                // Parse ISO8601 date
                let formatter = ISO8601DateFormatter()
                let newDate = formatter.date(from: previousValue)
                if newDate != self.dateReceived {
                    newMetadataChanges.append(MetadataChange(
                        field: .dateReceived,
                        previousValue: self.dateReceived?.ISO8601Format(),
                        newValue: previousValue
                    ))
                    self.dateReceived = newDate
                }
            }
        }
        
        // Restore all image slots
        for change in snapshot.imageChanges {
            guard let versionUrl = imageStorage.getImageURL(for: change.previousUri),
                  FileManager.default.fileExists(atPath: versionUrl.path) else {
                logger.warning("Version image not found: \(change.previousUri)")
                continue
            }
            
            let currentPath: String?
            switch change.slot {
            case .front: currentPath = self.frontImagePath
            case .back: currentPath = self.backImagePath
            case .insideLeft: currentPath = self.insideLeftImagePath
            case .insideRight: currentPath = self.insideRightImagePath
            }
            
            // Backup current image before overwriting
            if let currentPath = currentPath {
                let nextVersion = (self.versionHistory?.count ?? 0) + 1
                if let backupPath = imageStorage.saveVersionImage(from: currentPath, for: self.id, versionNumber: nextVersion) {
                    newImageChanges.append(ImageChange(slot: change.slot, previousUri: backupPath))
                }
            }
            
            // Restore the old image
            let targetPath = "CardImages/\(self.id.uuidString)/\(change.slot.rawValue).jpg"
            if let targetUrl = imageStorage.getImageURL(for: targetPath) {
                do {
                    if FileManager.default.fileExists(atPath: targetUrl.path) {
                        try FileManager.default.removeItem(at: targetUrl)
                    }
                    try FileManager.default.copyItem(at: versionUrl, to: targetUrl)
                    
                    // Update card path
                    switch change.slot {
                    case .front: self.frontImagePath = targetPath
                    case .back: self.backImagePath = targetPath
                    case .insideLeft: self.insideLeftImagePath = targetPath
                    case .insideRight: self.insideRightImagePath = targetPath
                    }
                    
                    logger.info("Restored \(change.slot.rawValue) image")
                } catch {
                    logger.error("Failed to restore image: \(error.localizedDescription)")
                }
            }
        }
        
        // Record the restore action as a new snapshot
        if !newMetadataChanges.isEmpty || !newImageChanges.isEmpty {
            addSnapshot(metadataChanges: newMetadataChanges, imageChanges: newImageChanges)
        }
    }
    
    /// Deletes version files
    private func deleteVersionFiles(for snapshot: CardVersionSnapshot, using imageStorage: ImageStorageService) {
        for change in snapshot.imageChanges {
            imageStorage.deleteVersionImage(at: change.previousUri)
        }
        imageStorage.deleteVersion(for: id, versionNumber: snapshot.versionNumber)
    }
    
    // MARK: - Helper Methods
    
    /// Creates a MetadataChange if values differ
    static func compare(_ field: MetadataField, old: String?, new: String?) -> MetadataChange? {
        guard old != new else { return nil }
        return MetadataChange(field: field, previousValue: old, newValue: new)
    }
    
    /// Creates a MetadataChange for dates if they differ
    static func compare(_ field: MetadataField, old: Date?, new: Date?) -> MetadataChange? {
        guard old != new else { return nil }
        return MetadataChange(
            field: field,
            previousValue: old?.ISO8601Format(),
            newValue: new?.ISO8601Format()
        )
    }
}

