//
//  iCloudBackupService.swift
//  Dearly
//
//  Service for syncing cards to/from iCloud Drive as individual .dearly files
//

import Foundation
import UIKit
import SwiftData

// MARK: - Backup Errors

enum iCloudBackupError: LocalizedError {
    case iCloudNotAvailable
    case syncFailed(String)
    case restoreFailed(String)
    case noCardsInCloud
    case fileOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available. Please sign in to iCloud in Settings and try again."
        case .syncFailed(let reason):
            return "Failed to sync: \(reason)"
        case .restoreFailed(let reason):
            return "Failed to restore: \(reason)"
        case .noCardsInCloud:
            return "No cards found in iCloud."
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        }
    }
}

// MARK: - iCloud Backup Service

/// Service for syncing cards to iCloud Drive as individual .dearly files
final class iCloudBackupService {
    
    /// Shared singleton instance
    static let shared = iCloudBackupService()
    
    /// FileManager instance
    private let fileManager = FileManager.default
    
    /// DearlyFileService for export/import operations
    private let dearlyFileService = DearlyFileService.shared
    
    /// Sync manifest filename
    private let syncManifestFilename = ".sync-manifest.json"
    
    /// UserDefaults key for last sync date
    private let lastSyncDateKey = "lastICloudSyncDate"
    
    private init() {}
    
    // MARK: - iCloud Availability
    
    /// Checks if iCloud is available on this device
    var isICloudAvailable: Bool {
        return fileManager.ubiquityIdentityToken != nil
    }
    
