//
//  DearlyManifest.swift
//  Dearly
//
//  Codable models for the .dearly file format manifest.json
//

import Foundation

// MARK: - Format Constants

/// Current supported format version (major version for compatibility checks)
let DearlyFormatVersion: Double = 3

// MARK: - Bundle Type

/// Bundle type for .dearly files
enum DearlyBundleType: String, Codable {
    case single = "single"
    case backup = "backup"
}

// MARK: - Top-Level Manifest

/// The top-level manifest structure for a .dearly file
struct DearlyManifest: Codable {
    /// Format version number (supports both integer like 1 and decimal like 1.1)
    let formatVersion: Double
    
    /// ISO 8601 timestamp of when the file was created
    let exportedAt: String
    
    /// Bundle type: single card or backup bundle (optional for backward compatibility)
    let bundleType: DearlyBundleType?
    
    /// Card metadata (single card mode only)
    let card: DearlyCardData?
    
    /// Image filename mapping (single card mode only)
    let images: DearlyImages?
    
    /// Version history (optional, v2 feature - at top level per spec, single card mode only)
    let versionHistory: [DearlyVersionSnapshot]?
    
    /// Array of cards with embedded images (backup bundle mode only)
    let cards: [DearlyCardWithImages]?
    
    /// Creates a manifest for single card export
    init(card: DearlyCardData, images: DearlyImages, versionHistory: [DearlyVersionSnapshot]? = nil) {
        self.formatVersion = versionHistory != nil ? 2 : 1
        self.exportedAt = ISO8601DateFormatter().string(from: Date())
        self.bundleType = .single
        self.card = card
        self.images = images
        self.versionHistory = versionHistory
        self.cards = nil
    }
    
    /// Creates a manifest for backup bundle export
    init(cards: [DearlyCardWithImages]) {
        self.formatVersion = 3
        self.exportedAt = ISO8601DateFormatter().string(from: Date())
        self.bundleType = .backup
        self.card = nil
        self.images = nil
        self.versionHistory = nil
        self.cards = cards
    }
    
    /// Creates a manifest from decoded data (for import)
    init(
        formatVersion: Double,
        exportedAt: String,
        bundleType: DearlyBundleType? = nil,
        card: DearlyCardData? = nil,
        images: DearlyImages? = nil,
        versionHistory: [DearlyVersionSnapshot]? = nil,
        cards: [DearlyCardWithImages]? = nil
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.bundleType = bundleType
        self.card = card
        self.images = images
        self.versionHistory = versionHistory
        self.cards = cards
    }
}

// MARK: - Backup Bundle Card

/// Card with embedded image references for backup bundles
struct DearlyCardWithImages: Codable {
    let id: String
    let date: String
    let isFavorite: Bool
    let sender: String?
    let occasion: String?
    let notes: String?
    let type: DearlyCardType?
    let aspectRatio: Double?
    let aiExtractedData: DearlyAIExtractedData?
    let createdAt: String?
    let updatedAt: String?
    let images: DearlyImages
    
    /// Creates a DearlyCardWithImages from a Card model
    static func from(_ card: Card, images: DearlyImages) -> DearlyCardWithImages {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let isoFormatter = ISO8601DateFormatter()
        
        var aiData: DearlyAIExtractedData? = nil
        if let status = card.aiExtractionStatus,
           let extractionStatus = DearlyExtractionStatus(rawValue: status) {
            
            var errorObj: DearlyExtractionError? = nil
            if let errorType = card.aiErrorType,
               let errorTypeEnum = DearlyExtractionErrorType(rawValue: errorType),
               let errorMessage = card.aiErrorMessage {
                errorObj = DearlyExtractionError(
                    type: errorTypeEnum,
                    message: errorMessage,
                    retryable: card.aiErrorRetryable ?? false
                )
            }
            
            aiData = DearlyAIExtractedData(
                extractedText: card.aiExtractedText,
                detectedSender: card.aiDetectedSender,
                detectedOccasion: card.aiDetectedOccasion,
                sentiment: card.aiSentiment,
                mentionedDates: card.aiMentionedDates,
                keywords: card.aiKeywords,
                status: extractionStatus,
                lastExtractedAt: card.aiLastExtractedAt.map { isoFormatter.string(from: $0) },
                processingStartedAt: card.aiProcessingStartedAt.map { isoFormatter.string(from: $0) },
                error: errorObj
            )
        }
        
        return DearlyCardWithImages(
            id: card.id.uuidString,
            date: dateFormatter.string(from: card.dateReceived ?? card.dateScanned),
            isFavorite: card.isFavorite,
            sender: card.sender,
            occasion: card.occasion,
            notes: card.notes,
            type: card.cardType.flatMap { DearlyCardType(rawValue: $0) },
            aspectRatio: card.aspectRatio,
            aiExtractedData: aiData,
            createdAt: card.createdAt.map { isoFormatter.string(from: $0) },
            updatedAt: card.updatedAt.map { isoFormatter.string(from: $0) },
            images: images
        )
    }
}

