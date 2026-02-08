//
//  BackupManifest.swift
//  Dearly
//
//  Legacy backup info model (kept for migration support)
//

import Foundation

// MARK: - Backup Info

/// Information about an existing backup (used for legacy backup detection)
struct BackupInfo {
    /// Date the backup was created
    let backupDate: Date
    
    /// Number of cards in the backup
    let cardCount: Int
    
    /// App version that created the backup
    let appVersion: String
    
    /// Size of the backup file in bytes
    let fileSize: Int64
    
    /// URL to the backup file
    let fileURL: URL
}
