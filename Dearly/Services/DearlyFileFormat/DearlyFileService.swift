//
//  DearlyFileService.swift
//  Dearly
//
//  Main service for exporting and importing .dearly files
//

import Foundation
import UIKit
import SwiftData

/// Service for exporting and importing cards in the .dearly file format
final class DearlyFileService {
    
    /// Shared singleton instance
    static let shared = DearlyFileService()
    
    /// File manager instance
    private let fileManager = FileManager.default
    
    /// Image storage service
    private let imageStorage = ImageStorageService.shared
    
    /// Supported image extensions
    private let supportedImageExtensions = ["jpg", "jpeg", "png", "webp", "heic"]
    
    private init() {}
    
    // MARK: - Export
    
    /// Exports a card to a .dearly file
    /// - Parameter card: The card to export
    /// - Returns: URL to the exported .dearly file
    /// - Throws: DearlyFileError if export fails
    func exportCard(_ card: Card) throws -> URL {
        // Create temporary directory for building the archive
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temp directory
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Front image (required)
        guard let frontImage = card.frontImage,
              let frontData = frontImage.jpegData(compressionQuality: 0.9) else {
            throw DearlyFileError.exportError("Front image is required but not available")
        }
        let frontFilename = "front.jpg"
        try frontData.write(to: tempDir.appendingPathComponent(frontFilename))
        
        // Back image (required)
        guard let backImage = card.backImage,
              let backData = backImage.jpegData(compressionQuality: 0.9) else {
            throw DearlyFileError.exportError("Back image is required but not available")
        }
        let backFilename = "back.jpg"
        try backData.write(to: tempDir.appendingPathComponent(backFilename))
        
        // Inside left image (optional)
        var insideLeftFilename: String? = nil
        if let insideLeftImage = card.insideLeftImage,
           let insideLeftData = insideLeftImage.jpegData(compressionQuality: 0.9) {
            insideLeftFilename = "inside_left.jpg"
            try insideLeftData.write(to: tempDir.appendingPathComponent(insideLeftFilename!))
        }
        
        // Inside right image (optional)
        var insideRightFilename: String? = nil
        if let insideRightImage = card.insideRightImage,
           let insideRightData = insideRightImage.jpegData(compressionQuality: 0.9) {
            insideRightFilename = "inside_right.jpg"
            try insideRightData.write(to: tempDir.appendingPathComponent(insideRightFilename!))
        }
        
        let images = DearlyImages(
            front: frontFilename,
            back: backFilename,
            insideLeft: insideLeftFilename,
            insideRight: insideRightFilename
        )
        
        // Build manifest
        let cardData = DearlyCardData.from(card)
        let manifest = DearlyManifest(card: cardData, images: images)
        
        // Write manifest.json
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))
        
        // Create ZIP archive
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsDir = documentsDir.appendingPathComponent("Exports", isDirectory: true)
        try fileManager.createDirectory(at: exportsDir, withIntermediateDirectories: true)
        
        // Generate filename from card metadata
        let senderPart = card.sender?.replacingOccurrences(of: " ", with: "_")
            .prefix(20) ?? "card"
        let datePart = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: card.dateReceived ?? card.dateScanned)
        }()
        let exportFilename = "\(senderPart)_\(datePart).dearly"
        let exportURL = exportsDir.appendingPathComponent(exportFilename)
        
        // Remove existing file if present
        if fileManager.fileExists(atPath: exportURL.path) {
            try fileManager.removeItem(at: exportURL)
        }
        
        // Create the ZIP archive using native approach
        try createZipArchive(from: tempDir, to: exportURL)
        
        print("✅ Exported card to: \(exportURL.path)")
        return exportURL
    }
    
    // MARK: - Import
    
    /// Imports a card from a .dearly file
    /// - Parameters:
    ///   - url: URL to the .dearly file
    ///   - modelContext: SwiftData model context for saving the card
    /// - Returns: The imported Card
    /// - Throws: DearlyFileError if import fails
    func importCard(from url: URL, using modelContext: ModelContext) throws -> Card {
        // Create temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temp directory
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Extract the archive
        try extractZipArchive(from: url, to: tempDir)
        
        // Parse and validate manifest
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw DearlyFileError.missingManifest
        }
        
        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        let manifest: DearlyManifest
        do {
            manifest = try decoder.decode(DearlyManifest.self, from: manifestData)
        } catch {
            throw DearlyFileError.invalidManifest(error.localizedDescription)
        }
        
        // Validate version
        if manifest.formatVersion > DearlyFormatVersion {
            throw DearlyFileError.unsupportedVersion(manifest.formatVersion)
        }
        
        // Generate new UUID per spec requirement
        let newCardId = UUID()
        
        // Extract and save images
        let frontPath = try saveImportedImage(
            filename: manifest.images.front,
            from: tempDir,
            cardId: newCardId,
            side: .front
        )
        
        let backPath = try saveImportedImage(
            filename: manifest.images.back,
            from: tempDir,
            cardId: newCardId,
            side: .back
        )
        
        var insideLeftPath: String? = nil
        if let insideLeftFilename = manifest.images.insideLeft {
            insideLeftPath = try saveImportedImage(
                filename: insideLeftFilename,
                from: tempDir,
                cardId: newCardId,
                side: .insideLeft
            )
        }
        
        var insideRightPath: String? = nil
        if let insideRightFilename = manifest.images.insideRight {
            insideRightPath = try saveImportedImage(
                filename: insideRightFilename,
                from: tempDir,
                cardId: newCardId,
                side: .insideRight
            )
        }
        
        // Parse dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let cardDate = dateFormatter.date(from: manifest.card.date)
        
        let isoFormatter = ISO8601DateFormatter()
        let createdAt = manifest.card.createdAt.flatMap { isoFormatter.date(from: $0) }
        let updatedAt = manifest.card.updatedAt.flatMap { isoFormatter.date(from: $0) }
        
        // Create the new card
        let card = Card(
            id: newCardId,
            frontImagePath: frontPath,
            backImagePath: backPath,
            insideLeftImagePath: insideLeftPath,
            insideRightImagePath: insideRightPath,
            dateScanned: Date(),
            isFavorite: manifest.card.isFavorite,
            sender: manifest.card.sender,
            occasion: manifest.card.occasion,
            dateReceived: cardDate,
            notes: manifest.card.notes
        )
        
        // Set extended properties
        card.cardType = manifest.card.type?.rawValue
        card.aspectRatio = manifest.card.aspectRatio
        card.createdAt = createdAt ?? Date()
        card.updatedAt = updatedAt
        
        // Set AI extraction data if present
        if let aiData = manifest.card.aiExtractedData {
            card.aiExtractedText = aiData.extractedText
            card.aiDetectedSender = aiData.detectedSender
            card.aiDetectedOccasion = aiData.detectedOccasion
            card.aiSentiment = aiData.sentiment
            card.aiMentionedDates = aiData.mentionedDates
            card.aiKeywords = aiData.keywords
            card.aiExtractionStatus = aiData.status.rawValue
            card.aiLastExtractedAt = aiData.lastExtractedAt.flatMap { isoFormatter.date(from: $0) }
            card.aiProcessingStartedAt = aiData.processingStartedAt.flatMap { isoFormatter.date(from: $0) }
            
            // Set error data if present
            if let error = aiData.error {
                card.aiErrorType = error.type.rawValue
                card.aiErrorMessage = error.message
                card.aiErrorRetryable = error.retryable
            }
        }
        
        // Save to SwiftData
        modelContext.insert(card)
        try modelContext.save()
        
        print("✅ Imported card: \(newCardId)")
        return card
    }
    
    // MARK: - Validation
    
    /// Validates a .dearly file without importing
    /// - Parameter url: URL to the .dearly file
    /// - Returns: Result with the parsed manifest or an error
    func validateFile(at url: URL) -> Result<DearlyManifest, DearlyFileError> {
        do {
            // Create temporary directory for extraction
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            defer {
                try? fileManager.removeItem(at: tempDir)
            }
            
            // Extract the archive
            try extractZipArchive(from: url, to: tempDir)
            
            // Parse manifest
            let manifestURL = tempDir.appendingPathComponent("manifest.json")
            guard fileManager.fileExists(atPath: manifestURL.path) else {
                return .failure(.missingManifest)
            }
            
            let manifestData = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            let manifest = try decoder.decode(DearlyManifest.self, from: manifestData)
            
            // Validate version
            if manifest.formatVersion > DearlyFormatVersion {
                return .failure(.unsupportedVersion(manifest.formatVersion))
            }
            
            // Validate required images exist
            guard fileManager.fileExists(atPath: tempDir.appendingPathComponent(manifest.images.front).path) else {
                return .failure(.missingImage(manifest.images.front))
            }
            
            guard fileManager.fileExists(atPath: tempDir.appendingPathComponent(manifest.images.back).path) else {
                return .failure(.missingImage(manifest.images.back))
            }
            
            return .success(manifest)
        } catch let error as DearlyFileError {
            return .failure(error)
        } catch {
            return .failure(.fileOperationError(error.localizedDescription))
        }
    }
    
    // MARK: - Private Methods - ZIP Operations
    
    /// Creates a ZIP archive from a directory using native approach
    private func createZipArchive(from sourceDir: URL, to destinationURL: URL) throws {
        // Collect all files to include
        let files = try fileManager.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil)
        
        // Create ZIP using a simple PKZip-compatible format
        var zipWriter = ZipWriter()
        
        for fileURL in files {
            let fileName = fileURL.lastPathComponent
            let fileData = try Data(contentsOf: fileURL)
            // Use STORE (no compression) per spec v1.1 recommendation - images are already compressed
            try zipWriter.addEntry(name: fileName, data: fileData, compressionMethod: .store)
        }
        
        let zipData = try zipWriter.finalize()
        try zipData.write(to: destinationURL)
    }
    
    /// Extracts a ZIP archive to a directory using native approach
    private func extractZipArchive(from sourceURL: URL, to destinationDir: URL) throws {
        let zipData = try Data(contentsOf: sourceURL)
        
        let zipReader = try ZipReader(data: zipData)
        for entry in zipReader.entries {
            let entryURL = destinationDir.appendingPathComponent(entry.name)
            try entry.data.write(to: entryURL)
        }
    }
    
    /// Saves an imported image to the image storage
    private func saveImportedImage(
        filename: String,
        from tempDir: URL,
        cardId: UUID,
        side: ImageSide
    ) throws -> String {
        let sourceURL = tempDir.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw DearlyFileError.missingImage(filename)
        }
        
        guard let image = UIImage(contentsOfFile: sourceURL.path) else {
            throw DearlyFileError.invalidCardData("Could not load image: \(filename)")
        }
        
        guard let path = imageStorage.saveImage(image, for: cardId, side: side) else {
            throw DearlyFileError.writeError("Failed to save image: \(filename)")
        }
        
        return path
    }
}