// MARK: - Card Data

/// Card type enum
enum DearlyCardType: String, Codable {
    case flat = "flat"
    case folded = "folded"
}

/// Card metadata structure
struct DearlyCardData: Codable {
    /// UUID identifier for the card
    let id: String
    
    /// User-assigned date in ISO 8601 format (YYYY-MM-DD)
    let date: String
    
    /// Whether the card is marked as a favorite
    let isFavorite: Bool
    
    /// Name of the sender (optional)
    let sender: String?
    
    /// Event/occasion (optional)
    let occasion: String?
    
    /// User notes about the card (optional)
    let notes: String?
    
    /// Physical card type (optional, default: flat)
    let type: DearlyCardType?
    
    /// Width/height ratio for consistent rendering (optional)
    let aspectRatio: Double?
    
    /// AI-extracted metadata (optional)
    let aiExtractedData: DearlyAIExtractedData?
    
    /// ISO 8601 timestamp when originally created (optional)
    let createdAt: String?
    
    /// ISO 8601 timestamp when last modified (optional)
    let updatedAt: String?
    
    /// Creates a DearlyCardData from a Card model
    static func from(_ card: Card) -> DearlyCardData {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let isoFormatter = ISO8601DateFormatter()
        
        // Build AI extracted data if status is present
        var aiData: DearlyAIExtractedData? = nil
        if let status = card.aiExtractionStatus,
           let extractionStatus = DearlyExtractionStatus(rawValue: status) {
            
            // Build error object if present
            var errorObj: DearlyExtractionError? = nil
            if let errorType = card.aiErrorType,
               let errorTypeEnum = DearlyExtractionErrorType(rawValue: errorType),
               let errorMessage = card.aiErrorMessage {
                errorObj = DearlyExtractionError(
                    type: errorTypeEnum,
                    message: errorMessage,
                    retryable: card.aiErrorRetryable ?? false
                )
            }
            
            aiData = DearlyAIExtractedData(
                extractedText: card.aiExtractedText,
                detectedSender: card.aiDetectedSender,
                detectedOccasion: card.aiDetectedOccasion,
                sentiment: card.aiSentiment,
                mentionedDates: card.aiMentionedDates,
                keywords: card.aiKeywords,
                status: extractionStatus,
                lastExtractedAt: card.aiLastExtractedAt.map { isoFormatter.string(from: $0) },
                processingStartedAt: card.aiProcessingStartedAt.map { isoFormatter.string(from: $0) },
                error: errorObj
            )
        }
        
        return DearlyCardData(
            id: card.id.uuidString,
            date: dateFormatter.string(from: card.dateReceived ?? card.dateScanned),
            isFavorite: card.isFavorite,
            sender: card.sender,
            occasion: card.occasion,
            notes: card.notes,
            type: card.cardType.flatMap { DearlyCardType(rawValue: $0) },
            aspectRatio: card.aspectRatio,
            aiExtractedData: aiData,
            createdAt: card.createdAt.map { isoFormatter.string(from: $0) },
            updatedAt: card.updatedAt.map { isoFormatter.string(from: $0) }
        )
    }
}

// MARK: - Images

/// Image filename mapping structure
struct DearlyImages: Codable {
    /// Filename of front image in archive
    let front: String
    
    /// Filename of back image in archive
    let back: String
    
    /// Filename of inside left image (optional)
    let insideLeft: String?
    
    /// Filename of inside right image (optional)
    let insideRight: String?
}

// MARK: - AI Extracted Data

/// Extraction status enum
enum DearlyExtractionStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case complete = "complete"
    case failed = "failed"
}

/// Error type enum for extraction failures
enum DearlyExtractionErrorType: String, Codable {
    case networkError = "NETWORK_ERROR"
    case quotaExceeded = "QUOTA_EXCEEDED"
    case invalidImage = "INVALID_IMAGE"
    case parsingError = "PARSING_ERROR"
    case apiKeyMissing = "API_KEY_MISSING"
    case unknownError = "UNKNOWN_ERROR"
}

/// Error details structure
struct DearlyExtractionError: Codable {
    let type: DearlyExtractionErrorType
    let message: String
    let retryable: Bool
}

