//
//  DearlyManifest.swift
//  Dearly
//
//  Codable models for the .dearly file format manifest.json
//

import Foundation

// MARK: - Format Constants

/// Current supported format version
let DearlyFormatVersion: Int = 1

// MARK: - Top-Level Manifest

/// The top-level manifest structure for a .dearly file
struct DearlyManifest: Codable {
    /// Format version number (currently 1)
    let formatVersion: Int
    
    /// ISO 8601 timestamp of when the file was created
    let exportedAt: String
    
    /// Card metadata
    let card: DearlyCardData
    
    /// Image filename mapping
    let images: DearlyImages
    
    /// Creates a manifest for export
    init(card: DearlyCardData, images: DearlyImages) {
        self.formatVersion = DearlyFormatVersion
        self.exportedAt = ISO8601DateFormatter().string(from: Date())
        self.card = card
        self.images = images
    }
    
    /// Creates a manifest from decoded data
    init(formatVersion: Int, exportedAt: String, card: DearlyCardData, images: DearlyImages) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.card = card
        self.images = images
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
