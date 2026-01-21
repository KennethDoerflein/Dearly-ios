//
//  CardVersionHistory.swift
//  Dearly
//
//  Created on 1/21/26.
//

import Foundation
import SwiftData

/// Type-safe enum for metadata fields
enum MetadataField: String, Codable, CaseIterable {
    case sender = "Sender"
    case occasion = "Occasion"
    case dateReceived = "Date Received"
    case notes = "Notes"
    
    /// For restored fields
    var restoredName: String { "\(rawValue) (Restored)" }
}

/// Snapshot of a card's state at a specific point in time
struct CardVersionSnapshot: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let versionNumber: Int
    let editedAt: Date
    let metadataChanges: [MetadataChange]
    let imageChanges: [ImageChange]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CardVersionSnapshot, rhs: CardVersionSnapshot) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a change to a single metadata field
struct MetadataChange: Codable, Hashable {
    let field: MetadataField
    let previousValue: String?
    let newValue: String?
}

/// Type-safe enum for image slots
enum ImageSlot: String, Codable, CaseIterable {
    case front
    case back
    case insideLeft
    case insideRight
}

/// Represents a change to a card's image
struct ImageChange: Codable, Hashable {
    let slot: ImageSlot
    let previousUri: String
}