/// AI extracted data structure (for future compatibility)
struct DearlyAIExtractedData: Codable {
    /// Full OCR text extracted from card images
    let extractedText: String?
    
    /// AI-detected sender name
    let detectedSender: String?
    
    /// AI-detected occasion/holiday
    let detectedOccasion: String?
    
    /// Detected sentiment/tone of message
    let sentiment: String?
    
    /// Dates found in card text (YYYY-MM-DD format)
    let mentionedDates: [String]?
    
    /// Detected keywords/themes
    let keywords: [String]?
    
    /// Extraction status (required when aiExtractedData is present)
    let status: DearlyExtractionStatus
    
    /// ISO 8601 timestamp of last extraction
    let lastExtractedAt: String?
    
    /// ISO 8601 timestamp when processing began
    let processingStartedAt: String?
    
    /// Error details if extraction failed
    let error: DearlyExtractionError?
}

// MARK: - Version History (Spec v1.2)

/// Version snapshot for .dearly file format (spec-compliant)
struct DearlyVersionSnapshot: Codable {
    let versionNumber: Int
    let editedAt: String  // ISO 8601
    let metadataChanges: [DearlyMetadataChange]
    let imageChanges: [DearlyImageChange]
    
    /// Convert from internal CardVersionSnapshot
    static func from(_ snapshot: CardVersionSnapshot) -> DearlyVersionSnapshot {
        let isoFormatter = ISO8601DateFormatter()
        return DearlyVersionSnapshot(
            versionNumber: snapshot.versionNumber,
            editedAt: isoFormatter.string(from: snapshot.editedAt),
            metadataChanges: snapshot.metadataChanges.map { DearlyMetadataChange.from($0) },
            imageChanges: snapshot.imageChanges.map { DearlyImageChange.from($0) }
        )
    }
    
    /// Convert to internal CardVersionSnapshot
    func toCardVersionSnapshot() -> CardVersionSnapshot {
        let isoFormatter = ISO8601DateFormatter()
        return CardVersionSnapshot(
            versionNumber: versionNumber,
            editedAt: isoFormatter.date(from: editedAt) ?? Date(),
            metadataChanges: metadataChanges.map { $0.toMetadataChange() },
            imageChanges: imageChanges.map { $0.toImageChange() }
        )
    }
}

/// Metadata change for .dearly file format (spec field name: "field")
struct DearlyMetadataChange: Codable {
    let field: String  // Spec uses string, not enum
    let previousValue: String?
    let newValue: String?
    
    static func from(_ change: MetadataChange) -> DearlyMetadataChange {
        DearlyMetadataChange(
            field: change.field.rawValue.lowercased(),  // Spec uses lowercase
            previousValue: change.previousValue,
            newValue: change.newValue
        )
    }
    
    func toMetadataChange() -> MetadataChange {
        // Map spec field names back to enum
        let fieldEnum: MetadataField
        switch field.lowercased() {
        case "sender": fieldEnum = .sender
        case "occasion": fieldEnum = .occasion
        case "date received", "datereceived": fieldEnum = .dateReceived
        case "notes": fieldEnum = .notes
        default: fieldEnum = .notes  // Fallback
        }
        return MetadataChange(field: fieldEnum, previousValue: previousValue, newValue: newValue)
    }
}

/// Image change for .dearly file format (spec uses "previousFilename")
struct DearlyImageChange: Codable {
    let slot: String  // Spec uses string
    let previousFilename: String  // Spec field name
    
    static func from(_ change: ImageChange) -> DearlyImageChange {
        // Extract just the filename from the full path for the ZIP
        // e.g., "CardImages/uuid/versions/v1/front.jpg" -> "versions/v1/front.jpg"
        let filename: String
        if let range = change.previousUri.range(of: "versions/") {
            filename = String(change.previousUri[range.lowerBound...])
        } else {
            filename = change.previousUri
        }
        return DearlyImageChange(
            slot: change.slot.rawValue,
            previousFilename: filename
        )
    }
    
    func toImageChange(withBasePath basePath: String = "") -> ImageChange {
        let slotEnum: ImageSlot
        switch slot.lowercased() {
        case "front": slotEnum = .front
        case "back": slotEnum = .back
        case "insideleft": slotEnum = .insideLeft
        case "insideright": slotEnum = .insideRight
        default: slotEnum = .front  // Fallback
        }
        // The basePath will be prepended during import
        return ImageChange(slot: slotEnum, previousUri: basePath + previousFilename)
    }
}
