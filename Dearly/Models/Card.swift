//
//  Card.swift
//  Dearly
//
//  Created by Mark Mauro on 10/28/25.
//

import Foundation
import SwiftUI
import SwiftData

@Model
final class Card {
    var id: UUID = UUID()
    
    // Image data stored directly in SwiftData (syncs via CloudKit)
    @Attribute(.externalStorage) var frontImageData: Data?
    @Attribute(.externalStorage) var backImageData: Data?
    @Attribute(.externalStorage) var insideLeftImageData: Data?
    @Attribute(.externalStorage) var insideRightImageData: Data?
    
    var dateScanned: Date = Date()
    var isFavorite: Bool = false
    
    // Metadata
    var sender: String?
    var occasion: String?
    var dateReceived: Date?
    var notes: String?
    
    // Extended properties for .dearly file format
    var cardType: String?  // "flat" | "folded"
    var aspectRatio: Double?
    var createdAt: Date?
    var updatedAt: Date?
    
    // AI Extraction Data (per .dearly file format spec)
    var aiExtractedText: String?
    var aiDetectedSender: String?
    var aiDetectedOccasion: String?
    var aiSentiment: String?  // "positive" | "neutral" | "negative"
    var aiMentionedDates: [String]?
    var aiKeywords: [String]?
    var aiExtractionStatus: String?  // "pending" | "processing" | "complete" | "failed"
    var aiLastExtractedAt: Date?
    var aiProcessingStartedAt: Date?
    var aiErrorType: String?
    var aiErrorMessage: String?
    var aiErrorRetryable: Bool?
    
    init(
        id: UUID = UUID(),
        frontImageData: Data? = nil,
        backImageData: Data? = nil,
        insideLeftImageData: Data? = nil,
        insideRightImageData: Data? = nil,
        dateScanned: Date = Date(),
        isFavorite: Bool = false,
        sender: String? = nil,
        occasion: String? = nil,
        dateReceived: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.frontImageData = frontImageData
        self.backImageData = backImageData
        self.insideLeftImageData = insideLeftImageData
        self.insideRightImageData = insideRightImageData
        self.dateScanned = dateScanned
        self.isFavorite = isFavorite
        self.sender = sender
        self.occasion = occasion
        self.dateReceived = dateReceived
        self.notes = notes
    }
    
    // MARK: - Computed Properties for Image Loading
    
    var frontImage: UIImage? {
        guard let data = frontImageData else { return nil }
        return UIImage(data: data)
    }
    
    var backImage: UIImage? {
        guard let data = backImageData else { return nil }
        return UIImage(data: data)
    }
    
    var insideLeftImage: UIImage? {
        guard let data = insideLeftImageData else { return nil }
        return UIImage(data: data)
    }
    
    var insideRightImage: UIImage? {
        guard let data = insideRightImageData else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Helper Methods for Setting Images
    
    /// Sets the front image from a UIImage
    func setFrontImage(_ image: UIImage?, compressionQuality: CGFloat = 0.8) {
        frontImageData = image?.jpegData(compressionQuality: compressionQuality)
    }
    
    /// Sets the back image from a UIImage
    func setBackImage(_ image: UIImage?, compressionQuality: CGFloat = 0.8) {
        backImageData = image?.jpegData(compressionQuality: compressionQuality)
    }
    
    /// Sets the inside left image from a UIImage
    func setInsideLeftImage(_ image: UIImage?, compressionQuality: CGFloat = 0.8) {
        insideLeftImageData = image?.jpegData(compressionQuality: compressionQuality)
    }
    
    /// Sets the inside right image from a UIImage
    func setInsideRightImage(_ image: UIImage?, compressionQuality: CGFloat = 0.8) {
        insideRightImageData = image?.jpegData(compressionQuality: compressionQuality)
    }
}