// MARK: - Simple ZIP Implementation

import Compression

enum ZipCompressionMethod: UInt16 {
    case store = 0
    case deflate = 8
}

/// A lightweight ZIP file writer compatible with PKZip format
private struct ZipWriter {
    private var entries: [(name: String, compressedData: Data, uncompressedSize: UInt32, crc32: UInt32, method: ZipCompressionMethod)] = []
    
    mutating func addEntry(name: String, data: Data, compressionMethod: ZipCompressionMethod = .store) throws {
        let crc = data.crc32()
        let uncompressedSize = UInt32(data.count)
        
        var compressedData: Data
        var method = compressionMethod
        
        switch compressionMethod {
        case .store:
            compressedData = data
            
        case .deflate:
            // Compress data using raw DEFLATE by stripping ZLIB headers
            let bufferSize = max(size_t(data.count), 64 * 1024)
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { destinationBuffer.deallocate() }
            
            let sourceData = data as NSData
            
            // Use zlib compression
            let compressedSize = compression_encode_buffer(
                destinationBuffer,
                bufferSize,
                sourceData.bytes.bindMemory(to: UInt8.self, capacity: data.count),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
            
            if compressedSize > 0 {
                // Strip zlib header (2 bytes) and checksum (4 bytes) to get raw DEFLATE
                if compressedSize > 6 {
                    let rawDeflateData = Data(bytes: destinationBuffer.advanced(by: 2), count: compressedSize - 6)
                    compressedData = rawDeflateData
                } else {
                    // Fallback to store
                    compressedData = data
                    method = .store
                }
            } else {
                // Fallback to store
                compressedData = data
                method = .store
            }
        }
        
        entries.append((name: name, compressedData: compressedData, uncompressedSize: uncompressedSize, crc32: crc, method: method))
    }
    
    func finalize() throws -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0
        
        // Write local file headers and data
        for entry in entries {
            let localHeader = createLocalFileHeader(
                name: entry.name,
                compressedSize: UInt32(entry.compressedData.count),
                uncompressedSize: entry.uncompressedSize,
                crc32: entry.crc32,
                method: entry.method
            )
            archive.append(localHeader)
            archive.append(entry.compressedData)
            
            // Create central directory entry
            let centralEntry = createCentralDirectoryEntry(
                name: entry.name,
                compressedSize: UInt32(entry.compressedData.count),
                uncompressedSize: entry.uncompressedSize,
                crc32: entry.crc32,
                method: entry.method,
                offset: offset
            )
            centralDirectory.append(centralEntry)
            
            offset = UInt32(archive.count)
        }
        
        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        
        // Write end of central directory
        let endRecord = createEndOfCentralDirectory(
            entryCount: UInt16(entries.count),
            centralDirectorySize: UInt32(centralDirectory.count),
            centralDirectoryOffset: centralDirectoryOffset
        )
        archive.append(endRecord)
        
        return archive
    }
    
