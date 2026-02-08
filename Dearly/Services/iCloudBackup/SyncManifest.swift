//
//  SyncManifest.swift
//  Dearly
//
//  Model for tracking synced cards in iCloud
//

import Foundation

// MARK: - Sync Manifest

/// Tracks which cards have been synced to iCloud and their state
struct SyncManifest: Codable {
    /// Version of the sync manifest format
    let version: Int
    
    /// Last time a full sync was performed
    var lastSyncDate: String
    
    /// Dictionary of card ID to sync info
    var cards: [String: SyncedCardInfo]
    
    init() {
        self.version = 1
        self.lastSyncDate = ISO8601DateFormatter().string(from: Date())
        self.cards = [:]
    }
}

// MARK: - Synced Card Info

/// Information about a synced card in iCloud
struct SyncedCardInfo: Codable {
    /// Filename in iCloud (e.g., "Mom_2025-01-15.dearly")
    let filename: String
    
    /// ISO 8601 timestamp when the card was last synced
    var syncedAt: String
    
    /// ISO 8601 timestamp of the card's updatedAt when synced
    /// Used to detect if the card has changed since last sync
    var cardUpdatedAt: String?
}

// MARK: - Cloud Card Info

/// Information about a card found in iCloud (for UI display)
struct CloudCardInfo {
    /// The .dearly filename
    let filename: String
    
    /// Full URL to the file in iCloud
    let url: URL
    
    /// File modification date
    let modifiedDate: Date
    
    /// File size in bytes
    let fileSize: Int64
}

// MARK: - Sync Result

/// Result of a sync operation
struct SyncResult {
    /// Number of cards uploaded to iCloud
    let uploaded: Int
    
    /// Number of cards that were already up to date
    let skipped: Int
    
    /// Number of cards that failed to sync
    let failed: Int
    
    /// Any error messages
    let errors: [String]
    
    var totalProcessed: Int {
        uploaded + skipped + failed
    }
    
    var isSuccess: Bool {
        failed == 0 && errors.isEmpty
    }
}

// MARK: - Restore Result

/// Result of a restore operation
struct RestoreResult {
    /// Number of cards imported from iCloud
    let imported: Int
    
    /// Number of cards skipped (already exist locally)
    let skipped: Int
    
    /// Number of cards that failed to import
    let failed: Int
    
    /// Any error messages
    let errors: [String]
    
    var totalProcessed: Int {
        imported + skipped + failed
    }
    
    var isSuccess: Bool {
        failed == 0 && errors.isEmpty
    }
}
