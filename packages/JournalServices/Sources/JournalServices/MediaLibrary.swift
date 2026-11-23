import Foundation
import CryptoKit

/// Keeps attachment bytes inside the journal vault. Transfers are sequential and become visible only after finish.
public final class MediaLibrary {
    public static let chunkSize = 256 * 1024
    public static let maxBytes = 80 * 1024 * 1024
    public static let maxPreviewBytes = 256 * 1024

    private struct Transfer {
        let uploadID: String
        let assetID: String
        let day: String
        let filename: String
        let mimeType: String
        let expectedBytes: Int
        let temporaryURL: URL
        let handle: FileHandle
        let preview: Data?
        var hasher = SHA256()
        var receivedBytes = 0
        var nextChunk = 0
    }

    private let store: JournalStore
    private let mediaDirectory: URL
    private let stagingDirectory: URL
    private var transfers: [String: Transfer] = [:]

    public init(vault: URL, store: JournalStore) throws {
        self.store = store
        mediaDirectory = vault.appendingPathComponent("media", isDirectory: true)
        stagingDirectory = vault.appendingPathComponent(".media-staging", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        // Interrupted transfers are never treated as saved memories.
        for url in try FileManager.default.contentsOfDirectory(at: stagingDirectory, includingPropertiesForKeys: nil) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func list(day: String) throws -> [MediaAsset] { try store.mediaAssets(day: day) }
    public func move(id: String, toDay: String) throws -> MediaAsset { try store.moveMedia(id: id, toDay: toDay) }

    public func begin(id: String, day: String, filename: String, mimeType: String, byteCount: Int, previewBase64: String?) throws -> String {
        try JournalStore.validateDay(day)
        guard let assetUUID = UUID(uuidString: id), byteCount > 0, byteCount <= Self.maxBytes,
              let normalizedMime = mimeType.lowercased().split(separator: ";", maxSplits: 1).first.map(String.init),
              JournalStore.mediaKind(normalizedMime) != nil,
              !filename.isEmpty, filename.utf8.count <= 240,
              !filename.contains("/") && !filename.contains("\\"),
              try store.mediaAsset(id: assetUUID.uuidString) == nil else {
            throw ServiceError("invalid", "Unsupported attachment, duplicate identifier, or file exceeds 80 MB.")
        }
        var preview: Data?
        if let previewBase64 {
            guard previewBase64.utf8.count <= Self.maxPreviewBytes * 4 / 3 + 8,
                  let decoded = Data(base64Encoded: previewBase64), decoded.count <= Self.maxPreviewBytes,
                  decoded.starts(with: [0xff, 0xd8]) else { throw ServiceError("invalid", "The image preview is invalid or too large.") }
            preview = decoded
        }
        let uploadID = UUID().uuidString
        let temporaryURL = stagingDirectory.appendingPathComponent(uploadID + ".part")
        guard FileManager.default.createFile(atPath: temporaryURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw ServiceError("storage", "Could not create an attachment staging file.")
        }
        let handle = try FileHandle(forWritingTo: temporaryURL)
        transfers[uploadID] = Transfer(uploadID: uploadID, assetID: assetUUID.uuidString, day: day,
                                       filename: filename, mimeType: normalizedMime, expectedBytes: byteCount,
                                       temporaryURL: temporaryURL, handle: handle, preview: preview)
        return uploadID
    }

    @discardableResult public func append(uploadID: String, chunkIndex: Int, base64: String) throws -> Int {
        guard var transfer = transfers[uploadID], chunkIndex == transfer.nextChunk,
              let bytes = Data(base64Encoded: base64), !bytes.isEmpty, bytes.count <= Self.chunkSize,
              transfer.receivedBytes + bytes.count <= transfer.expectedBytes else {
            throw ServiceError("invalid", "Attachment chunk is invalid, out of order, or too large.")
        }
        do { try transfer.handle.write(contentsOf: bytes) }
        catch { throw ServiceError("storage", "Could not write the attachment chunk.") }
        transfer.hasher.update(data: bytes)
        transfer.receivedBytes += bytes.count
        transfer.nextChunk += 1
        transfers[uploadID] = transfer
        return transfer.receivedBytes
    }

    public func finish(uploadID: String) throws -> MediaAsset {
        guard let transfer = transfers[uploadID] else { throw ServiceError("notFound", "This attachment upload has expired.") }
        guard transfer.receivedBytes == transfer.expectedBytes else { throw ServiceError("incomplete", "The attachment upload did not finish. Please retry it.") }
        try transfer.handle.synchronize()
        try transfer.handle.close()
        let fileURL = mediaDirectory.appendingPathComponent(transfer.assetID + ".bin")
        let previewURL = mediaDirectory.appendingPathComponent(transfer.assetID + ".preview.jpg")
        do {
            try FileManager.default.moveItem(at: transfer.temporaryURL, to: fileURL)
            if let preview = transfer.preview { try preview.write(to: previewURL, options: [.atomic]) }
            let asset = try store.registerMedia(id: transfer.assetID, day: transfer.day, filename: transfer.filename,
                                                mimeType: transfer.mimeType, byteCount: transfer.expectedBytes,
                                                hasPreview: transfer.preview != nil,
                                                contentDigest: transfer.hasher.finalize().map { String(format: "%02x", $0) }.joined())
            transfers.removeValue(forKey: uploadID)
            return asset
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: previewURL)
            transfers.removeValue(forKey: uploadID)
            throw error
        }
    }

    public func cancel(uploadID: String) {
        guard let transfer = transfers.removeValue(forKey: uploadID) else { return }
        try? transfer.handle.close()
        try? FileManager.default.removeItem(at: transfer.temporaryURL)
    }

    public func preview(id: String) throws -> String {
        guard let asset = try store.mediaAsset(id: id), asset.hasPreview else { throw ServiceError("notFound", "This attachment has no preview.") }
        let url = mediaDirectory.appendingPathComponent(asset.id + ".preview.jpg")
        guard let data = try? Data(contentsOf: url), data.count <= Self.maxPreviewBytes else { throw ServiceError("notFound", "The attachment preview is unavailable.") }
        return data.base64EncodedString()
    }

    public func read(id: String, offset: Int, length: Int) throws -> [String: Any] {
        guard let asset = try store.mediaAsset(id: id), offset >= 0, offset <= asset.byteCount,
              length > 0, length <= Self.chunkSize else { throw ServiceError("invalid", "Invalid attachment read range.") }
        let url = mediaDirectory.appendingPathComponent(asset.id + ".bin")
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(offset))
            let data = try handle.read(upToCount: min(length, asset.byteCount - offset)) ?? Data()
            return ["id": asset.id, "mimeType": asset.mimeType, "offset": offset,
                    "nextOffset": offset + data.count, "done": offset + data.count >= asset.byteCount,
                    "data": data.base64EncodedString()]
        } catch { throw ServiceError("storage", "Could not read the saved attachment.") }
    }

    public func analysisSource(id: String) throws -> URL {
        guard let asset = try store.mediaAsset(id: id), ["audio", "video"].contains(asset.kind) else { throw ServiceError("invalid", "Choose a saved audio or video memory.") }
        let url = mediaDirectory.appendingPathComponent(asset.id + ".bin")
        guard let bytes = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber, bytes.intValue == asset.byteCount else { throw ServiceError("storage", "Original recording is unavailable or incomplete.") }
        return url
    }

    public func visualSource(id: String) throws -> (URL, String, String) {
        guard let asset = try store.mediaAsset(id: id), ["photo", "video"].contains(asset.kind) else { throw ServiceError("invalid", "Choose a photo or video memory.") }
        let url = mediaDirectory.appendingPathComponent(asset.id + ".bin")
        guard let bytes = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber, bytes.intValue == asset.byteCount else { throw ServiceError("storage", "Original media is unavailable or incomplete.") }
        return (url, asset.kind, asset.mimeType)
    }

    public func delete(id: String) throws {
        let asset = try store.deleteMedia(id: id)
        try? FileManager.default.removeItem(at: mediaDirectory.appendingPathComponent(asset.id + ".bin"))
        try? FileManager.default.removeItem(at: mediaDirectory.appendingPathComponent(asset.id + ".preview.jpg"))
    }
}
