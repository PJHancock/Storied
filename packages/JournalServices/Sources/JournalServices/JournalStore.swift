import Foundation
import CSQLite

public struct ServiceError: LocalizedError {
    public let code: String
    public let message: String
    public init(_ code: String, _ message: String) { self.code = code; self.message = message }
    public var errorDescription: String? { message }
}
public struct Entry: Codable, Equatable {
    public let id: String
    public let day: String
    public let body: String
    public let timezone: String
    public let allowsAI: Bool
    public let revision: Int
    public let createdAt: String
    public let updatedAt: String
}
public struct MediaAsset: Codable, Equatable {
    public let id: String
    public var day: String
    public let filename: String
    public let mimeType: String
    public let kind: String
    public let byteCount: Int
    public let hasPreview: Bool
    public var allowsAI: Bool? = nil
    public var transcript: String? = nil
    public var analysisText: String? = nil
    public var analysisRevision: Int? = nil
    public var contentDigest: String? = nil
    public let createdAt: String
}
public struct DaySummaryOverride: Codable, Equatable {
    public let day: String
    public let title: String
    public let detail: String
}
public struct WeeklySummaryOverride: Codable, Equatable {
    public let weekOf: String
    public let title: String
    public let detail: String
}
public struct DayWeatherLocation: Codable, Equatable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
}
public struct MonthlySynopsisBullet: Codable, Equatable {
    public let day: String
    public let text: String
}
public struct MonthlySynopsis: Codable, Equatable {
    public let month: String
    public let fingerprint: String
    public let bullets: [MonthlySynopsisBullet]
}
public struct JournalContextItem: Codable, Equatable {
    public let id: String
    public let kind: String
    public let title: String
    public let aliases: String
    public let details: String
    public let revision: Int
}
/// Serialized access is supplied by the host; no arbitrary paths or SQL cross the bridge.
public final class JournalStore {
    private var db: OpaquePointer?
    public init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard sqlite3_open(directory.appendingPathComponent("journal.sqlite").path, &db) == SQLITE_OK else { throw ServiceError("storage", "Could not open the journal.") }
        let schemaVersion = try rows("PRAGMA user_version").first.flatMap(Int.init) ?? 0
        guard schemaVersion <= 9 else {
            sqlite3_close(db); db = nil
            throw ServiceError("newerDatabase", "This journal was created by a newer app version. Open it with that version.")
        }
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA synchronous=FULL")
        try exec("CREATE TABLE IF NOT EXISTS entries(id TEXT PRIMARY KEY, day TEXT NOT NULL, payload TEXT NOT NULL)")
        try exec("CREATE INDEX IF NOT EXISTS entries_day ON entries(day)")
        try exec("CREATE TABLE IF NOT EXISTS drafts(day TEXT PRIMARY KEY, body TEXT NOT NULL)")
        if schemaVersion < 2 { try exec("CREATE TABLE IF NOT EXISTS media_assets(id TEXT PRIMARY KEY, day TEXT NOT NULL, payload TEXT NOT NULL)") }
        try exec("CREATE INDEX IF NOT EXISTS media_assets_day ON media_assets(day)")
        try exec("CREATE TABLE IF NOT EXISTS day_summary_overrides(day TEXT PRIMARY KEY, title TEXT NOT NULL, detail TEXT NOT NULL)")
        try exec("CREATE TABLE IF NOT EXISTS resource_settings(name TEXT PRIMARY KEY, enabled INTEGER NOT NULL CHECK(enabled IN (0,1)))")
        try exec("CREATE TABLE IF NOT EXISTS semantic_embeddings(source_id TEXT PRIMARY KEY, source_type TEXT NOT NULL, source_revision INTEGER NOT NULL, model TEXT NOT NULL, vector TEXT NOT NULL)")
        try exec("CREATE TABLE IF NOT EXISTS hidden_context_items(day TEXT NOT NULL, source TEXT NOT NULL, item_id TEXT NOT NULL, PRIMARY KEY(day,source,item_id))")
        try exec("CREATE TABLE IF NOT EXISTS generated_summary_cache(cache_key TEXT PRIMARY KEY, digest TEXT NOT NULL, payload TEXT NOT NULL)")
        try exec("CREATE TABLE IF NOT EXISTS connected_day_cache(day TEXT PRIMARY KEY, synced_at TEXT NOT NULL, payload TEXT NOT NULL)")
        if schemaVersion < 9 {
            try exec("CREATE TABLE IF NOT EXISTS journal_preferences(name TEXT PRIMARY KEY, value TEXT NOT NULL)")
            try exec("CREATE TABLE IF NOT EXISTS journal_context_items(id TEXT PRIMARY KEY, payload TEXT NOT NULL)")
            try exec("CREATE TABLE IF NOT EXISTS day_context_links(day TEXT NOT NULL, context_id TEXT NOT NULL, PRIMARY KEY(day,context_id))")
        }
        try exec("PRAGMA user_version=9")
    }
    deinit { sqlite3_close(db) }
    private func exec(_ sql: String, _ values: [String] = []) throws { _ = try rows(sql, values) }
    private func rows(_ sql: String, _ values: [String] = []) throws -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw ServiceError("storage", "Could not prepare journal operation.") }
        defer { sqlite3_finalize(stmt) }
        for (offset, value) in values.enumerated() {
            let result = value.withCString { sqlite3_bind_text(stmt, Int32(offset+1), $0, Int32(value.utf8.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            guard result == SQLITE_OK else { throw ServiceError("storage", "Could not bind journal operation.") }
        }
        var output: [String] = []
        while true {
            let status = sqlite3_step(stmt)
            if status == SQLITE_DONE { return output }
            guard status == SQLITE_ROW else { throw ServiceError("storage", "Could not complete journal operation.") }
            if let text = sqlite3_column_text(stmt, 0) { output.append(String(decoding: Data(bytes: text, count: Int(sqlite3_column_bytes(stmt, 0))), as: UTF8.self)) }
        }
    }
    private func transaction<T>(_ work: () throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE")
        do { let value = try work(); try exec("COMMIT"); return value }
        catch { try? exec("ROLLBACK"); throw error }
    }
    public func resourceEnabled(_ resource: String) throws -> Bool? {
        guard ["photos", "calendar"].contains(resource) else { throw ServiceError("invalid", "Unknown resource connection.") }
        guard let value = try rows("SELECT enabled FROM resource_settings WHERE name=?", [resource]).first else { return nil }
        return value == "1"
    }
    public func setResourceEnabled(_ resource: String, enabled: Bool) throws {
        guard ["photos", "calendar"].contains(resource) else { throw ServiceError("invalid", "Unknown resource connection.") }
        try exec("INSERT INTO resource_settings(name,enabled) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET enabled=excluded.enabled", [resource, enabled ? "1" : "0"])
    }
    public func connectedDayCache(day: String) throws -> (syncedAt: String, payload: String)? {
        try Self.validateDay(day)
        guard let payload = try rows("SELECT payload FROM connected_day_cache WHERE day=?", [day]).first,
              let syncedAt = try rows("SELECT synced_at FROM connected_day_cache WHERE day=?", [day]).first else { return nil }
        return (syncedAt, payload)
    }
    public func saveConnectedDayCache(day: String, syncedAt: String, payload: String) throws {
        try Self.validateDay(day)
        guard syncedAt.utf8.count <= 40, payload.utf8.count <= 4_000_000 else {
            throw ServiceError("invalid", "Connected day cache exceeded its storage limit.")
        }
        try exec("INSERT INTO connected_day_cache(day,synced_at,payload) VALUES(?,?,?) ON CONFLICT(day) DO UPDATE SET synced_at=excluded.synced_at,payload=excluded.payload", [day, syncedAt, payload])
    }
    public func contextItemHidden(day: String, source: String, itemID: String) throws -> Bool {
        try Self.validateDay(day)
        guard ["photo", "calendar", "weather"].contains(source), !itemID.isEmpty, itemID.utf8.count <= 500 else { throw ServiceError("invalid", "Invalid connected item.") }
        return try !rows("SELECT 1 FROM hidden_context_items WHERE day=? AND source=? AND item_id=?", [day, source, itemID]).isEmpty
    }
    public func setContextItemHidden(day: String, source: String, itemID: String, hidden: Bool) throws {
        try Self.validateDay(day)
        guard ["photo", "calendar", "weather"].contains(source), !itemID.isEmpty, itemID.utf8.count <= 500 else { throw ServiceError("invalid", "Invalid connected item.") }
        if hidden { try exec("INSERT OR IGNORE INTO hidden_context_items(day,source,item_id) VALUES(?,?,?)", [day, source, itemID]) }
        else { try exec("DELETE FROM hidden_context_items WHERE day=? AND source=? AND item_id=?", [day, source, itemID]) }
    }
    public struct PageText: Codable, Equatable, Sendable {
        public var revision: Int
        public var fields: [String: String]
    }
    public func pageText(weekOf: String) throws -> PageText {
        try Self.validateDay(weekOf)
        guard let payload = try rows("SELECT value FROM journal_preferences WHERE name=?", ["page_text:" + weekOf]).first else { return PageText(revision: 0, fields: [:]) }
        return try JSONDecoder().decode(PageText.self, from: Data(payload.utf8))
    }
    public func savePageText(weekOf: String, fields: [String: String], expectedRevision: Int) throws -> PageText {
        try Self.validateDay(weekOf)
        let allowed = Set(["week.title", "week.subtitle", "week.note", "week.eyebrow", "week.summaryLabel", "week.summaryTitle", "week.summaryDetail", "week.dayOrder", "label.originals", "label.photos", "label.calendar", "label.weather", "label.media"])
        guard expectedRevision >= 0, fields.count <= 100, fields.allSatisfy({ key, value in
            if key.range(of: #"^day\.\d{4}-\d{2}-\d{2}\.(photoPlacement|photoSize)$"#, options: .regularExpression) != nil {
                let date = String(key.dropFirst(4).prefix(10))
                let allowedValues = key.hasSuffix(".photoPlacement") ? Set(["above", "beside", "overlap"]) : Set(["small", "medium", "large"])
                return allowedValues.contains(value) && Self.weekContainsDay(date, weekOf: weekOf)
            }
            if key.range(of: #"^day\.\d{4}-\d{2}-\d{2}\.style$"#, options: .regularExpression) != nil {
                let date = String(key.dropFirst(4).prefix(10))
                let styles = Set(["note", "lined", "ticket", "tag", "postcard", "clipped", "index", "photo"])
                return styles.contains(value) && Self.weekContainsDay(date, weekOf: weekOf)
            }
            let allowedField = key == "week.dayOrder" ? Self.isValidWeekDayOrder(value, weekOf: weekOf) : (allowed.contains(key) || key.range(of: #"^day\.\d{4}-\d{2}-\d{2}\.(title|detail|date)$"#, options: .regularExpression) != nil)
            return allowedField && value.utf8.count <= 10000
        }) else { throw ServiceError("invalid", "Invalid page text or text too long.") }
        return try transaction {
            let previous = try pageText(weekOf: weekOf)
            guard previous.revision == expectedRevision else { throw ServiceError("conflict", "This page was edited in another window. Cancel and reopen the page editor to load the latest edits.") }
            let saved = PageText(revision: previous.revision + 1, fields: fields)
            let data = try JSONEncoder().encode(saved)
            guard data.count <= 80000 else { throw ServiceError("invalid", "Page text is too large.") }
            try exec("INSERT INTO journal_preferences(name,value) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET value=excluded.value", ["page_text:" + weekOf, String(decoding: data, as: UTF8.self)])
            return saved
        }
    }

    /// Uses SQLite's online backup API, so the snapshot includes committed WAL data.
    public func snapshotDatabase(to destination: URL) throws {
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw ServiceError("backup", "The backup database already exists.") }
        var output: OpaquePointer?
        guard sqlite3_open_v2(destination.path, &output, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK, let output else {
            if output != nil { sqlite3_close(output) }
            throw ServiceError("backup", "Could not create the database snapshot.")
        }
        defer { sqlite3_close(output) }
        guard let backup = sqlite3_backup_init(output, "main", db, "main") else { throw ServiceError("backup", "Could not start the database snapshot.") }
        let status = sqlite3_backup_step(backup, -1)
        let finished = sqlite3_backup_finish(backup)
        guard status == SQLITE_DONE && finished == SQLITE_OK else { throw ServiceError("backup", "Could not complete the database snapshot. Retry.") }
        // The backup copies the source database header, including WAL mode. A standalone
        // file without its -wal/-shm siblings cannot be opened read-only on some systems.
        // Normalize the snapshot to DELETE mode while the writable handle is still open.
        guard sqlite3_exec(output, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else {
            throw ServiceError("backup", "Could not finalize the database snapshot. Retry.")
        }
    }

    public func savedSummary(key: String) throws -> GroundedSummary? {
        guard let payload = try rows("SELECT payload FROM generated_summary_cache WHERE cache_key=?", [key]).first else { return nil }
        return try? JSONDecoder().decode(GroundedSummary.self, from: Data(payload.utf8))
    }
    public func weatherCache(key: String) throws -> String? {
        guard key.utf8.count <= 200 else { throw ServiceError("invalid", "Invalid weather key.") }
        return try rows("SELECT value FROM journal_preferences WHERE name=?", ["weather:" + key]).first
    }
    public func saveWeatherCache(key: String, payload: String) throws {
        guard key.utf8.count <= 200, payload.utf8.count <= 10000 else { throw ServiceError("invalid", "Invalid weather cache.") }
        try exec("INSERT INTO journal_preferences(name,value) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET value=excluded.value", ["weather:" + key, payload])
    }
    public func cachedSummary(key: String, digest: String) throws -> GroundedSummary? {
        guard !key.isEmpty, key.utf8.count <= 200, digest.utf8.count == 64 else { throw ServiceError("invalid", "Invalid summary cache key.") }
        guard let payload = try rows("SELECT payload FROM generated_summary_cache WHERE cache_key=? AND digest=?", [key, digest]).first,
              let value = try? JSONDecoder().decode(GroundedSummary.self, from: Data(payload.utf8)) else { return nil }
        return value
    }
    public func saveSummaryCache(_ entries: [(key: String, digest: String, summary: GroundedSummary)]) throws {
        try transaction {
            for entry in entries {
                guard !entry.key.isEmpty, entry.key.utf8.count <= 200, entry.digest.utf8.count == 64 else { throw ServiceError("invalid", "Invalid summary cache entry.") }
                let payload = String(decoding: try JSONEncoder().encode(entry.summary), as: UTF8.self)
                try exec("INSERT INTO generated_summary_cache(cache_key,digest,payload) VALUES(?,?,?) ON CONFLICT(cache_key) DO UPDATE SET digest=excluded.digest,payload=excluded.payload", [entry.key, entry.digest, payload])
            }
        }
    }
    public func entries(day: String? = nil) throws -> [Entry] {
        let result = try day.map { try rows("SELECT payload FROM entries WHERE day=? ORDER BY id", [$0]) }
            ?? rows("SELECT payload FROM entries ORDER BY day DESC, id")
        return try result.map { try JSONDecoder().decode(Entry.self, from: Data($0.utf8)) }
    }
    private func entry(_ id: String) throws -> Entry? {
        guard let data = try rows("SELECT payload FROM entries WHERE id=?", [id]).first else { return nil }
        return try JSONDecoder().decode(Entry.self, from: Data(data.utf8))
    }
    private func write(_ entry: Entry) throws {
        let json = String(decoding: try JSONEncoder().encode(entry), as: UTF8.self)
        try exec("INSERT INTO entries(id,day,payload) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET day=excluded.day,payload=excluded.payload", [entry.id, entry.day, json])
    }
    public func save(id: String, day: String, body: String, timezone: String, allowsAI: Bool, expectedRevision: Int?) throws -> Entry {
        try Self.validateDay(day)
        guard let uuid = UUID(uuidString: id), TimeZone(identifier: timezone) != nil,
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, body.utf8.count <= 100_000 else { throw ServiceError("invalid", "Supply a valid memory up to 100 KB and a valid timezone.") }
        return try transaction {
            let id = uuid.uuidString
            let old = try entry(id)
            if let revision = expectedRevision {
                guard old?.revision == revision else { throw ServiceError("staleRevision", "This memory changed. Reload before editing.") }
            } else if let old {
                guard old.revision == 1, old.day == day, old.body == body, old.timezone == timezone, old.allowsAI == allowsAI else { throw ServiceError("conflict", "This memory identifier is already in use.") }
                return old
            }
            let now = ISO8601DateFormatter().string(from: Date())
            let value = Entry(id: id, day: day, body: body, timezone: timezone, allowsAI: allowsAI,
                revision: (old?.revision ?? 0) + 1, createdAt: old?.createdAt ?? now, updatedAt: now)
            try exec("DELETE FROM semantic_embeddings WHERE source_id=?", [id])
            try write(value)
            try exec("DELETE FROM day_summary_overrides WHERE day=?", [day])
            if let old, old.day != day { try exec("DELETE FROM day_summary_overrides WHERE day=?", [old.day]) }
            if expectedRevision == nil { try exec("DELETE FROM drafts WHERE day=?", [day]) }
            return value
        }
    }
    public func delete(id: String, expectedRevision: Int) throws {
        try transaction {
            guard let uuid = UUID(uuidString: id), let old = try entry(uuid.uuidString), old.revision == expectedRevision else { throw ServiceError("staleRevision", "This memory changed or was removed. Reload before deleting.") }
            try exec("DELETE FROM entries WHERE id=?", [uuid.uuidString])
            try exec("DELETE FROM semantic_embeddings WHERE source_id=?", [uuid.uuidString])
            try exec("DELETE FROM day_summary_overrides WHERE day=?", [old.day])
        }
    }
    public func draft(day: String) throws -> String { try Self.validateDay(day); return try rows("SELECT body FROM drafts WHERE day=?", [day]).first ?? "" }
    public func saveDraft(day: String, body: String) throws {
        try Self.validateDay(day)
        guard body.utf8.count <= 100_000 else { throw ServiceError("invalid", "Draft exceeds 100 KB.") }
        try exec("INSERT INTO drafts(day,body) VALUES(?,?) ON CONFLICT(day) DO UPDATE SET body=excluded.body", [day, body])
    }
    public func daySummaryOverride(day: String) throws -> DaySummaryOverride? {
        try Self.validateDay(day)
        guard let title = try rows("SELECT title FROM day_summary_overrides WHERE day=?", [day]).first,
              let detail = try rows("SELECT detail FROM day_summary_overrides WHERE day=?", [day]).first else { return nil }
        return DaySummaryOverride(day: day, title: title, detail: detail)
    }
    public func saveDaySummaryOverride(day: String, title: String, detail: String) throws -> DaySummaryOverride {
        try Self.validateDay(day)
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 80, detail.count <= 1_000 else {
            throw ServiceError("invalid", "Add a heading up to 80 characters and explanation up to 1,000 characters.")
        }
        try exec("INSERT INTO day_summary_overrides(day,title,detail) VALUES(?,?,?) ON CONFLICT(day) DO UPDATE SET title=excluded.title,detail=excluded.detail", [day, title, detail])
        return DaySummaryOverride(day: day, title: title, detail: detail)
    }
    public func summaryGuidance() throws -> String {
        try rows("SELECT value FROM journal_preferences WHERE name='summary_guidance'").first ?? ""
    }
    public func saveSummaryGuidance(_ text: String) throws -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count <= 2_500 else { throw ServiceError("invalid", "Summary guidance must be at most 2.5 KB.") }
        if try summaryGuidance() != value {
            try exec("INSERT INTO journal_preferences(name,value) VALUES('summary_guidance',?) ON CONFLICT(name) DO UPDATE SET value=excluded.value", [value])
        }
        return value
    }
    public func weeklySummaryOverride(weekOf: String) throws -> WeeklySummaryOverride? {
        try Self.validateDay(weekOf)
        guard let value = try rows("SELECT value FROM journal_preferences WHERE name=?", ["weekly_summary_override:" + weekOf]).first else { return nil }
        return try JSONDecoder().decode(WeeklySummaryOverride.self, from: Data(value.utf8))
    }
    public func saveWeeklySummaryOverride(weekOf: String, title: String, detail: String) throws -> WeeklySummaryOverride {
        try Self.validateDay(weekOf)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, cleanTitle.count <= 80, cleanDetail.count <= 1_000 else {
            throw ServiceError("invalid", "Add a heading up to 80 characters and explanation up to 1,000 characters.")
        }
        let value = WeeklySummaryOverride(weekOf: weekOf, title: cleanTitle, detail: cleanDetail)
        let payload = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        try exec("INSERT INTO journal_preferences(name,value) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET value=excluded.value", ["weekly_summary_override:" + weekOf, payload])
        return value
    }
    public func clearWeeklySummaryOverride(weekOf: String) throws {
        try Self.validateDay(weekOf)
        try exec("DELETE FROM journal_preferences WHERE name=?", ["weekly_summary_override:" + weekOf])
    }
    public func dayWeatherLocation(day: String) throws -> DayWeatherLocation? {
        try Self.validateDay(day)
        guard let payload = try rows("SELECT value FROM journal_preferences WHERE name=?", ["weather_location:" + day]).first else { return nil }
        return try JSONDecoder().decode(DayWeatherLocation.self, from: Data(payload.utf8))
    }
    public func saveDayWeatherLocation(day: String, name: String, latitude: Double, longitude: Double) throws -> DayWeatherLocation {
        try Self.validateDay(day)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName.count <= 160, cleanName.utf8.count <= 400,
              latitude.isFinite, (-90...90).contains(latitude), longitude.isFinite, (-180...180).contains(longitude) else {
            throw ServiceError("invalid", "Choose a valid city for this day.")
        }
        let location = DayWeatherLocation(name: cleanName, latitude: latitude, longitude: longitude)
        let payload = String(decoding: try JSONEncoder().encode(location), as: UTF8.self)
        try exec("INSERT INTO journal_preferences(name,value) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET value=excluded.value", ["weather_location:" + day, payload])
        return location
    }
    public func clearDayWeatherLocation(day: String) throws {
        try Self.validateDay(day)
        try exec("DELETE FROM journal_preferences WHERE name=?", ["weather_location:" + day])
    }
    public func hiddenAnniversaryDays() throws -> [String] {
        guard let payload = try rows("SELECT value FROM journal_preferences WHERE name='hidden_anniversary_days'").first else { return [] }
        let days = try JSONDecoder().decode([String].self, from: Data(payload.utf8))
        for day in days { try Self.validateDay(day) }
        return Array(Set(days)).sorted(by: >)
    }
    public func setAnniversaryHidden(day: String, hidden: Bool) throws -> [String] {
        try Self.validateDay(day)
        var days = Set(try hiddenAnniversaryDays())
        if hidden { days.insert(day) } else { days.remove(day) }
        guard days.count <= 500 else { throw ServiceError("invalid", "You can hide up to 500 On this day entries.") }
        let sorted = days.sorted(by: >)
        let payload = String(decoding: try JSONEncoder().encode(sorted), as: UTF8.self)
        try exec("INSERT INTO journal_preferences(name,value) VALUES('hidden_anniversary_days',?) ON CONFLICT(name) DO UPDATE SET value=excluded.value", [payload])
        return sorted
    }
    public func monthlySynopsis(month: String, fingerprint: String) throws -> MonthlySynopsis? {
        try Self.validateMonth(month)
        try Self.validateFingerprint(fingerprint)
        guard let payload = try rows("SELECT value FROM journal_preferences WHERE name=?", ["monthly_synopsis:" + month]).first else { return nil }
        let value = try JSONDecoder().decode(MonthlySynopsis.self, from: Data(payload.utf8))
        return value.fingerprint == fingerprint ? value : nil
    }
    public func saveMonthlySynopsis(month: String, fingerprint: String, bullets: [MonthlySynopsisBullet]) throws -> MonthlySynopsis {
        try Self.validateMonth(month)
        try Self.validateFingerprint(fingerprint)
        guard !bullets.isEmpty, bullets.count <= 31, bullets.allSatisfy({ $0.day.hasPrefix(month + "-") && $0.text == $0.text.trimmingCharacters(in: .whitespacesAndNewlines) && !$0.text.isEmpty && $0.text.count <= 450 }) else {
            throw ServiceError("invalid", "Monthly synopsis bullets are invalid.")
        }
        for bullet in bullets { try Self.validateDay(bullet.day) }
        let value = MonthlySynopsis(month: month, fingerprint: fingerprint, bullets: bullets)
        let payload = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        guard payload.utf8.count <= 60_000 else { throw ServiceError("invalid", "Monthly synopsis is too large.") }
        try exec("INSERT INTO journal_preferences(name,value) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET value=excluded.value", ["monthly_synopsis:" + month, payload])
        return value
    }
    private static func validateMonth(_ month: String) throws {
        guard month.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil else { throw ServiceError("invalid", "Use a valid month.") }
        try validateDay(month + "-01")
    }
    private static func validateFingerprint(_ fingerprint: String) throws {
        guard fingerprint.utf8.count == 64, fingerprint.allSatisfy({ $0.isHexDigit }) else { throw ServiceError("invalid", "Invalid monthly synopsis fingerprint.") }
    }
    public func headlinePhotoID(day: String) throws -> String? {
        try Self.validateDay(day)
        return try rows("SELECT value FROM journal_preferences WHERE name=?", ["headline_photo:" + day]).first
    }
    public func saveHeadlinePhotoID(day: String, photoID: String?) throws {
        try Self.validateDay(day)
        let name = "headline_photo:" + day
        if let photoID {
            guard !photoID.isEmpty, photoID.utf8.count <= 500 else { throw ServiceError("invalid", "Choose a valid photo for this day.") }
            try exec("INSERT INTO journal_preferences(name,value) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET value=excluded.value", [name, photoID])
        } else {
            try exec("DELETE FROM journal_preferences WHERE name=?", [name])
        }
    }
    public func journalContextItems() throws -> [JournalContextItem] {
        try rows("SELECT payload FROM journal_context_items ORDER BY id").map { try JSONDecoder().decode(JournalContextItem.self, from: Data($0.utf8)) }
    }
    public func journalContextItem(id: String) throws -> JournalContextItem? {
        guard let payload = try rows("SELECT payload FROM journal_context_items WHERE id=?", [id]).first else { return nil }
        return try JSONDecoder().decode(JournalContextItem.self, from: Data(payload.utf8))
    }
    public func dayJournalContextItems(day: String) throws -> [JournalContextItem] {
        try Self.validateDay(day)
        return try rows("SELECT item.payload FROM journal_context_items item JOIN day_context_links link ON link.context_id=item.id WHERE link.day=? ORDER BY item.id", [day])
            .map { try JSONDecoder().decode(JournalContextItem.self, from: Data($0.utf8)) }
    }
    public func saveJournalContextItem(id: String, kind: String, title: String, aliases: String, details: String, expectedRevision: Int?) throws -> JournalContextItem {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAliases = aliases.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uuid = UUID(uuidString: id), ["person", "event"].contains(kind), !cleanTitle.isEmpty,
              cleanTitle.utf8.count <= 160, cleanAliases.utf8.count <= 400, cleanDetails.utf8.count <= 1_500 else {
            throw ServiceError("invalid", "Use a person or event with a title up to 160 bytes, aliases up to 400 bytes, and notes up to 1.5 KB.")
        }
        return try transaction {
            let id = uuid.uuidString
            let old = try journalContextItem(id: id)
            if let expectedRevision {
                guard old?.revision == expectedRevision else { throw ServiceError("staleRevision", "This context changed. Reload before saving.") }
            } else if old != nil { throw ServiceError("conflict", "This context identifier is already in use.") }
            if old == nil, try rows("SELECT id FROM journal_context_items").count >= 250 {
                throw ServiceError("limit", "The journal context library is full. Remove an unused item before adding another.")
            }
            let item = JournalContextItem(id: id, kind: kind, title: cleanTitle, aliases: cleanAliases,
                                          details: cleanDetails, revision: (old?.revision ?? 0) + 1)
            let payload = String(decoding: try JSONEncoder().encode(item), as: UTF8.self)
            try exec("INSERT INTO journal_context_items(id,payload) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload", [id, payload])
            return item
        }
    }
    public func deleteJournalContextItem(id: String, expectedRevision: Int) throws {
        try transaction {
            guard let item = try journalContextItem(id: id), item.revision == expectedRevision else {
                throw ServiceError("staleRevision", "This context changed. Reload before deleting.")
            }
            try exec("DELETE FROM day_context_links WHERE context_id=?", [id])
            try exec("DELETE FROM journal_context_items WHERE id=?", [id])
        }
    }
    public func setDayJournalContext(day: String, contextID: String, linked: Bool) throws {
        try Self.validateDay(day)
        guard UUID(uuidString: contextID) != nil else { throw ServiceError("invalid", "Choose a saved context item.") }
        try transaction {
            if linked {
                guard try journalContextItem(id: contextID) != nil else { throw ServiceError("notFound", "That people/event context no longer exists.") }
                if try rows("SELECT context_id FROM day_context_links WHERE day=?", [day]).count >= 12,
                   try rows("SELECT context_id FROM day_context_links WHERE day=? AND context_id=?", [day, contextID]).isEmpty {
                    throw ServiceError("limit", "A day can have at most 12 linked context items.")
                }
                try exec("INSERT OR IGNORE INTO day_context_links(day,context_id) VALUES(?,?)", [day, contextID])
            } else {
                try exec("DELETE FROM day_context_links WHERE day=? AND context_id=?", [day, contextID])
            }
        }
    }
    public func clearDaySummaryOverride(day: String) throws {
        try Self.validateDay(day)
        try exec("DELETE FROM day_summary_overrides WHERE day=?", [day])
    }
    public func registerMedia(id: String, day: String, filename: String, mimeType: String, byteCount: Int, hasPreview: Bool, contentDigest: String? = nil) throws -> MediaAsset {
        try Self.validateDay(day)
        guard let uuid = UUID(uuidString: id), byteCount > 0, byteCount <= 80 * 1024 * 1024,
              let kind = Self.mediaKind(mimeType), !filename.isEmpty, filename.utf8.count <= 240,
              !filename.contains("/") && !filename.contains("\\") else { throw ServiceError("invalid", "Unsupported media type or invalid attachment details.") }
        var value = MediaAsset(id: uuid.uuidString, day: day, filename: filename, mimeType: mimeType,
                               kind: kind, byteCount: byteCount, hasPreview: hasPreview,
                               createdAt: ISO8601DateFormatter().string(from: Date()))
        value.contentDigest = contentDigest
        // Newly added memories follow the user's automatic local-indexing preference.
        value.allowsAI = true
        let payload = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        try exec("INSERT INTO media_assets(id,day,payload) VALUES(?,?,?)", [value.id, day, payload])
        try exec("DELETE FROM day_summary_overrides WHERE day=?", [day])
        return value
    }
    private func updateMedia(_ asset: MediaAsset) throws {
        let payload = String(decoding: try JSONEncoder().encode(asset), as: UTF8.self)
        try exec("UPDATE media_assets SET day=?,payload=? WHERE id=?", [asset.day, payload, asset.id])
        try exec("DELETE FROM day_summary_overrides WHERE day=?", [asset.day])
    }
    public func moveMedia(id: String, toDay: String) throws -> MediaAsset {
        try Self.validateDay(toDay)
        return try transaction {
            guard var asset = try mediaAsset(id: id) else { throw ServiceError("notFound", "This attachment is no longer available.") }
            let previousDay = asset.day
            guard previousDay != toDay else { return asset }
            asset.day = toDay
            try updateMedia(asset)
            try exec("DELETE FROM day_summary_overrides WHERE day=?", [previousDay])
            if asset.kind == "photo", try headlinePhotoID(day: previousDay) == asset.id {
                try saveHeadlinePhotoID(day: previousDay, photoID: nil)
                if try headlinePhotoID(day: toDay) == nil { try saveHeadlinePhotoID(day: toDay, photoID: asset.id) }
            }
            return asset
        }
    }
    public func setMediaAI(id: String, enabled: Bool) throws -> MediaAsset {
        try transaction {
            guard var asset = try mediaAsset(id: id) else { throw ServiceError("notFound", "Memory not found.") }
            asset.allowsAI = enabled; asset.analysisRevision = (asset.analysisRevision ?? 0) + 1
            if !enabled { asset.transcript = nil; asset.analysisText = nil; try exec("DELETE FROM semantic_embeddings WHERE source_id=?", [asset.id]) }
            try updateMedia(asset); return asset
        }
    }
    public func saveMediaTranscript(source: MediaAsset, transcript: String) throws -> MediaAsset {
        try transaction {
            guard let current = try mediaAsset(id: source.id), current == source, current.allowsAI == true,
                  current.kind != "photo" else { throw ServiceError("staleRevision", "Recording changed or was excluded. Retry processing.") }
            guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, transcript.utf8.count <= 100_000 else { throw ServiceError("invalid", "No speech was recognized, or the transcript exceeds 100 KB.") }
            var asset = current; asset.transcript = transcript; asset.analysisRevision = (asset.analysisRevision ?? 0) + 1
            try updateMedia(asset); return asset
        }
    }
    public func updateMediaTranscript(id: String, transcript: String, expectedRevision: Int) throws -> MediaAsset {
        try transaction {
            guard var asset = try mediaAsset(id: id) else { throw ServiceError("notFound", "Memory not found.") }
            guard asset.allowsAI == true, asset.kind != "photo",
                  (asset.analysisRevision ?? 0) == expectedRevision else {
                throw ServiceError("staleRevision", "This recording changed or is no longer included. Reload before editing its transcript.")
            }
            guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, transcript.utf8.count <= 100_000 else {
                throw ServiceError("invalid", "Keep the transcript between 1 byte and 100 KB.")
            }
            asset.transcript = transcript
            asset.analysisRevision = expectedRevision + 1
            try exec("DELETE FROM semantic_embeddings WHERE source_id=?", [asset.id])
            try updateMedia(asset)
            return asset
        }
    }
    public func saveMediaAnalysis(source: MediaAsset, text: String) throws -> MediaAsset {
        try transaction {
            guard let current = try mediaAsset(id: source.id), current == source, current.allowsAI == true else { throw ServiceError("staleRevision", "Memory changed or was excluded. Retry analysis.") }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 20_000 else { throw ServiceError("invalid", "Local media analysis is empty or too large.") }
            var asset = current; asset.analysisText = text; asset.analysisRevision = (asset.analysisRevision ?? 0) + 1
            try updateMedia(asset); return asset
        }
    }
    public func mediaAssets(day: String? = nil) throws -> [MediaAsset] {
        if let day { try Self.validateDay(day) }
        let values = try day.map { try rows("SELECT payload FROM media_assets WHERE day=? ORDER BY rowid", [$0]) }
            ?? rows("SELECT payload FROM media_assets ORDER BY day DESC, rowid")
        return try values.map { try JSONDecoder().decode(MediaAsset.self, from: Data($0.utf8)) }
    }
    public func saveSemanticEmbedding(id: String, type: String, revision: Int, model: String, vector: [Double]) throws {
        guard vector.count <= 4096, vector.allSatisfy(\.isFinite), model.utf8.count <= 120 else { throw ServiceError("invalid", "Invalid local embedding.") }
        let encoded = String(decoding: try JSONEncoder().encode(vector), as: UTF8.self)
        try exec("INSERT INTO semantic_embeddings(source_id,source_type,source_revision,model,vector) VALUES(?,?,?,?,?) ON CONFLICT(source_id) DO UPDATE SET source_type=excluded.source_type,source_revision=excluded.source_revision,model=excluded.model,vector=excluded.vector", [id, type, String(revision), model, encoded])
    }
    public func semanticEmbeddings() throws -> [(id: String, type: String, revision: Int, model: String, vector: [Double])] {
        var stmt: OpaquePointer?
        let sql = "SELECT source_id,source_type,source_revision,model,vector FROM semantic_embeddings ORDER BY source_id"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw ServiceError("storage", "Could not read the local search index.") }
        defer { sqlite3_finalize(stmt) }
        var output: [(String,String,Int,String,[Double])] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func col(_ index: Int32) -> String { guard let pointer = sqlite3_column_text(stmt, index) else { return "" }; return String(cString: pointer) }
            guard let vector = try? JSONDecoder().decode([Double].self, from: Data(col(4).utf8)), let revision = Int(col(2)) else { continue }
            output.append((col(0), col(1), revision, col(3), vector))
        }
        return output
    }
    public func mediaAsset(id: String) throws -> MediaAsset? {
        guard let uuid = UUID(uuidString: id), let payload = try rows("SELECT payload FROM media_assets WHERE id=?", [uuid.uuidString]).first else { return nil }
        return try JSONDecoder().decode(MediaAsset.self, from: Data(payload.utf8))
    }
    @discardableResult public func deleteMedia(id: String) throws -> MediaAsset {
        try transaction {
            guard let asset = try mediaAsset(id: id) else { throw ServiceError("notFound", "This attachment is no longer available.") }
            try exec("DELETE FROM media_assets WHERE id=?", [asset.id])
            try exec("DELETE FROM semantic_embeddings WHERE source_id=?", [asset.id])
            try exec("DELETE FROM day_summary_overrides WHERE day=?", [asset.day])
            if try headlinePhotoID(day: asset.day) == asset.id { try saveHeadlinePhotoID(day: asset.day, photoID: nil) }
            return asset
        }
    }
    public static func mediaKind(_ mimeType: String) -> String? {
        let mime = mimeType.lowercased().split(separator: ";", maxSplits: 1).first.map(String.init) ?? ""
        if ["image/jpeg", "image/png", "image/heic", "image/heif", "image/gif", "image/webp"].contains(mime) { return "photo" }
        if ["audio/mp4", "audio/x-m4a", "audio/mpeg", "audio/wav", "audio/x-wav", "audio/aac", "audio/webm", "audio/ogg", "audio/3gpp", "audio/x-caf", "audio/caf"].contains(mime) { return "audio" }
        if ["video/mp4", "video/quicktime", "video/webm", "video/x-m4v", "video/3gpp"].contains(mime) { return "video" }
        return nil
    }
    public static func validateDay(_ day: String) throws {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard day.utf8.count == 10, let date = formatter.date(from: day), formatter.string(from: date) == day else { throw ServiceError("invalid", "Use a valid calendar date.") }
    }
    private static func weekContainsDay(_ day: String, weekOf: String) -> Bool {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard let start = formatter.date(from: weekOf), formatter.string(from: start) == weekOf,
              let target = formatter.date(from: day), formatter.string(from: target) == day else { return false }
        let difference = Int(target.timeIntervalSince(start) / 86400)
        return (0..<7).contains(difference)
    }
    private static func isValidWeekDayOrder(_ value: String, weekOf: String) -> Bool {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard let start = formatter.date(from: weekOf), formatter.string(from: start) == weekOf else { return false }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let expected = (0..<7).compactMap { offset in calendar.date(byAdding: .day, value: offset, to: start).map { formatter.string(from: $0) } }
        let supplied = value.split(separator: ",").map(String.init)
        return supplied.count == 7 && Set(supplied) == Set(expected)
    }
}
