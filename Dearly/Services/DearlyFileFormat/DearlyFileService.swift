//
//  DearlyFileService.swift
//  Dearly
//
//  Main service for exporting and importing .dearly files
//

import Foundation
import UIKit
import SwiftData

/// Service for exporting and importing cards in the .dearly file format
final class DearlyFileService {
    
    /// Shared singleton instance
    static let shared = DearlyFileService()
    
    /// File manager instance
    private let fileManager = FileManager.default
    
    /// Image storage service
    private let imageStorage = ImageStorageService.shared
    
    /// Supported image extensions
    private let supportedImageExtensions = ["jpg", "jpeg", "png", "webp", "heic"]
    
    private init() {}
    
    // MARK: - Export
    
    /// Exports a card to a .dearly file
    /// - Parameter card: The card to export
    /// - Parameter includeHistory: Whether to include version history (default: true)
    /// - Returns: URL to the exported .dearly file
    /// - Throws: DearlyFileError if export fails
    func exportCard(_ card: Card, includeHistory: Bool = true) throws -> URL {
        // Create temporary directory for building the archive
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temp directory
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Front image (required)
        guard let frontImage = card.frontImage,
              let frontData = frontImage.jpegData(compressionQuality: 0.9) else {
            throw DearlyFileError.exportError("Front image is required but not available")
        }
        let frontFilename = "front.jpg"
        try frontData.write(to: tempDir.appendingPathComponent(frontFilename))
        
        // Back image (required)
        guard let backImage = card.backImage,
              let backData = backImage.jpegData(compressionQuality: 0.9) else {
            throw DearlyFileError.exportError("Back image is required but not available")
        }
        let backFilename = "back.jpg"
        try backData.write(to: tempDir.appendingPathComponent(backFilename))
        
        // Inside left image (optional)
        var insideLeftFilename: String? = nil
        if let insideLeftImage = card.insideLeftImage,
           let insideLeftData = insideLeftImage.jpegData(compressionQuality: 0.9) {
            insideLeftFilename = "inside_left.jpg"
            try insideLeftData.write(to: tempDir.appendingPathComponent(insideLeftFilename!))
        }
        
        // Inside right image (optional)
        var insideRightFilename: String? = nil
        if let insideRightImage = card.insideRightImage,
           let insideRightData = insideRightImage.jpegData(compressionQuality: 0.9) {
            insideRightFilename = "inside_right.jpg"
            try insideRightData.write(to: tempDir.appendingPathComponent(insideRightFilename!))
        }
        
        let images = DearlyImages(
            front: frontFilename,
            back: backFilename,
            insideLeft: insideLeftFilename,
            insideRight: insideRightFilename
        )
        
        // Build version history for manifest (spec-compliant format)
        var dearlyHistory: [DearlyVersionSnapshot]? = nil
        if includeHistory, let history = card.versionHistory, !history.isEmpty {
            dearlyHistory = history.map { DearlyVersionSnapshot.from($0) }
        }
        
        // Build manifest
        let cardData = DearlyCardData.from(card)
        let manifest = DearlyManifest(card: cardData, images: images, versionHistory: dearlyHistory)
        
        // Write manifest.json
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))
        
        // Export Version History Images
        if includeHistory, let history = card.versionHistory {
            for snapshot in history {
                for change in snapshot.imageChanges {
                    // change.previousUri is relative path like "CardImages/{cardId}/versions/v1/front.jpg"
                    // We want to store it in ZIP as "versions/v1/front.jpg"
                    
                    // 1. Locate source file
                    if let sourceURL = imageStorage.getImageURL(for: change.previousUri),
                       fileManager.fileExists(atPath: sourceURL.path) {
                        
                        // 2. Determine dest path in ZIP
                        // We strip the prefix "CardImages/{uuid}/" if present to get clean relative path
                        let relativePath: String
                        if change.previousUri.contains("/versions/") {
                             let components = change.previousUri.components(separatedBy: "/versions/")
                             if components.count > 1 {
                                 relativePath = "versions/" + components[1]
                             } else {
                                 continue
                             }
                        } else {
                            continue
                        }
                        
                        let destURL = tempDir.appendingPathComponent(relativePath)
                        
                        // Create subdirectories
                        try fileManager.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        
                        // Copy file
                        try fileManager.copyItem(at: sourceURL, to: destURL)
                    }
                }
            }
        }
        
        // Create ZIP archive
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsDir = documentsDir.appendingPathComponent("Exports", isDirectory: true)
        try fileManager.createDirectory(at: exportsDir, withIntermediateDirectories: true)
        
        // Generate filename from card metadata
        let senderPart = card.sender?.replacingOccurrences(of: " ", with: "_")
            .prefix(20) ?? "card"
        let datePart = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: card.dateReceived ?? card.dateScanned)
        }()
        let exportFilename = "\(senderPart)_\(datePart).dearly"
        let exportURL = exportsDir.appendingPathComponent(exportFilename)
        
        // Remove existing file if present
        if fileManager.fileExists(atPath: exportURL.path) {
            try fileManager.removeItem(at: exportURL)
        }
        
        // Create the ZIP archive using native approach
        try createZipArchive(from: tempDir, to: exportURL)
        
        print("✅ Exported card to: \(exportURL.path)")
        return exportURL
    }
    
    // MARK: - Unified Import
    
    /// Result of a unified import operation
    enum ImportResult {
        /// Single card was imported directly
        case singleCard(Card)
        /// Backup bundle detected - returns previews for selection
        case backupBundle([BundlePreview])
    }
    
    /// Detects the file type and either imports a single card or returns previews for a backup bundle
    /// - Parameters:
    ///   - url: URL to the .dearly file
    ///   - modelContext: SwiftData model context for saving the card (used for single card import)
    /// - Returns: ImportResult indicating what was imported or previews for selection
    /// - Throws: DearlyFileError if file cannot be read
    func detectAndImport(from url: URL, using modelContext: ModelContext) throws -> ImportResult {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        try extractZipArchive(from: url, to: tempDir)
        
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw DearlyFileError.missingManifest
        }
        
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(DearlyManifest.self, from: manifestData)
        
        if manifest.formatVersion > DearlyFormatVersion {
            throw DearlyFileError.unsupportedVersion(manifest.formatVersion)
        }
        
        // Check if this is a backup bundle
        if manifest.bundleType == .backup || manifest.cards != nil {
            // Return previews for backup bundle
            guard let cards = manifest.cards, !cards.isEmpty else {
                throw DearlyFileError.invalidManifest("Backup bundle has no cards")
            }
            
            var previews: [BundlePreview] = []
            
            for cardData in cards {
                var thumbnail: Data? = nil
                let frontImageURL = tempDir.appendingPathComponent(cardData.images.front)
                if fileManager.fileExists(atPath: frontImageURL.path) {
                    thumbnail = try? Data(contentsOf: frontImageURL)
                }
                
                previews.append(BundlePreview(
                    id: cardData.id,
                    sender: cardData.sender,
                    occasion: cardData.occasion,
                    date: cardData.date,
                    thumbnailData: thumbnail
                ))
            }
            
            return .backupBundle(previews)
        }
        
        // Single card import - import directly
        let card = try importCard(from: url, using: modelContext)
        return .singleCard(card)
    }
    
    // MARK: - Import (Single Card)
    
    /// Imports a card from a .dearly file
    /// - Parameters:
    ///   - url: URL to the .dearly file
    ///   - modelContext: SwiftData model context for saving the card
    /// - Returns: The imported Card
    /// - Throws: DearlyFileError if import fails
    func importCard(from url: URL, using modelContext: ModelContext) throws -> Card {
        // Create temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temp directory
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Extract the archive
        try extractZipArchive(from: url, to: tempDir)
        
        // Parse and validate manifest
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw DearlyFileError.missingManifest
        }
        
        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        let manifest: DearlyManifest
        do {
            manifest = try decoder.decode(DearlyManifest.self, from: manifestData)
        } catch {
            throw DearlyFileError.invalidManifest(error.localizedDescription)
        }
        
        // Validate version
        if manifest.formatVersion > DearlyFormatVersion {
            throw DearlyFileError.unsupportedVersion(manifest.formatVersion)
        }
        
        // Check if this is a backup bundle
        if manifest.bundleType == .backup || manifest.cards != nil {
            throw DearlyFileError.backupBundleDetected
        }
        
        // Validate single-card structure
        guard let cardData = manifest.card, let images = manifest.images else {
            throw DearlyFileError.invalidManifest("Missing card or images data for single card import")
        }
        
        // Generate new UUID per spec requirement
        let newCardId = UUID()
        
        // Extract and save images
        let frontPath = try saveImportedImage(
            filename: images.front,
            from: tempDir,
            cardId: newCardId,
            side: .front
        )
        
        let backPath = try saveImportedImage(
            filename: images.back,
            from: tempDir,
            cardId: newCardId,
            side: .back
        )
        
        var insideLeftPath: String? = nil
        if let insideLeftFilename = images.insideLeft {
            insideLeftPath = try saveImportedImage(
                filename: insideLeftFilename,
                from: tempDir,
                cardId: newCardId,
                side: .insideLeft
            )
        }
        
        var insideRightPath: String? = nil
        if let insideRightFilename = images.insideRight {
            insideRightPath = try saveImportedImage(
                filename: insideRightFilename,
                from: tempDir,
                cardId: newCardId,
                side: .insideRight
            )
        }
        
        // Processing Version History Import (from top-level per spec)
        var importedHistory: [CardVersionSnapshot]? = nil
        
        if let dearlyHistory = manifest.versionHistory, !dearlyHistory.isEmpty {
            var history: [CardVersionSnapshot] = []
            
            for dearlySnapshot in dearlyHistory {
                var updatedImageChanges: [ImageChange] = []
                
                for dearlyChange in dearlySnapshot.imageChanges {
                    // dearlyChange.previousFilename is relative path like "versions/v1/front.jpg"
                    let sourceURL = tempDir.appendingPathComponent(dearlyChange.previousFilename)
                    
                    if fileManager.fileExists(atPath: sourceURL.path) {
                        let versionDirName = "v\(dearlySnapshot.versionNumber)"
                        let fileName = sourceURL.lastPathComponent
                        
                        let cardVersionsDir = imageStorage.getImageURL(for: "")!
                            .appendingPathComponent("CardImages")
                            .appendingPathComponent(newCardId.uuidString)
                            .appendingPathComponent("versions")
                            .appendingPathComponent(versionDirName)
                        
                        do {
                            try fileManager.createDirectory(at: cardVersionsDir, withIntermediateDirectories: true)
                            let destURL = cardVersionsDir.appendingPathComponent(fileName)
                            
                            try fileManager.copyItem(at: sourceURL, to: destURL)
                            
                            let newPath = "CardImages/\(newCardId.uuidString)/versions/\(versionDirName)/\(fileName)"
                            let slotEnum = ImageSlot(rawValue: dearlyChange.slot) ?? .front
                            updatedImageChanges.append(ImageChange(slot: slotEnum, previousUri: newPath))
                        } catch {
                            print("⚠️ Failed to import version image: \(error)")
                        }
                    }
                }
                
                // Convert to internal format
                let isoFormatter = ISO8601DateFormatter()
                let snapshot = CardVersionSnapshot(
                    versionNumber: dearlySnapshot.versionNumber,
                    editedAt: isoFormatter.date(from: dearlySnapshot.editedAt) ?? Date(),
                    metadataChanges: dearlySnapshot.metadataChanges.map { $0.toMetadataChange() },
                    imageChanges: updatedImageChanges
                )
                history.append(snapshot)
            }
            importedHistory = history
        }
        
        // Parse dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let cardDate = dateFormatter.date(from: cardData.date)
        
        let isoFormatter = ISO8601DateFormatter()
        let createdAt = cardData.createdAt.flatMap { isoFormatter.date(from: $0) }
        let updatedAt = cardData.updatedAt.flatMap { isoFormatter.date(from: $0) }
        
        // Create the new card
        let card = Card(
            id: newCardId,
            frontImagePath: frontPath,
            backImagePath: backPath,
            insideLeftImagePath: insideLeftPath,
            insideRightImagePath: insideRightPath,
            dateScanned: Date(),
            isFavorite: cardData.isFavorite,
            sender: cardData.sender,
            occasion: cardData.occasion,
            dateReceived: cardDate,
            notes: cardData.notes,
            versionHistory: importedHistory
        )
        
        // Set extended properties
        card.cardType = cardData.type?.rawValue
        card.aspectRatio = cardData.aspectRatio
        card.createdAt = createdAt ?? Date()
        card.updatedAt = updatedAt
        
        // Set AI extraction data if present
        if let aiData = cardData.aiExtractedData {
            card.aiExtractedText = aiData.extractedText
            card.aiDetectedSender = aiData.detectedSender
            card.aiDetectedOccasion = aiData.detectedOccasion
            card.aiSentiment = aiData.sentiment
            card.aiMentionedDates = aiData.mentionedDates
            card.aiKeywords = aiData.keywords
            card.aiExtractionStatus = aiData.status.rawValue
            card.aiLastExtractedAt = aiData.lastExtractedAt.flatMap { isoFormatter.date(from: $0) }
            card.aiProcessingStartedAt = aiData.processingStartedAt.flatMap { isoFormatter.date(from: $0) }
            
            // Set error data if present
            if let error = aiData.error {
                card.aiErrorType = error.type.rawValue
                card.aiErrorMessage = error.message
                card.aiErrorRetryable = error.retryable
            }
        }
        
        // Save to SwiftData
        modelContext.insert(card)
        try modelContext.save()
        
        print("✅ Imported card: \(newCardId)")
        return card
    }
    
    // MARK: - Validation
    
    /// Validates a .dearly file without importing
    /// - Parameter url: URL to the .dearly file
    /// - Returns: Result with the parsed manifest or an error
    func validateFile(at url: URL) -> Result<DearlyManifest, DearlyFileError> {
        do {
            // Create temporary directory for extraction
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            defer {
                try? fileManager.removeItem(at: tempDir)
            }
            
            // Extract the archive
            try extractZipArchive(from: url, to: tempDir)
            
            // Parse manifest
            let manifestURL = tempDir.appendingPathComponent("manifest.json")
            guard fileManager.fileExists(atPath: manifestURL.path) else {
                return .failure(.missingManifest)
            }
            
            let manifestData = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            let manifest = try decoder.decode(DearlyManifest.self, from: manifestData)
            
            // Validate version
            if manifest.formatVersion > DearlyFormatVersion {
                return .failure(.unsupportedVersion(manifest.formatVersion))
            }
            
            // Validate based on bundle type
            if manifest.bundleType == .backup || manifest.cards != nil {
                // Backup bundle - validate cards array exists
                guard let cards = manifest.cards, !cards.isEmpty else {
                    return .failure(.invalidManifest("Backup bundle has no cards"))
                }
            } else {
                // Single card - validate required images exist
                guard let images = manifest.images else {
                    return .failure(.invalidManifest("Missing images data"))
                }
                
                guard fileManager.fileExists(atPath: tempDir.appendingPathComponent(images.front).path) else {
                    return .failure(.missingImage(images.front))
                }
                
                guard fileManager.fileExists(atPath: tempDir.appendingPathComponent(images.back).path) else {
                    return .failure(.missingImage(images.back))
                }
            }
            
            return .success(manifest)
        } catch let error as DearlyFileError {
            return .failure(error)
        } catch {
            return .failure(.fileOperationError(error.localizedDescription))
        }
    }
    
    // MARK: - Backup Bundle Export
    
    /// Exports multiple cards to a backup .dearly file
    /// - Parameter cards: The cards to export
    /// - Returns: URL to the exported .dearly backup file
    /// - Throws: DearlyFileError if export fails
    func exportCardsToBackup(_ cards: [Card]) throws -> URL {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        var cardsWithImages: [DearlyCardWithImages] = []
        let cardsDir = tempDir.appendingPathComponent("cards")
        try fileManager.createDirectory(at: cardsDir, withIntermediateDirectories: true)
        
        for card in cards {
            let cardFolder = cardsDir.appendingPathComponent(card.id.uuidString)
            try fileManager.createDirectory(at: cardFolder, withIntermediateDirectories: true)
            
            // Front image (required)
            guard let frontImage = card.frontImage,
                  let frontData = frontImage.jpegData(compressionQuality: 0.9) else {
                continue
            }
            let frontFilename = "front.jpg"
            try frontData.write(to: cardFolder.appendingPathComponent(frontFilename))
            
            // Back image (required)
            guard let backImage = card.backImage,
                  let backData = backImage.jpegData(compressionQuality: 0.9) else {
                continue
            }
            let backFilename = "back.jpg"
            try backData.write(to: cardFolder.appendingPathComponent(backFilename))
            
            // Inside left image (optional)
            var insideLeftFilename: String? = nil
            if let insideLeftImage = card.insideLeftImage,
               let insideLeftData = insideLeftImage.jpegData(compressionQuality: 0.9) {
                insideLeftFilename = "inside_left.jpg"
                try insideLeftData.write(to: cardFolder.appendingPathComponent(insideLeftFilename!))
            }
            
            // Inside right image (optional)
            var insideRightFilename: String? = nil
            if let insideRightImage = card.insideRightImage,
               let insideRightData = insideRightImage.jpegData(compressionQuality: 0.9) {
                insideRightFilename = "inside_right.jpg"
                try insideRightData.write(to: cardFolder.appendingPathComponent(insideRightFilename!))
            }
            
            let images = DearlyImages(
                front: "cards/\(card.id.uuidString)/\(frontFilename)",
                back: "cards/\(card.id.uuidString)/\(backFilename)",
                insideLeft: insideLeftFilename.map { "cards/\(card.id.uuidString)/\($0)" },
                insideRight: insideRightFilename.map { "cards/\(card.id.uuidString)/\($0)" }
            )
            
            cardsWithImages.append(DearlyCardWithImages.from(card, images: images))
        }
        
        guard !cardsWithImages.isEmpty else {
            throw DearlyFileError.exportError("No valid cards to export")
        }
        
        // Create manifest
        let manifest = DearlyManifest(cards: cardsWithImages)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))
        
        // Create ZIP archive
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsDir = documentsDir.appendingPathComponent("Exports", isDirectory: true)
        try fileManager.createDirectory(at: exportsDir, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let datePart = dateFormatter.string(from: Date())
        let exportFilename = "dearly_backup_\(datePart).dearly"
        let exportURL = exportsDir.appendingPathComponent(exportFilename)
        
        if fileManager.fileExists(atPath: exportURL.path) {
            try fileManager.removeItem(at: exportURL)
        }
        
        try createZipArchive(from: tempDir, to: exportURL)
        
        print("✅ Exported \(cardsWithImages.count) cards to backup: \(exportURL.path)")
        return exportURL
    }
    
    // MARK: - Backup Bundle Preview
    
    /// Preview structure for backup bundle cards
    struct BundlePreview {
        let id: String
        let sender: String?
        let occasion: String?
        let date: String
        let thumbnailData: Data?
    }
    
    /// Gets a preview of cards in a backup bundle
    /// - Parameter url: URL to the .dearly backup file
    /// - Returns: Array of card previews, or nil if not a backup bundle
    /// - Throws: DearlyFileError if file cannot be read
    func previewBackupBundle(from url: URL) throws -> [BundlePreview]? {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        try extractZipArchive(from: url, to: tempDir)
        
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw DearlyFileError.missingManifest
        }
        
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(DearlyManifest.self, from: manifestData)
        
        // Only for backup bundles
        guard manifest.bundleType == .backup || manifest.cards != nil,
              let cards = manifest.cards else {
            return nil
        }
        
        var previews: [BundlePreview] = []
        
        for cardData in cards {
            var thumbnail: Data? = nil
            
            // Try to get front image as thumbnail
            let frontImageURL = tempDir.appendingPathComponent(cardData.images.front)
            if fileManager.fileExists(atPath: frontImageURL.path) {
                thumbnail = try? Data(contentsOf: frontImageURL)
            }
            
            previews.append(BundlePreview(
                id: cardData.id,
                sender: cardData.sender,
                occasion: cardData.occasion,
                date: cardData.date,
                thumbnailData: thumbnail
            ))
        }
        
        return previews
    }
    
    // MARK: - Backup Bundle Import
    
    /// Imports cards from a backup .dearly file
    /// - Parameters:
    ///   - url: URL to the .dearly backup file
    ///   - modelContext: SwiftData model context for saving cards
    ///   - generateNewIds: Whether to generate new IDs for cards (default: true)
    ///   - selectedIds: Set of card IDs to import (nil imports all)
    /// - Returns: Array of imported Cards
    /// - Throws: DearlyFileError if import fails
    func importCardsFromBackup(
        from url: URL,
        using modelContext: ModelContext,
        generateNewIds: Bool = true,
        selectedIds: Set<String>? = nil
    ) throws -> [Card] {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        try extractZipArchive(from: url, to: tempDir)
        
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw DearlyFileError.missingManifest
        }
        
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(DearlyManifest.self, from: manifestData)
        
        if manifest.formatVersion > DearlyFormatVersion {
            throw DearlyFileError.unsupportedVersion(manifest.formatVersion)
        }
        
        guard manifest.bundleType == .backup || manifest.cards != nil,
              let cards = manifest.cards else {
            throw DearlyFileError.invalidManifest("Not a backup bundle")
        }
        
        var importedCards: [Card] = []
        
        for cardData in cards {
            // Skip if not in selected set
            if let selected = selectedIds, !selected.contains(cardData.id) {
                continue
            }
            
            let cardId = generateNewIds ? UUID() : (UUID(uuidString: cardData.id) ?? UUID())
            
            // Extract and save images
            let frontURL = tempDir.appendingPathComponent(cardData.images.front)
            guard fileManager.fileExists(atPath: frontURL.path),
                  let frontImage = UIImage(contentsOfFile: frontURL.path),
                  let frontPath = imageStorage.saveImage(frontImage, for: cardId, side: .front) else {
                continue
            }
            
            let backURL = tempDir.appendingPathComponent(cardData.images.back)
            guard fileManager.fileExists(atPath: backURL.path),
                  let backImage = UIImage(contentsOfFile: backURL.path),
                  let backPath = imageStorage.saveImage(backImage, for: cardId, side: .back) else {
                continue
            }
            
            var insideLeftPath: String? = nil
            if let insideLeft = cardData.images.insideLeft {
                let insideLeftURL = tempDir.appendingPathComponent(insideLeft)
                if fileManager.fileExists(atPath: insideLeftURL.path),
                   let insideLeftImage = UIImage(contentsOfFile: insideLeftURL.path) {
                    insideLeftPath = imageStorage.saveImage(insideLeftImage, for: cardId, side: .insideLeft)
                }
            }
            
            var insideRightPath: String? = nil
            if let insideRight = cardData.images.insideRight {
                let insideRightURL = tempDir.appendingPathComponent(insideRight)
                if fileManager.fileExists(atPath: insideRightURL.path),
                   let insideRightImage = UIImage(contentsOfFile: insideRightURL.path) {
                    insideRightPath = imageStorage.saveImage(insideRightImage, for: cardId, side: .insideRight)
                }
            }
            
            // Parse dates
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let cardDate = dateFormatter.date(from: cardData.date)
            
            let isoFormatter = ISO8601DateFormatter()
            let createdAt = cardData.createdAt.flatMap { isoFormatter.date(from: $0) }
            let updatedAt = cardData.updatedAt.flatMap { isoFormatter.date(from: $0) }
            
            // Create the new card
            let card = Card(
                id: cardId,
                frontImagePath: frontPath,
                backImagePath: backPath,
                insideLeftImagePath: insideLeftPath,
                insideRightImagePath: insideRightPath,
                dateScanned: Date(),
                isFavorite: cardData.isFavorite,
                sender: cardData.sender,
                occasion: cardData.occasion,
                dateReceived: cardDate,
                notes: cardData.notes
            )
            
            // Set extended properties
            card.cardType = cardData.type?.rawValue
            card.aspectRatio = cardData.aspectRatio
            card.createdAt = createdAt ?? Date()
            card.updatedAt = updatedAt
            
            // Set AI extraction data if present
            if let aiData = cardData.aiExtractedData {
                card.aiExtractedText = aiData.extractedText
                card.aiDetectedSender = aiData.detectedSender
                card.aiDetectedOccasion = aiData.detectedOccasion
                card.aiSentiment = aiData.sentiment
                card.aiMentionedDates = aiData.mentionedDates
                card.aiKeywords = aiData.keywords
                card.aiExtractionStatus = aiData.status.rawValue
                card.aiLastExtractedAt = aiData.lastExtractedAt.flatMap { isoFormatter.date(from: $0) }
                card.aiProcessingStartedAt = aiData.processingStartedAt.flatMap { isoFormatter.date(from: $0) }
                
                if let error = aiData.error {
                    card.aiErrorType = error.type.rawValue
                    card.aiErrorMessage = error.message
                    card.aiErrorRetryable = error.retryable
                }
            }
            
            modelContext.insert(card)
            importedCards.append(card)
        }
        
        try modelContext.save()
        
        print("✅ Imported \(importedCards.count) cards from backup")
        return importedCards
    }
    
    // MARK: - Private Methods - ZIP Operations
    
    /// Creates a ZIP archive from a directory using native approach
    /// Recursively includes all files and subdirectories
    private func createZipArchive(from sourceDir: URL, to destinationURL: URL) throws {
        var zipWriter = ZipWriter()
        
        // Recursively collect all files
        try addFilesToZip(from: sourceDir, baseDir: sourceDir, writer: &zipWriter)
        
        let zipData = try zipWriter.finalize()
        try zipData.write(to: destinationURL)
    }
    
    /// Recursively adds files from a directory to the ZIP writer
    private func addFilesToZip(from dir: URL, baseDir: URL, writer: inout ZipWriter) throws {
        let contents = try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])
        
        for itemURL in contents {
            let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? false
            
            // Calculate relative path from base directory
            let relativePath = itemURL.path.replacingOccurrences(of: baseDir.path + "/", with: "")
            
            if isDirectory {
                // Recursively process subdirectory
                try addFilesToZip(from: itemURL, baseDir: baseDir, writer: &writer)
            } else {
                // Add file to ZIP
                let fileData = try Data(contentsOf: itemURL)
                try writer.addEntry(name: relativePath, data: fileData, compressionMethod: .store)
            }
        }
    }
    
    /// Extracts a ZIP archive to a directory using native approach
    /// Creates subdirectories as needed for nested paths
    private func extractZipArchive(from sourceURL: URL, to destinationDir: URL) throws {
        let zipData = try Data(contentsOf: sourceURL)
        
        let zipReader = try ZipReader(data: zipData)
        for entry in zipReader.entries {
            let entryURL = destinationDir.appendingPathComponent(entry.name)
            
            // Create parent directories if needed (for nested paths like "cards/uuid/front.jpg")
            let parentDir = entryURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            
            try entry.data.write(to: entryURL)
        }
    }
    
    /// Saves an imported image to the image storage
    private func saveImportedImage(
        filename: String,
        from tempDir: URL,
        cardId: UUID,
        side: ImageSide
    ) throws -> String {
        let sourceURL = tempDir.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw DearlyFileError.missingImage(filename)
        }
        
        guard let image = UIImage(contentsOfFile: sourceURL.path) else {
            throw DearlyFileError.invalidCardData("Could not load image: \(filename)")
        }
        
        guard let path = imageStorage.saveImage(image, for: cardId, side: side) else {
            throw DearlyFileError.writeError("Failed to save image: \(filename)")
        }
        
        return path
    }
}