    private func createLocalFileHeader(name: String, compressedSize: UInt32, uncompressedSize: UInt32, crc32: UInt32, method: ZipCompressionMethod) -> Data {
        var header = Data()
        let nameData = name.data(using: .utf8) ?? Data()
        
        header.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Local file header signature
        header.append(contentsOf: UInt16(20).littleEndianBytes) // Version needed
        header.append(contentsOf: UInt16(0).littleEndianBytes) // General purpose bit flag
        header.append(contentsOf: method.rawValue.littleEndianBytes) // Compression method
        header.append(contentsOf: UInt16(0).littleEndianBytes) // Last mod file time
        header.append(contentsOf: UInt16(0).littleEndianBytes) // Last mod file date
        header.append(contentsOf: crc32.littleEndianBytes) // CRC-32
        header.append(contentsOf: compressedSize.littleEndianBytes) // Compressed size
        header.append(contentsOf: uncompressedSize.littleEndianBytes) // Uncompressed size
        header.append(contentsOf: UInt16(nameData.count).littleEndianBytes) // File name length
        header.append(contentsOf: UInt16(0).littleEndianBytes) // Extra field length
        header.append(nameData) // File name
        
        return header
    }
    
    private func createCentralDirectoryEntry(name: String, compressedSize: UInt32, uncompressedSize: UInt32, crc32: UInt32, method: ZipCompressionMethod, offset: UInt32) -> Data {
        var entry = Data()
        let nameData = name.data(using: .utf8) ?? Data()
        
        entry.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // Central directory signature
        entry.append(contentsOf: UInt16(20).littleEndianBytes) // Version made by
        entry.append(contentsOf: UInt16(20).littleEndianBytes) // Version needed
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // General purpose bit flag
        entry.append(contentsOf: method.rawValue.littleEndianBytes) // Compression method
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Last mod file time
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Last mod file date
        entry.append(contentsOf: crc32.littleEndianBytes) // CRC-32
        entry.append(contentsOf: compressedSize.littleEndianBytes) // Compressed size
        entry.append(contentsOf: uncompressedSize.littleEndianBytes) // Uncompressed size
        entry.append(contentsOf: UInt16(nameData.count).littleEndianBytes) // File name length
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Extra field length
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // File comment length
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Disk number start
        entry.append(contentsOf: UInt16(0).littleEndianBytes) // Internal file attributes
        entry.append(contentsOf: UInt32(0).littleEndianBytes) // External file attributes
        entry.append(contentsOf: offset.littleEndianBytes) // Relative offset of local header
        entry.append(nameData) // File name
        
        return entry
    }
    
