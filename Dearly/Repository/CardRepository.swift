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
/// Images are now stored directly in SwiftData and sync via CloudKit
final class CardRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    /// Fetches all cards from the database
    func fetchAllCards() -> [Card] {
        let descriptor = FetchDescriptor<Card>(
            sortBy: [SortDescriptor(\.dateScanned, order: .reverse)]
        )
        
        do {
            let cards = try modelContext.fetch(descriptor)
            print("📦 CardRepository.fetchAllCards: Found \(cards.count) cards in SwiftData")
            return cards
        } catch {
            logger.error("Failed to fetch cards: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Adds a new card to the database
    func addCard(_ card: Card) {
        print("📦 CardRepository.addCard: Inserting card \(card.id)")
        modelContext.insert(card)
        save()
        print("📦 CardRepository.addCard: Card saved successfully")
    }
    
    /// Updates an existing card (SwiftData tracks changes automatically)
    func updateCard() {
        save()
    }
    
    /// Deletes a card (images are stored in SwiftData, so they're deleted automatically)
    func deleteCard(_ card: Card) {
        modelContext.delete(card)
        save()
    }
    
    /// Saves pending changes to the database
    func save() {
        do {
            try modelContext.save()
            print("💾 CardRepository.save: Context saved successfully")
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
    }
    

    // MARK: - Utility
    
    /// Clears all cards (for testing/reset)
    func clearAllData() {
        let cards = fetchAllCards()
        for card in cards {
            deleteCard(card)
        }
    }
}

