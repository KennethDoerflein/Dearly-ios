//
//  CardRepository.swift
//  Dearly
//
//  Created by Mark Mauro on 11/12/25.
//

import Foundation
import SwiftData
import UIKit
import os.log

private let logger = Logger(subsystem: "com.dearly.app", category: "CardRepository")

/// Repository for managing Card persistence with SwiftData
/// Handles coordination between SwiftData and ImageStorageService
final class CardRepository {
    private let modelContext: ModelContext
    private let imageStorage: ImageStorageService
    
    init(modelContext: ModelContext, imageStorage: ImageStorageService = .shared) {
        self.modelContext = modelContext
        self.imageStorage = imageStorage
    }
    
    // MARK: - CRUD Operations
    
    /// Fetches all cards from the database
    func fetchAllCards() -> [Card] {
        let descriptor = FetchDescriptor<Card>(
            sortBy: [SortDescriptor(\.dateScanned, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch cards: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Adds a new card to the database
    func addCard(_ card: Card) {
        modelContext.insert(card)
        save()
    }
    
    /// Updates an existing card (SwiftData tracks changes automatically)
    func updateCard() {
        save()
    }
    
    /// Deletes a card and its associated images
    func deleteCard(_ card: Card) {
        // Delete images from file system first
        imageStorage.deleteImages(for: card.id)
        
        // Delete from database
        modelContext.delete(card)
        save()
    }
    
    /// Saves pending changes to the database
    func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Metadata Update
    
    /// Updates card metadata and creates a version snapshot if changes were made
    func updateCardMetadata(
        _ card: Card,
        sender: String?,
        occasion: String?,
        dateReceived: Date?,
        notes: String?
    ) {
        var changes: [MetadataChange] = []
        
        if let change = Card.compare(.sender, old: card.sender, new: sender) {
            changes.append(change)
        }
        
        if let change = Card.compare(.occasion, old: card.occasion, new: occasion) {
            changes.append(change)
        }
        
        if let change = Card.compare(.dateReceived, old: card.dateReceived, new: dateReceived) {
            changes.append(change)
        }
        
        if let change = Card.compare(.notes, old: card.notes, new: notes) {
            changes.append(change)
        }
        
        // Create snapshot BEFORE applying changes
        if !changes.isEmpty {
            card.addSnapshot(metadataChanges: changes, imageChanges: [])
        }
        
        // Apply changes
        card.sender = sender
        card.occasion = occasion
        card.dateReceived = dateReceived
        card.notes = notes
        
        save()
        logger.info("Updated metadata for card \(card.id)")
    }
    
    // MARK: - Image Operations
    
    /// Saves images and creates a SINGLE snapshot for all image changes
    func saveImages(
        frontImage: UIImage?,
        backImage: UIImage?,
        insideLeftImage: UIImage?,
        insideRightImage: UIImage?,
        for cardId: UUID
    ) -> (front: String?, back: String?, insideLeft: String?, insideRight: String?) {
        
        var currentCard: Card?
        var imageChanges: [ImageChange] = []
        
        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.id == cardId })
        if let card = try? modelContext.fetch(descriptor).first {
            currentCard = card
        }
        
        // Calculate next version number ONCE for all changes in this batch
        let nextVersion = (currentCard?.versionHistory?.map { $0.versionNumber }.max() ?? 0) + 1
        
        func processImage(_ newImage: UIImage?, currentPath: String?, side: ImageSide, slot: ImageSlot) -> String? {
            guard let newImage = newImage else { return nil }
            
            if let currentPath = currentPath, imageStorage.imageExists(at: currentPath) {
                if let versionPath = imageStorage.saveVersionImage(from: currentPath, for: cardId, versionNumber: nextVersion) {
                    imageChanges.append(ImageChange(slot: slot, previousUri: versionPath))
                }
            }
            
            return imageStorage.saveImage(newImage, for: cardId, side: side)
        }
        
        let frontPath = processImage(frontImage, currentPath: currentCard?.frontImagePath, side: .front, slot: .front)
        let backPath = processImage(backImage, currentPath: currentCard?.backImagePath, side: .back, slot: .back)
        let insideLeftPath = processImage(insideLeftImage, currentPath: currentCard?.insideLeftImagePath, side: .insideLeft, slot: .insideLeft)
        let insideRightPath = processImage(insideRightImage, currentPath: currentCard?.insideRightImagePath, side: .insideRight, slot: .insideRight)
        
        // Create ONE snapshot for ALL image changes in this batch
        if !imageChanges.isEmpty, let card = currentCard {
            card.addSnapshot(metadataChanges: [], imageChanges: imageChanges)
            save()
            logger.info("Created snapshot v\(nextVersion) with \(imageChanges.count) image change(s)")
        }
        
        return (frontPath, backPath, insideLeftPath, insideRightPath)
    }
    
    // MARK: - Utility
    
    /// Clears all cards and their images (for testing/reset)
    func clearAllData() {
        let cards = fetchAllCards()
        for card in cards {
            deleteCard(card)
        }
        imageStorage.clearAllImages()
    }
}