    private func createEndOfCentralDirectory(entryCount: UInt16, centralDirectorySize: UInt32, centralDirectoryOffset: UInt32) -> Data {
        var endRecord = Data()
        
        endRecord.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // End of central directory signature
        endRecord.append(contentsOf: UInt16(0).littleEndianBytes) // Disk number
        endRecord.append(contentsOf: UInt16(0).littleEndianBytes) // Disk number with central directory
        endRecord.append(contentsOf: entryCount.littleEndianBytes) // Number of entries on this disk
        endRecord.append(contentsOf: entryCount.littleEndianBytes) // Total number of entries
        endRecord.append(contentsOf: centralDirectorySize.littleEndianBytes) // Size of central directory
        endRecord.append(contentsOf: centralDirectoryOffset.littleEndianBytes) // Offset of central directory
        endRecord.append(contentsOf: UInt16(0).littleEndianBytes) // Comment length
        
        return endRecord
    }
}

/// A lightweight ZIP file reader
private struct ZipReader {
    struct Entry {
        let name: String
        let data: Data
    }
    
    let entries: [Entry]
    
    init(data: Data) throws {
        var entries: [Entry] = []
        var offset = 0
        
        // Validate ZIP signature at start of file
        guard data.count >= 4 else {
            throw DearlyFileError.invalidZip
        }
        
        let initialSignature = data.subdata(in: 0..<4)
        guard initialSignature == Data([0x50, 0x4B, 0x03, 0x04]) else {
            throw DearlyFileError.invalidZip
        }
        
        while offset < data.count - 4 {
            // Check for local file header signature
            let signature = data.subdata(in: offset..<offset+4)
            if signature != Data([0x50, 0x4B, 0x03, 0x04]) {
                break
            }
            
            offset += 4
            
            // Skip version needed (2)
            offset += 2
            
            // Skip flags (2)
            offset += 2
            
            // Read compression method (2 bytes)
            guard offset + 2 <= data.count else { break }
            let compressionMethod = data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            offset += 2
            
            // Skip time (2), date (2)
            offset += 4
            
            // Read CRC-32 (4 bytes)
            offset += 4
            
            // Read compressed size (4 bytes)
            guard offset + 4 <= data.count else { break }
            let compressedSize = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            offset += 4
            
            // Read uncompressed size (4 bytes) - useful for buffer allocation if needed
            guard offset + 4 <= data.count else { break }
            let uncompressedSize = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            offset += 4
            
            // Read file name length (2 bytes)
            guard offset + 2 <= data.count else { break }
            let nameLength = data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            offset += 2
            
            // Read extra field length (2 bytes)
            guard offset + 2 <= data.count else { break }
            let extraLength = data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            offset += 2
            
            // Read file name
            guard offset + Int(nameLength) <= data.count else { break }
            let nameData = data.subdata(in: offset..<offset+Int(nameLength))
            let name = String(data: nameData, encoding: .utf8) ?? ""
            offset += Int(nameLength)
            
            // Skip extra field
            offset += Int(extraLength)
            
            // Read file data
            guard offset + Int(compressedSize) <= data.count else { break }
            let compressedData = data.subdata(in: offset..<offset+Int(compressedSize))
            offset += Int(compressedSize)
            
            // Decompress if needed
            let uncompressedData: Data
            if compressionMethod == ZipCompressionMethod.store.rawValue {
                uncompressedData = compressedData
            } else if compressionMethod == ZipCompressionMethod.deflate.rawValue {
                // Decompress raw DEFLATE data
                // Create ZLIB header: CMF (0x78) + FLG (0x9C)
                // This satisfies (CMF * 256 + FLG) % 31 == 0 check
                var zlibData = Data([0x78, 0x9C])
                zlibData.append(compressedData)
                
                let bufferSize = Int(uncompressedSize) + 1024
                let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { destinationBuffer.deallocate() }
                
                let sourceData = zlibData as NSData
                
                let decodedSize = compression_decode_buffer(
                    destinationBuffer,
                    bufferSize,
                    sourceData.bytes.bindMemory(to: UInt8.self, capacity: zlibData.count),
                    zlibData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
                
                if decodedSize > 0 {
                    uncompressedData = Data(bytes: destinationBuffer, count: decodedSize)
                } else {
                    // Fallback: try decompressing without prepended header
                    print("⚠️ Failed to decompress \(name) with header. Retrying raw...")
                    
                    let rawSource = compressedData as NSData
                     let decodedSize2 = compression_decode_buffer(
                         destinationBuffer,
                         bufferSize,
                         rawSource.bytes.bindMemory(to: UInt8.self, capacity: compressedData.count),
                         compressedData.count,
                         nil,
                         COMPRESSION_ZLIB
                     )
                    
                    if decodedSize2 > 0 {
                         uncompressedData = Data(bytes: destinationBuffer, count: decodedSize2)
                    } else {
                         throw DearlyFileError.invalidCardData("Decompression failed for \(name)")
                    }
                }
            } else {
                throw DearlyFileError.invalidCardData("Unsupported compression method: \(compressionMethod)")
            }
            
            entries.append(Entry(name: name, data: uncompressedData))
        }
        
        self.entries = entries
    }
}

// MARK: - Data Extensions for ZIP

private extension Data {
    /// Calculate CRC-32 checksum
    func crc32() -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = Self.crc32Table
        
        for byte in self {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        
        return ~crc
    }
    
    /// CRC-32 lookup table
    private static let crc32Table: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }()
}

private extension UInt16 {
    var littleEndianBytes: [UInt8] {
        let value = self.littleEndian
        return [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }
}

private extension UInt32 {
    var littleEndianBytes: [UInt8] {
        let value = self.littleEndian
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }
}
