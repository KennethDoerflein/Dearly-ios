//
//  Card+VersionHistory.swift
//  Dearly
//
//  Created on 1/21/26.
//

import Foundation
import UIKit
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
    
    /// Restores card by undoing the changes in a specific version snapshot
    func restore(to snapshot: CardVersionSnapshot, using imageStorage: ImageStorageService = .shared) {
        var newMetadataChanges: [MetadataChange] = []
        var newImageChanges: [ImageChange] = []
        
        // Undo metadata changes: restore each field to its previousValue
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
            
            guard let restoredImageData = try? Data(contentsOf: versionUrl) else {
                 logger.error("Failed to load image data from version file: \(versionUrl)")
                 continue
            }
            
            let currentData: Data?
            switch change.slot {
            case .front: currentData = self.frontImageData
            case .back: currentData = self.backImageData
            case .insideLeft: currentData = self.insideLeftImageData
            case .insideRight: currentData = self.insideRightImageData
            }
            
            if let currentData = currentData, let currentImage = UIImage(data: currentData) {
                let nextVersion = (self.versionHistory?.count ?? 0) + 1
                
                if let backupPath = saveImageToVersionHistory(image: currentImage, cardId: self.id, versionNumber: nextVersion, originalFileName: "\(change.slot.rawValue).jpg") {
                    newImageChanges.append(ImageChange(slot: change.slot, previousUri: backupPath))
                }
            }
            
            switch change.slot {
            case .front: self.frontImageData = restoredImageData
            case .back: self.backImageData = restoredImageData
            case .insideLeft: self.insideLeftImageData = restoredImageData
            case .insideRight: self.insideRightImageData = restoredImageData
            }
            
            logger.info("Restored \(change.slot.rawValue) image")
        }
        
        // Record the restore action as a new snapshot
        if !newMetadataChanges.isEmpty || !newImageChanges.isEmpty {
            addSnapshot(metadataChanges: newMetadataChanges, imageChanges: newImageChanges)
        }
    }
    
    /// Helper to save a UIImage directly to version history
    private func saveImageToVersionHistory(image: UIImage, cardId: UUID, versionNumber: Int, originalFileName: String) -> String? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagesDirectory = documentsDirectory.appendingPathComponent("CardImages", isDirectory: true)
        
        let versionDirName = "v\(versionNumber)"
        let cardVersionsDir = imagesDirectory
            .appendingPathComponent(cardId.uuidString, isDirectory: true)
            .appendingPathComponent("versions", isDirectory: true)
            .appendingPathComponent(versionDirName, isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: cardVersionsDir.path) {
                try fileManager.createDirectory(at: cardVersionsDir, withIntermediateDirectories: true)
            }
            
            let destinationURL = cardVersionsDir.appendingPathComponent(originalFileName)
            
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: destinationURL)
                return "CardImages/\(cardId.uuidString)/versions/\(versionDirName)/\(originalFileName)"
            }
            return nil
        } catch {
            logger.error("Failed to save version image directly: \(error.localizedDescription)")
            return nil
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