// MARK: - Simple ZIP Implementation

import Compression

enum ZipCompressionMethod: UInt16 {
    case store = 0
    case deflate = 8
}

/// A lightweight ZIP file writer compatible with PKZip format
private struct ZipWriter {
    private var entries: [(name: String, compressedData: Data, uncompressedSize: UInt32, crc32: UInt32, method: ZipCompressionMethod)] = []
    
    mutating func addEntry(name: String, data: Data, compressionMethod: ZipCompressionMethod = .store) throws {
        let crc = data.crc32()
        let uncompressedSize = UInt32(data.count)
        
        var compressedData: Data
        var method = compressionMethod
        
        switch compressionMethod {
        case .store:
            compressedData = data
            
        case .deflate:
            // Compress data using raw DEFLATE by stripping ZLIB headers
            let bufferSize = max(size_t(data.count), 64 * 1024)
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { destinationBuffer.deallocate() }
            
            let sourceData = data as NSData
            
            // Use zlib compression
            let compressedSize = compression_encode_buffer(
                destinationBuffer,
                bufferSize,
                sourceData.bytes.bindMemory(to: UInt8.self, capacity: data.count),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
            
            if compressedSize > 0 {
                // Strip zlib header (2 bytes) and checksum (4 bytes) to get raw DEFLATE
                if compressedSize > 6 {
                    let rawDeflateData = Data(bytes: destinationBuffer.advanced(by: 2), count: compressedSize - 6)
                    compressedData = rawDeflateData
                } else {
                    // Fallback to store
                    compressedData = data
                    method = .store
                }
            } else {
                // Fallback to store
                compressedData = data
                method = .store
            }
        }
        
        entries.append((name: name, compressedData: compressedData, uncompressedSize: uncompressedSize, crc32: crc, method: method))
    }
    
    func finalize() throws -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0
        
        // Write local file headers and data
        for entry in entries {
            let localHeader = createLocalFileHeader(
                name: entry.name,
                compressedSize: UInt32(entry.compressedData.count),
                uncompressedSize: entry.uncompressedSize,
                crc32: entry.crc32,
                method: entry.method
            )
            archive.append(localHeader)
            archive.append(entry.compressedData)
            
            // Create central directory entry
            let centralEntry = createCentralDirectoryEntry(
                name: entry.name,
                compressedSize: UInt32(entry.compressedData.count),
                uncompressedSize: entry.uncompressedSize,
                crc32: entry.crc32,
                method: entry.method,
                offset: offset
            )
            centralDirectory.append(centralEntry)
            
            offset = UInt32(archive.count)
        }
        
        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        
        // Write end of central directory
        let endRecord = createEndOfCentralDirectory(
            entryCount: UInt16(entries.count),
            centralDirectorySize: UInt32(centralDirectory.count),
            centralDirectoryOffset: centralDirectoryOffset
        )
        archive.append(endRecord)
        
        return archive
    }
    
