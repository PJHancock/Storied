import Foundation
import CryptoKit
import CSQLite

/// A directory backup with a database snapshot and independently verified managed media.
/// Restore always creates a new vault; it never replaces a running journal.
public enum JournalBackup {
    private struct FileRecord: Codable { let name: String; let bytes: Int; let sha256: String }
    private struct Manifest: Codable { let format: String; let version: Int; let createdAt: String; let files: [FileRecord] }
    public struct Result: Sendable { public let url: URL; public let mediaCount: Int }
    private static let format = "memory-catcher-directory-backup"
    private static let fm = FileManager.default

    private static func regular(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw ServiceError("backup", "A backup file is missing or is not a regular file.") }
    }
    private static func record(_ url: URL, name: String) throws -> FileRecord {
        try regular(url)
        let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
        var hasher = SHA256(), size = 0
        while let data = try file.read(upToCount: 1024 * 1024), !data.isEmpty {
            size += data.count; hasher.update(data: data)
        }
        return FileRecord(name: name, bytes: size, sha256: hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }
    private static func inspectDatabase(_ url: URL) throws {
        try regular(url)
        var db: OpaquePointer?
        // These are closed, immutable artifacts. URI immutable mode lets SQLite check a
        // standalone WAL-mode snapshot without requiring sibling -wal/-shm files.
        guard sqlite3_open_v2(url.absoluteString + "?immutable=1", &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK, let db else {
            if db != nil { sqlite3_close(db) }; throw ServiceError("backup", "The backup database cannot be opened.")
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &statement, nil) == SQLITE_OK, let statement else { throw ServiceError("backup", "The backup database cannot be checked: " + String(cString: sqlite3_errmsg(db))) }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let value = sqlite3_column_text(statement, 0), String(cString: value) == "ok" else { throw ServiceError("backup", "The backup database failed its integrity check.") }
    }
    private static func mediaNames(_ assets: [MediaAsset]) throws -> [String] {
        var names: [String] = []
        for asset in assets {
            guard UUID(uuidString: asset.id) != nil, asset.byteCount > 0, asset.byteCount <= MediaLibrary.maxBytes else { throw ServiceError("backup", "The journal contains invalid media metadata.") }
            names.append(asset.id + ".bin")
            if asset.hasPreview { names.append(asset.id + ".preview.jpg") }
        }
        guard Set(names).count == names.count else { throw ServiceError("backup", "The journal contains duplicate media identifiers.") }
        return names.sorted()
    }
    private static func stage(in parent: URL, prefix: String) throws -> URL {
        let url = parent.appendingPathComponent("." + prefix + "-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]); return url
    }
    private static func finalURL(in parent: URL, prefix: String) -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return parent.appendingPathComponent(prefix + " " + stamp + " " + String(UUID().uuidString.prefix(8)), isDirectory: true)
    }
    public static func create(store: JournalStore, vault: URL, destinationParent: URL) throws -> Result {
        let resolvedVault = vault.standardizedFileURL.resolvingSymlinksInPath().path
        let resolvedParent = destinationParent.standardizedFileURL.resolvingSymlinksInPath().path
        guard resolvedParent != resolvedVault && !resolvedParent.hasPrefix(resolvedVault + "/") else { throw ServiceError("backup", "Choose a backup location outside the journal folder.") }
        let staging = try stage(in: destinationParent, prefix: "memory-catcher-backup")
        defer { try? fm.removeItem(at: staging) }
        try store.snapshotDatabase(to: staging.appendingPathComponent("journal.sqlite"))
        try inspectDatabase(staging.appendingPathComponent("journal.sqlite"))
        let assets: [MediaAsset] = try { let snapshot = try JournalStore(directory: staging); return try snapshot.mediaAssets() }()
        let names = try mediaNames(assets)
        if !names.isEmpty {
            let sourceDirectory = vault.appendingPathComponent("media", isDirectory: true)
            let values = try sourceDirectory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { throw ServiceError("backup", "The journal media folder is invalid.") }
        }
        let directory = staging.appendingPathComponent("media", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        var files = [try record(staging.appendingPathComponent("journal.sqlite"), name: "journal.sqlite")]
        for name in names {
            let source = vault.appendingPathComponent("media", isDirectory: true).appendingPathComponent(name)
            try regular(source)
            let dest = directory.appendingPathComponent(name); try fm.copyItem(at: source, to: dest)
            let entry = try record(dest, name: "media/" + name)
            if name.hasSuffix(".bin"), let asset = assets.first(where: { $0.id + ".bin" == name }) {
                guard entry.bytes == asset.byteCount, asset.contentDigest == nil || asset.contentDigest == entry.sha256 else { throw ServiceError("backup", "An original attachment changed or failed verification. Retry the backup.") }
            }
            files.append(entry)
        }
        let manifest = Manifest(format: format, version: 1, createdAt: ISO8601DateFormatter().string(from: Date()), files: files)
        try JSONEncoder().encode(manifest).write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
        let destination = finalURL(in: destinationParent, prefix: "Memory Catcher Backup")
        try fm.moveItem(at: staging, to: destination)
        return Result(url: destination, mediaCount: assets.count)
    }
    public static func restore(backup: URL, destinationParent: URL) throws -> Result {
        let resolvedBackup = backup.standardizedFileURL.resolvingSymlinksInPath().path
        let resolvedParent = destinationParent.standardizedFileURL.resolvingSymlinksInPath().path
        guard resolvedParent != resolvedBackup && !resolvedParent.hasPrefix(resolvedBackup + "/") else { throw ServiceError("backup", "Choose a restore location outside the backup folder.") }
        let manifestURL = backup.appendingPathComponent("manifest.json"); try regular(manifestURL)
        let size = try manifestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 && size <= 5_000_000 else { throw ServiceError("backup", "The backup manifest is invalid or too large.") }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.format == format, manifest.version == 1, manifest.files.count <= 200_001,
              Set(manifest.files.map(\.name)).count == manifest.files.count,
              manifest.files.filter({ $0.name == "journal.sqlite" }).count == 1 else { throw ServiceError("backup", "This is not a supported backup or its manifest is invalid.") }
        let staging = try stage(in: destinationParent, prefix: "memory-catcher-restore")
        defer { try? fm.removeItem(at: staging) }
        let media = staging.appendingPathComponent("media", isDirectory: true)
        try fm.createDirectory(at: media, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        for file in manifest.files {
            let validMedia = file.name.range(of: #"^media/[0-9A-Fa-f-]{36}\.(bin|preview\.jpg)$"#, options: .regularExpression) != nil
            let sizeLimit = file.name.hasSuffix(".preview.jpg") ? MediaLibrary.maxPreviewBytes : (validMedia ? MediaLibrary.maxBytes : 2_000_000_000)
            guard file.name == "journal.sqlite" || validMedia, file.bytes >= 0, file.bytes <= sizeLimit, file.sha256.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil else { throw ServiceError("backup", "The backup contains an invalid filename or checksum.") }
            let source = backup.appendingPathComponent(file.name), dest = staging.appendingPathComponent(file.name)
            try regular(source)
            if validMedia {
                let parent = backup.appendingPathComponent("media", isDirectory: true)
                let values = try parent.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isDirectory == true, values.isSymbolicLink != true else { throw ServiceError("backup", "The backup media folder is invalid.") }
            }
            let before = try record(source, name: file.name)
            guard before.bytes == file.bytes, before.sha256 == file.sha256 else { throw ServiceError("backup", "A backup file failed its checksum. The restore was not applied.") }
            try fm.copyItem(at: source, to: dest)
            let after = try record(dest, name: file.name)
            guard after.bytes == file.bytes, after.sha256 == file.sha256 else { throw ServiceError("backup", "A restored file failed its checksum.") }
        }
        try inspectDatabase(staging.appendingPathComponent("journal.sqlite"))
        let assets: [MediaAsset] = try {
            let restored = try JournalStore(directory: staging)
            let assets = try restored.mediaAssets()
            try restored.setResourceEnabled("photos", enabled: false)
            try restored.setResourceEnabled("calendar", enabled: false)
            return assets
        }()
        let expectedNames = Set(try mediaNames(assets).map { "media/" + $0 })
        guard expectedNames == Set(manifest.files.map(\.name).filter { $0.hasPrefix("media/") }) else { throw ServiceError("backup", "The backup is missing media or contains unexpected media.") }
        for asset in assets {
            guard let file = manifest.files.first(where: { $0.name == "media/" + asset.id + ".bin" }), file.bytes == asset.byteCount,
                  asset.contentDigest == nil || file.sha256 == asset.contentDigest else { throw ServiceError("backup", "A restored attachment does not match its journal record.") }
        }
        try Data("memory-catcher-restored-v1".utf8).write(to: staging.appendingPathComponent("restore.receipt"), options: .atomic)
        let destination = finalURL(in: destinationParent, prefix: "Memory Catcher Restored Journal")
        try fm.moveItem(at: staging, to: destination)
        return Result(url: destination, mediaCount: assets.count)
    }
    public static func validateRestored(_ directory: URL) throws {
        let receipt = directory.appendingPathComponent("restore.receipt")
        try regular(receipt)
        guard (try receipt.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 128 else { throw ServiceError("backup", "Choose a restored Memory Catcher journal folder.") }
        guard (try? String(contentsOf: receipt, encoding: .utf8)) == "memory-catcher-restored-v1" else { throw ServiceError("backup", "Choose a restored Memory Catcher journal folder.") }
        try inspectDatabase(directory.appendingPathComponent("journal.sqlite"))
        let assets: [MediaAsset] = try { let store = try JournalStore(directory: directory); return try store.mediaAssets() }()
        let names = try mediaNames(assets)
        if !names.isEmpty {
            let mediaDirectory = directory.appendingPathComponent("media", isDirectory: true)
            let values = try mediaDirectory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { throw ServiceError("backup", "The restored media folder is invalid.") }
            for name in names { try regular(mediaDirectory.appendingPathComponent(name)) }
        }
    }

}