    /// Gets the iCloud Documents container URL
    private var iCloudDocumentsURL: URL? {
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.mauroapps.Dearly") else {
            return nil
        }
        return containerURL.appendingPathComponent("Documents", isDirectory: true)
    }
    
    /// Gets the Cards folder URL in iCloud
    private var cardsDirectoryURL: URL? {
        return iCloudDocumentsURL?.appendingPathComponent("Cards", isDirectory: true)
    }
    
    /// Gets the sync manifest URL
    private var syncManifestURL: URL? {
        return cardsDirectoryURL?.appendingPathComponent(syncManifestFilename)
    }
    
    // MARK: - Last Sync Date
    
    /// Gets the date of the last successful sync
    var lastSyncDate: Date? {
        return UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date
    }
    
    /// Sets the last sync date
    private func setLastSyncDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastSyncDateKey)
    }
    
    // MARK: - Sync to iCloud
    
    /// Syncs all cards to iCloud as individual .dearly files
    /// - Parameter cards: Array of cards to sync
    /// - Returns: SyncResult with counts of uploaded/skipped/failed
    @MainActor
    func syncToCloud(cards: [Card]) async throws -> SyncResult {
        guard isICloudAvailable else {
            throw iCloudBackupError.iCloudNotAvailable
        }
        
        guard let cardsDir = cardsDirectoryURL else {
            throw iCloudBackupError.iCloudNotAvailable
        }
        
        // Ensure Cards directory exists in iCloud
        if !fileManager.fileExists(atPath: cardsDir.path) {
            try fileManager.createDirectory(at: cardsDir, withIntermediateDirectories: true)
        }
        
        // Load existing sync manifest
        var manifest = loadSyncManifest() ?? SyncManifest()
        
        var uploaded = 0
        var skipped = 0
        var failed = 0
        var errors: [String] = []
        
        for card in cards {
            let cardIdString = card.id.uuidString
            
            // Check if card needs syncing
            if let existingInfo = manifest.cards[cardIdString] {
                // Card exists in manifest - check if it's been updated
                let cardUpdatedAt = card.updatedAt ?? card.dateScanned
                let isoFormatter = ISO8601DateFormatter()
                let existingUpdatedAt = existingInfo.cardUpdatedAt.flatMap { isoFormatter.date(from: $0) }
                
                if let existingDate = existingUpdatedAt, cardUpdatedAt <= existingDate {
                    // Card hasn't changed since last sync
                    skipped += 1
                    continue
                }
                
                // Card has been updated - delete old file if filename changed
                let newFilename = generateFilename(for: card)
                if existingInfo.filename != newFilename {
                    let oldFileURL = cardsDir.appendingPathComponent(existingInfo.filename)
                    try? fileManager.removeItem(at: oldFileURL)
                }
            }
            
            // Export card to .dearly file
            do {
                let exportedURL = try dearlyFileService.exportCard(card)
                let filename = generateFilename(for: card)
                let destinationURL = cardsDir.appendingPathComponent(filename)
                
                // Remove existing file if present
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                
                // Copy to iCloud
                try fileManager.copyItem(at: exportedURL, to: destinationURL)
                
                // Clean up local export
                try? fileManager.removeItem(at: exportedURL)
                
                // Update manifest
                let isoFormatter = ISO8601DateFormatter()
                let cardUpdatedAt = card.updatedAt ?? card.dateScanned
                manifest.cards[cardIdString] = SyncedCardInfo(
                    filename: filename,
                    syncedAt: isoFormatter.string(from: Date()),
                    cardUpdatedAt: isoFormatter.string(from: cardUpdatedAt)
                )
                
                uploaded += 1
                print("✅ Synced card: \(filename)")
                
            } catch {
                failed += 1
                errors.append("Failed to sync \(card.sender ?? "card"): \(error.localizedDescription)")
                print("❌ Failed to sync card \(cardIdString): \(error.localizedDescription)")
            }
        }
        
        // Save updated manifest
        manifest.lastSyncDate = ISO8601DateFormatter().string(from: Date())
        saveSyncManifest(manifest)
        
        // Update last sync date
        setLastSyncDate(Date())
        
        print("✅ Sync complete: \(uploaded) uploaded, \(skipped) skipped, \(failed) failed")
        
        return SyncResult(uploaded: uploaded, skipped: skipped, failed: failed, errors: errors)
    }
    
    // MARK: - Get Cloud Info
    
    /// Gets information about cards stored in iCloud
    func getCloudInfo() async -> (cardCount: Int, totalSize: Int64, cards: [CloudCardInfo])? {
        guard isICloudAvailable,
              let cardsDir = cardsDirectoryURL,
              fileManager.fileExists(atPath: cardsDir.path) else {
            return nil
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cardsDir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
            )
            
            var cloudCards: [CloudCardInfo] = []
            var totalSize: Int64 = 0
            
            for fileURL in contents {
                // Only process .dearly files
                guard fileURL.pathExtension.lowercased() == "dearly" else {
                    continue
                }
                
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                let modDate = resourceValues.contentModificationDate ?? Date()
                
                totalSize += fileSize
                
                cloudCards.append(CloudCardInfo(
                    filename: fileURL.lastPathComponent,
                    url: fileURL,
                    modifiedDate: modDate,
                    fileSize: fileSize
                ))
            }
            
            // Sort by modification date, newest first
            cloudCards.sort { $0.modifiedDate > $1.modifiedDate }
            
            return (cardCount: cloudCards.count, totalSize: totalSize, cards: cloudCards)
            
        } catch {
            print("❌ Failed to get cloud info: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Restore from iCloud
    
    /// Restores cards from iCloud
    /// - Parameters:
    ///   - modelContext: SwiftData model context for saving cards
    ///   - replaceExisting: If true, deletes all existing local cards first
    /// - Returns: RestoreResult with counts
    @MainActor
    func restoreFromCloud(modelContext: ModelContext, replaceExisting: Bool = false) async throws -> RestoreResult {
        guard isICloudAvailable else {
            throw iCloudBackupError.iCloudNotAvailable
        }
        
        guard let cardsDir = cardsDirectoryURL,
              fileManager.fileExists(atPath: cardsDir.path) else {
            throw iCloudBackupError.noCardsInCloud
        }
        
        // Get all .dearly files in iCloud
        let contents = try fileManager.contentsOfDirectory(at: cardsDir, includingPropertiesForKeys: nil)
        let dearlyFiles = contents.filter { $0.pathExtension.lowercased() == "dearly" }
        
        if dearlyFiles.isEmpty {
            throw iCloudBackupError.noCardsInCloud
        }
        
        // STEP 1: Create temp directory and copy ALL files from iCloud first
        // This ensures we have the files downloaded and readable BEFORE deleting anything
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("dearly-restore-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temp directory when done
            try? fileManager.removeItem(at: tempDir)
        }
        
        var tempFiles: [URL] = []
        var copyErrors: [String] = []
        
        print("📥 Downloading \(dearlyFiles.count) files from iCloud...")
        
        for fileURL in dearlyFiles {
            do {
                // Trigger iCloud download if needed
                try await downloadICloudFileIfNeeded(at: fileURL)
                
                // Copy to temp directory
                let tempFileURL = tempDir.appendingPathComponent(fileURL.lastPathComponent)
                try fileManager.copyItem(at: fileURL, to: tempFileURL)
                
                // Validate the copied file is readable
                let validationResult = dearlyFileService.validateFile(at: tempFileURL)
                switch validationResult {
                case .success:
                    tempFiles.append(tempFileURL)
                    print("✅ Downloaded and validated: \(fileURL.lastPathComponent)")
                case .failure(let error):
                    copyErrors.append("Invalid file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    print("⚠️ Invalid file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            } catch {
                copyErrors.append("Failed to download \(fileURL.lastPathComponent): \(error.localizedDescription)")
                print("⚠️ Failed to download \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // If we couldn't get ANY valid files, abort without deleting anything
        if tempFiles.isEmpty {
            let errorMessage = copyErrors.isEmpty 
                ? "Could not read any files from iCloud. Files may still be downloading."
                : copyErrors.joined(separator: "\n")
            throw iCloudBackupError.restoreFailed(errorMessage)
        }
        
        // STEP 2: Now that we have valid files, optionally clear existing data
        if replaceExisting {
            print("🗑️ Clearing existing local cards...")
            let existingCards = try modelContext.fetch(FetchDescriptor<Card>())
            for card in existingCards {
                // Images are stored directly in SwiftData with @Attribute(.externalStorage)
                // so they're deleted automatically when the model is deleted
                modelContext.delete(card)
            }
            try modelContext.save()
        }
        
        // STEP 3: Import from temp copies (which we know are readable)
        var imported = 0
        var skipped = 0
        var failed = 0
        var errors: [String] = copyErrors // Include any files that failed to download
        
        for tempFileURL in tempFiles {
            do {
                let card = try dearlyFileService.importCard(from: tempFileURL, using: modelContext)
                imported += 1
                print("✅ Imported: \(tempFileURL.lastPathComponent)")
            } catch {
                failed += 1
                errors.append("Failed to import \(tempFileURL.lastPathComponent): \(error.localizedDescription)")
                print("❌ Failed to import \(tempFileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        print("✅ Restore complete: \(imported) imported, \(skipped) skipped, \(failed) failed")
        
        return RestoreResult(imported: imported, skipped: skipped, failed: failed, errors: errors)
    }
    
    /// Downloads an iCloud file if it's not yet available locally
    private func downloadICloudFileIfNeeded(at url: URL) async throws {
        // Check if file needs to be downloaded
        var isDownloaded = false
        var isDownloading = false
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                isDownloaded = (status == .current)
                isDownloading = (status == .downloaded)
            }
        } catch {
            // If we can't get resource values, try to read the file directly
            // This might work for local files or files that don't have ubiquitous attributes
        }
        
        if isDownloaded {
            return // File is already available
        }
        
        // Trigger download
        do {
            try fileManager.startDownloadingUbiquitousItem(at: url)
        } catch {
            // Ignore error - file might not be ubiquitous or already downloaded
        }
        
        // Wait for download with timeout
        let maxWaitTime: TimeInterval = 30 // 30 second timeout
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            // Check if we can read the file
            if let _ = try? Data(contentsOf: url, options: .mappedIfSafe) {
                return // File is readable
            }
            
            // Wait a bit before checking again
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Try one final time to read the file
        let _ = try Data(contentsOf: url)
    }
    
    // MARK: - Delete from Cloud
    
    /// Deletes a specific card from iCloud
    /// - Parameter cardId: The card ID to delete
    func deleteCardFromCloud(cardId: UUID) throws {
        guard let cardsDir = cardsDirectoryURL else { return }
        
        var manifest = loadSyncManifest()
        
        if let syncInfo = manifest?.cards[cardId.uuidString] {
            let fileURL = cardsDir.appendingPathComponent(syncInfo.filename)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                print("✅ Deleted from iCloud: \(syncInfo.filename)")
            }
            
            // Remove from manifest
            manifest?.cards.removeValue(forKey: cardId.uuidString)
            if let updatedManifest = manifest {
                saveSyncManifest(updatedManifest)
            }
        }
    }
    
    /// Deletes all cards from iCloud
    func deleteAllFromCloud() throws {
        guard let cardsDir = cardsDirectoryURL,
              fileManager.fileExists(atPath: cardsDir.path) else {
            return
        }
        
        // Remove the entire Cards directory
        try fileManager.removeItem(at: cardsDir)
        
        // Clear the last sync date
        UserDefaults.standard.removeObject(forKey: lastSyncDateKey)
        
        print("✅ Deleted all cards from iCloud")
    }
    
    // MARK: - Private Helpers
    
    /// Generates a filename for a card
    private func generateFilename(for card: Card) -> String {
        // Sanitize sender name
        var senderPart = (card.sender ?? "Card")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        // Limit length
        if senderPart.count > 20 {
            senderPart = String(senderPart.prefix(20))
        }
        
        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let datePart = dateFormatter.string(from: card.dateReceived ?? card.dateScanned)
        
        // Add short UUID suffix to ensure uniqueness
        let uuidSuffix = String(card.id.uuidString.prefix(8))
        
        return "\(senderPart)_\(datePart)_\(uuidSuffix).dearly"
    }
    
    /// Loads the sync manifest from iCloud
    private func loadSyncManifest() -> SyncManifest? {
        guard let manifestURL = syncManifestURL,
              fileManager.fileExists(atPath: manifestURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: manifestURL)
            return try JSONDecoder().decode(SyncManifest.self, from: data)
        } catch {
            print("⚠️ Failed to load sync manifest: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Saves the sync manifest to iCloud
    private func saveSyncManifest(_ manifest: SyncManifest) {
        guard let manifestURL = syncManifestURL else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifest)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            print("⚠️ Failed to save sync manifest: \(error.localizedDescription)")
        }
    }
}

// MARK: - Legacy Support

extension iCloudBackupService {
    /// Gets the legacy backup info (for migration)
    /// Returns nil if no legacy backup exists
    func getLegacyBackupInfo() async -> BackupInfo? {
        guard let iCloudDocsURL = iCloudDocumentsURL else { return nil }
        
        let legacyBackupURL = iCloudDocsURL.appendingPathComponent("dearly-backup.zip")
        guard fileManager.fileExists(atPath: legacyBackupURL.path) else {
            return nil
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: legacyBackupURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let modDate = attributes[.modificationDate] as? Date ?? Date()
            
            return BackupInfo(
                backupDate: modDate,
                cardCount: 0, // Unknown without parsing
                appVersion: "legacy",
                fileSize: fileSize,
                fileURL: legacyBackupURL
            )
        } catch {
            return nil
        }
    }
    
    /// Deletes the legacy backup file
    func deleteLegacyBackup() throws {
        guard let iCloudDocsURL = iCloudDocumentsURL else { return }
        
        let legacyBackupURL = iCloudDocsURL.appendingPathComponent("dearly-backup.zip")
        if fileManager.fileExists(atPath: legacyBackupURL.path) {
            try fileManager.removeItem(at: legacyBackupURL)
            print("✅ Deleted legacy backup")
        }
    }
}