    private func createLocalFileHeader(name: String, compressedSize: UInt32, uncompressedSize: UInt32, crc32: UInt32, method: ZipCompressionMethod) -> Data {
        var header = Data()
        let nameData = name.data(using: .utf8) ?? Data()
        
        header.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Local file header signature
        header.append(contentsOf: UInt16(20).littleEndianBytes) // Version needed
        header.append(contentsOf: UInt16(0).littleEndianBytes) // General purpose bit flag
        header.append(contentsOf: method.rawValue.littleEndianBytes) // Compression method
        header.append(contentsOf: UInt16(0).littleEndianBytes) // Last mod file time
        header.append(contentsOf: UInt16(0).littleEndianBytes) // Last mod file date
        header.append(contentsOf: crc32.littleEndianBytes) // CRC-32
        header.append(contentsOf: compressedSize.littleEndianBytes) // Compressed size
        header.append(contentsOf: uncompressedSize.littleEndianBytes) // Uncompressed size
        header.append(contentsOf: UInt16(nameData.count).littleEndianBytes) // File name length
        header.append(contentsOf: UInt16(0).littleEndianBytes) // Extra field length
        header.append(nameData) // File name
        
        return header
    }
    
    private func createCentralDirectoryEntry(name: String, compressedSize: UInt32, uncompressedSize: UInt32, crc32: UInt32, method: ZipCompressionMethod, offset: UInt32) -> Data {
        var entry = Data()
        let nameData = name.data(using: .utf8) ?? Data()
        
        entry.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // Central directory signature
        entry.append(contentsOf: UInt16(20).littleEndianBytes) // Version made by
        entry.append(contentsOf: UInt16(20).littleEndianBytes) // Version needed
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // General purpose bit flag
        entry.append(contentsOf: method.rawValue.littleEndianBytes) // Compression method
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Last mod file time
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Last mod file date
        entry.append(contentsOf: crc32.littleEndianBytes) // CRC-32
        entry.append(contentsOf: compressedSize.littleEndianBytes) // Compressed size
        entry.append(contentsOf: uncompressedSize.littleEndianBytes) // Uncompressed size
        entry.append(contentsOf: UInt16(nameData.count).littleEndianBytes) // File name length
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Extra field length
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // File comment length
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Disk number start
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Internal file attributes
        entry.append(contentsOf: UInt32(0).littleEndianBytes) // External file attributes
        entry.append(contentsOf: offset.littleEndianBytes) // Relative offset of local header
        entry.append(nameData) // File name
        
        return entry
    }
    
