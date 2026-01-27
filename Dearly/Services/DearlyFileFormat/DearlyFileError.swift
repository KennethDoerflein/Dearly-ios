//
//  DearlyFileError.swift
//  Dearly
//
//  Error types for .dearly file operations
//

import Foundation

/// Errors that can occur during .dearly file operations
enum DearlyFileError: LocalizedError {
    /// File is not a valid ZIP archive
    case invalidZip
    
    /// manifest.json not found in archive
    case missingManifest
    
    /// manifest.json is malformed or invalid JSON
    case invalidManifest(String)
    
    /// formatVersion is higher than supported
    case unsupportedVersion(Double)
    
    /// Required image file referenced in manifest not found
    case missingImage(String)
    
    /// Card metadata fails validation
    case invalidCardData(String)
    
    /// Failed to write extracted images to storage
    case writeError(String)
    
    /// Failed to create the export archive
    case exportError(String)
    
    /// Generic file operation error
    case fileOperationError(String)
    
    /// Tried to import a backup bundle as a single card
    case backupBundleDetected
    
    var errorDescription: String? {
        switch self {
        case .invalidZip:
            return "The file is not a valid .dearly archive"
        case .missingManifest:
            return "The archive is missing the required manifest.json file"
        case .invalidManifest(let detail):
            return "Failed to parse manifest: \(detail)"
        case .unsupportedVersion(let version):
            return "Unsupported file format version: \(version). Please update the app to import this file."
        case .missingImage(let filename):
            return "Required image not found in archive: \(filename)"
        case .invalidCardData(let detail):
            return "Invalid card data: \(detail)"
        case .writeError(let detail):
            return "Failed to save images: \(detail)"
        case .exportError(let detail):
            return "Failed to export card: \(detail)"
        case .fileOperationError(let detail):
            return "File operation failed: \(detail)"
        case .backupBundleDetected:
            return "This is a backup archive. Use 'Restore from Backup' instead."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidZip:
            return "Make sure the file has a .dearly extension and was exported from the Dearly app."
        case .missingManifest:
            return "The file may be corrupted. Try exporting it again from the source."
        case .invalidManifest:
            return "The file may be corrupted. Try exporting it again from the source."
        case .unsupportedVersion:
            return "Check for app updates to support newer file formats."
        case .missingImage:
            return "The file may be corrupted. Try exporting it again from the source."
        case .invalidCardData:
            return "The file may be corrupted. Try exporting it again from the source."
        case .writeError:
            return "Check that the app has permission to save files and there is enough storage space."
        case .exportError:
            return "Try exporting the card again. If the problem persists, restart the app."
        case .fileOperationError:
            return "Try the operation again. If the problem persists, restart the app."
        case .backupBundleDetected:
            return "This file contains multiple cards. Go to Settings > Restore from Backup to import it."
        }
    }
}
