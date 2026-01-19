//
//  DearlyFileServiceTests.swift
//  DearlyTests
//
//  Created by Mark Mauro on 1/14/26.
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import Dearly

struct DearlyFileServiceTests {

    @Test func testExportAndImportCard() async throws {
        // Setup
        let service = DearlyFileService.shared
        let schema = Schema([Card.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let mainContext = ModelContext(try ModelContainer(for: schema, configurations: [modelConfiguration]))
        
        // create a dummy image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let img = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let imgData = img.jpegData(compressionQuality: 0.9)!
        
        // Create dummy card
        let cardId = UUID()
        // Save images manually to storage
        let storage = ImageStorageService.shared
        let frontPath = storage.saveImage(img, for: cardId, side: .front)
        let backPath = storage.saveImage(img, for: cardId, side: .back)
        
        let card = Card(
            id: cardId,
            frontImagePath: frontPath,
            backImagePath: backPath,
            insideLeftImagePath: nil,
            insideRightImagePath: nil,
            dateScanned: Date(),
            isFavorite: true,
            sender: "Test Sender",
            occasion: "Test Occasion",
            dateReceived: Date(),
            notes: "Test Notes"
        )
        
        mainContext.insert(card)
        
        // 1. Test Export
        let exportURL = try service.exportCard(card)
        #expect(FileManager.default.fileExists(atPath: exportURL.path))
        #expect(exportURL.pathExtension == "dearly")
        
        // Verify ZIP integrity (basic)
        let data = try Data(contentsOf: exportURL)
        #expect(data.count > 0)
        // Check local file header signature
        #expect(data.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]))
        
        // Verify Compression Method is STORE (0)
        // Offset 8 (2 bytes)
        let compressionMethod = data.subdata(in: 8..<10).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
        #expect(compressionMethod == 0, "Expected STORE compression (0), but got \(compressionMethod)")
        
        // 2. Test Import
        // Import into same context (it will create a NEW card with NEW ID per spec)
        let importedCard = try service.importCard(from: exportURL, using: mainContext)
        
        #expect(importedCard.sender == "Test Sender")
        #expect(importedCard.occasion == "Test Occasion")
        #expect(importedCard.notes == "Test Notes")
        #expect(importedCard.isFavorite == true)
        #expect(importedCard.id != card.id) // Should be a new ID
        
        // Verify images were saved
        #expect(importedCard.frontImagePath != nil)
        #expect(importedCard.backImagePath != nil)
        
        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }
    
    @Test func testExportAndImportCardWithAIData() async throws {
        // Setup
        let service = DearlyFileService.shared
        let schema = Schema([Card.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let mainContext = ModelContext(try ModelContainer(for: schema, configurations: [modelConfiguration]))
        
        // Create a dummy image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let img = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        
        // Create dummy card with AI data
        let cardId = UUID()
        let storage = ImageStorageService.shared
        let frontPath = storage.saveImage(img, for: cardId, side: .front)
        let backPath = storage.saveImage(img, for: cardId, side: .back)
        
        let card = Card(
            id: cardId,
            frontImagePath: frontPath,
            backImagePath: backPath,
            insideLeftImagePath: nil,
            insideRightImagePath: nil,
            dateScanned: Date(),
            isFavorite: true,
            sender: "AI Test Sender",
            occasion: "Test Occasion",
            dateReceived: Date(),
            notes: "Test Notes with AI Data"
        )
        
        // Set AI extraction data
        card.aiExtractedText = "Merry Christmas!\nWith love from the family..."
        card.aiDetectedSender = "The Smith Family"
        card.aiDetectedOccasion = "Christmas"
        card.aiSentiment = "positive"
        card.aiMentionedDates = ["2025-12-25"]
        card.aiKeywords = ["family", "love", "holidays"]
        card.aiExtractionStatus = "complete"
        card.aiLastExtractedAt = Date()
        
        mainContext.insert(card)
        
        // 1. Test Export
        let exportURL = try service.exportCard(card)
        #expect(FileManager.default.fileExists(atPath: exportURL.path))
        
        // 2. Test Import
        let importedCard = try service.importCard(from: exportURL, using: mainContext)
        
        // Verify basic data
        #expect(importedCard.sender == "AI Test Sender")
        #expect(importedCard.id != card.id) // Should be a new ID
        
        // Verify AI extraction data is preserved
        #expect(importedCard.aiExtractedText == "Merry Christmas!\nWith love from the family...")
        #expect(importedCard.aiDetectedSender == "The Smith Family")
        #expect(importedCard.aiDetectedOccasion == "Christmas")
        #expect(importedCard.aiSentiment == "positive")
        #expect(importedCard.aiMentionedDates == ["2025-12-25"])
        #expect(importedCard.aiKeywords == ["family", "love", "holidays"])
        #expect(importedCard.aiExtractionStatus == "complete")
        #expect(importedCard.aiLastExtractedAt != nil)
        
        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }
}