    private func createEndOfCentralDirectory(entryCount: UInt16, centralDirectorySize: UInt32, centralDirectoryOffset: UInt32) -> Data {
        var endRecord = Data()
        
        endRecord.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // End of central directory signature
        endRecord.append(contentsOf: UInt16(0).littleEndianBytes) // Disk number
        endRecord.append(contentsOf: UInt16(0).littleEndianBytes) // Disk number with central directory
        endRecord.append(contentsOf: entryCount.littleEndianBytes) // Number of entries on this disk
        endRecord.append(contentsOf: entryCount.littleEndianBytes) // Total number of entries
        endRecord.append(contentsOf: centralDirectorySize.littleEndianBytes) // Size of central directory
        endRecord.append(contentsOf: centralDirectoryOffset.littleEndianBytes) // Offset of central directory
        endRecord.append(contentsOf: UInt16(0).littleEndianBytes) // Comment length
        
        return endRecord
    }
}

/// A lightweight ZIP file reader
private struct ZipReader {
    struct Entry {
        let name: String
        let data: Data
    }
    
    let entries: [Entry]
    
    init(data: Data) throws {
        var entries: [Entry] = []
        var offset = 0
        
        // Validate ZIP signature at start of file
        guard data.count >= 4 else {
            throw DearlyFileError.invalidZip
        }
        
        let initialSignature = data.subdata(in: 0..<4)
        guard initialSignature == Data([0x50, 0x4B, 0x03, 0x04]) else {
            throw DearlyFileError.invalidZip
        }
        
        while offset < data.count - 4 {
            // Check for local file header signature
            let signature = data.subdata(in: offset..<offset+4)
            if signature != Data([0x50, 0x4B, 0x03, 0x04]) {
                break
            }
            
            offset += 4
            
            // Skip version needed (2)
            offset += 2
            
            // Skip flags (2)
            offset += 2
            
            // Read compression method (2 bytes)
            guard offset + 2 <= data.count else { break }
            let compressionMethod = data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            offset += 2
            
            // Skip time (2), date (2)
            offset += 4
            
            // Read CRC-32 (4 bytes)
            offset += 4
            
            // Read compressed size (4 bytes)
            guard offset + 4 <= data.count else { break }
            let compressedSize = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            offset += 4
            
            // Read uncompressed size (4 bytes) - useful for buffer allocation if needed
            guard offset + 4 <= data.count else { break }
            let uncompressedSize = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            offset += 4
            
            // Read file name length (2 bytes)
            guard offset + 2 <= data.count else { break }
            let nameLength = data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            offset += 2
            
            // Read extra field length (2 bytes)
            guard offset + 2 <= data.count else { break }
            let extraLength = data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            offset += 2
            
            // Read file name
            guard offset + Int(nameLength) <= data.count else { break }
            let nameData = data.subdata(in: offset..<offset+Int(nameLength))
            let name = String(data: nameData, encoding: .utf8) ?? ""
            offset += Int(nameLength)
            
            // Skip extra field
            offset += Int(extraLength)
            
            // Read file data
            guard offset + Int(compressedSize) <= data.count else { break }
            let compressedData = data.subdata(in: offset..<offset+Int(compressedSize))
            offset += Int(compressedSize)
            
            // Decompress if needed
            let uncompressedData: Data
            if compressionMethod == ZipCompressionMethod.store.rawValue {
                uncompressedData = compressedData
            } else if compressionMethod == ZipCompressionMethod.deflate.rawValue {
                // Decompress raw DEFLATE data
                // Create ZLIB header: CMF (0x78) + FLG (0x9C)
                // This satisfies (CMF * 256 + FLG) % 31 == 0 check
                var zlibData = Data([0x78, 0x9C])
                zlibData.append(compressedData)
                
                let bufferSize = Int(uncompressedSize) + 1024
                let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { destinationBuffer.deallocate() }
                
                let sourceData = zlibData as NSData
                
                let decodedSize = compression_decode_buffer(
                    destinationBuffer,
                    bufferSize,
                    sourceData.bytes.bindMemory(to: UInt8.self, capacity: zlibData.count),
                    zlibData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
                
                if decodedSize > 0 {
                    uncompressedData = Data(bytes: destinationBuffer, count: decodedSize)
                } else {
                    // Fallback: try decompressing without prepended header
                    print("⚠️ Failed to decompress \(name) with header. Retrying raw...")
                    
                    let rawSource = compressedData as NSData
                     let decodedSize2 = compression_decode_buffer(
                         destinationBuffer,
                         bufferSize,
                         rawSource.bytes.bindMemory(to: UInt8.self, capacity: compressedData.count),
                         compressedData.count,
                         nil,
                         COMPRESSION_ZLIB
                     )
                    
                    if decodedSize2 > 0 {
                         uncompressedData = Data(bytes: destinationBuffer, count: decodedSize2)
                    } else {
                         throw DearlyFileError.invalidCardData("Decompression failed for \(name)")
                    }
                }
            } else {
                throw DearlyFileError.invalidCardData("Unsupported compression method: \(compressionMethod)")
            }
            
            entries.append(Entry(name: name, data: uncompressedData))
        }
        
        self.entries = entries
    }
}

// MARK: - Data Extensions for ZIP

private extension Data {
    /// Calculate CRC-32 checksum
    func crc32() -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = Self.crc32Table
        
        for byte in self {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        
        return ~crc
    }
    
    /// CRC-32 lookup table
    private static let crc32Table: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }()
}

private extension UInt16 {
    var littleEndianBytes: [UInt8] {
        let value = self.littleEndian
        return [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }
}

private extension UInt32 {
    var littleEndianBytes: [UInt8] {
        let value = self.littleEndian
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }
}
