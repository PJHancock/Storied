import Foundation
import Testing
import CSQLite
@testable import JournalServices
@Suite struct BridgeTests {
    func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    @Test func memoriesAndDraftsSurviveNewStoreAndSaveConsumesDraft() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID().uuidString
        do {
            let store = try JournalStore(directory: root)
            try store.saveDraft(day: "2026-11-12", body: "Unfinished paragraph")
            #expect(try store.draft(day: "2026-11-12") == "Unfinished paragraph")
        }
        do {
            let store = try JournalStore(directory: root)
            #expect(try store.draft(day: "2026-11-12") == "Unfinished paragraph")
            _ = try store.save(id: id, day: "2026-11-12", body: "Original\n\nSecond paragraph <script>untrusted</script>", timezone: "America/Denver", allowsAI: false, expectedRevision: nil)
            #expect(try store.draft(day: "2026-11-12") == "")
        }
        let store = try JournalStore(directory: root)
        let original = try #require(store.entries().first)
        #expect(original.body == "Original\n\nSecond paragraph <script>untrusted</script>")
        #expect(original.timezone == "America/Denver" && !original.allowsAI && original.revision == 1)
    }
    @Test func retriesDoNotDuplicateAndStaleWritesCannotOverwrite() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(directory: root), id = UUID().uuidString
        let a = try store.save(id: id, day: "2026-11-12", body: "Original", timezone: "UTC", allowsAI: false, expectedRevision: nil)
        let b = try store.save(id: id, day: a.day, body: a.body, timezone: a.timezone, allowsAI: a.allowsAI, expectedRevision: nil)
        let savedEntries = try store.entries()
        #expect(a == b && savedEntries.count == 1)
        let edit = try store.save(id: id, day: a.day, body: "Corrected", timezone: a.timezone, allowsAI: false, expectedRevision: 1)
        #expect(edit.revision == 2)
        #expect(throws: ServiceError.self) { try store.save(id: id, day: a.day, body: "Stale", timezone: a.timezone, allowsAI: false, expectedRevision: 1) }
        #expect(throws: ServiceError.self) { try store.delete(id: id, expectedRevision: 1) }
        #expect(try store.entries().first?.body == "Corrected")
        try store.delete(id: id, expectedRevision: 2)
        #expect(try store.entries().isEmpty)
    }
    @Test func invalidDatesAndOversizedTextAreRejected() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(directory: root)
        for day in ["2026-02-30", "bad", "2026-13-01"] { #expect(throws: ServiceError.self) { try store.saveDraft(day: day, body: "Note") } }
        #expect(throws: ServiceError.self) { try store.saveDraft(day: "2026-11-12", body: String(repeating: "a", count: 100_001)) }
        #expect(throws: ServiceError.self) { try store.save(id: UUID().uuidString, day: "2026-11-12", body: " ", timezone: "UTC", allowsAI: false, expectedRevision: nil) }
    }
    @Test func daySummaryEditsPersistAndCanBeRegenerated() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        do {
            let store = try JournalStore(directory: root)
            let saved = try store.saveDaySummaryOverride(day: "2026-11-12", title: "Hungarian Costume Fitting", detail: "We tried on costumes together.")
            #expect(saved.title == "Hungarian Costume Fitting")
            #expect(try store.daySummaryOverride(day: saved.day) == saved)
            #expect(throws: ServiceError.self) { try store.saveDaySummaryOverride(day: saved.day, title: " ", detail: "") }
        }
        let reopened = try JournalStore(directory: root)
        #expect(try reopened.daySummaryOverride(day: "2026-11-12")?.detail == "We tried on costumes together.")
        try reopened.clearDaySummaryOverride(day: "2026-11-12")
        #expect(try reopened.daySummaryOverride(day: "2026-11-12") == nil)
        _ = try reopened.save(id: UUID().uuidString, day: "2026-11-12", body: "A new memory", timezone: "UTC", allowsAI: false, expectedRevision: nil)
        _ = try reopened.saveDaySummaryOverride(day: "2026-11-12", title: "Custom title", detail: "Custom explanation")
        try reopened.delete(id: try #require(reopened.entries(day: "2026-11-12").first?.id), expectedRevision: 1)
        #expect(try reopened.daySummaryOverride(day: "2026-11-12") == nil)
    }
    @Test func photoAndCalendarChoicesPersistAcrossStoreReopen() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        do {
            let store = try JournalStore(directory: root)
            #expect(try store.resourceEnabled("photos") == nil)
            #expect(try store.resourceEnabled("calendar") == nil)
            try store.setResourceEnabled("photos", enabled: true)
            try store.setResourceEnabled("calendar", enabled: true)
        }
        let reopened = try JournalStore(directory: root)
        #expect(try reopened.resourceEnabled("photos") == true)
        #expect(try reopened.resourceEnabled("calendar") == true)
        try reopened.setResourceEnabled("photos", enabled: false)
        #expect(try JournalStore(directory: root).resourceEnabled("photos") == false)
        #expect(throws: ServiceError.self) { try reopened.setResourceEnabled("location", enabled: true) }
    }
    @Test func connectedItemsCanBeHiddenIndividuallyAndPersistByDayAndSource() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        do {
            let store = try JournalStore(directory: root)
            #expect(try !store.contextItemHidden(day: "2026-11-12", source: "photo", itemID: "synthetic-photo-1"))
            try store.setContextItemHidden(day: "2026-11-12", source: "photo", itemID: "synthetic-photo-1", hidden: true)
            try store.setContextItemHidden(day: "2026-11-12", source: "calendar", itemID: "synthetic-event-1", hidden: true)
            try store.setContextItemHidden(day: "2026-11-12", source: "weather", itemID: "2026-11-12", hidden: true)
        }
        let reopened = try JournalStore(directory: root)
        #expect(try reopened.contextItemHidden(day: "2026-11-12", source: "photo", itemID: "synthetic-photo-1"))
        #expect(try !reopened.contextItemHidden(day: "2026-11-13", source: "photo", itemID: "synthetic-photo-1"))
        #expect(try !reopened.contextItemHidden(day: "2026-11-12", source: "photo", itemID: "synthetic-event-1"))
        #expect(try reopened.contextItemHidden(day: "2026-11-12", source: "calendar", itemID: "synthetic-event-1"))
        try reopened.setContextItemHidden(day: "2026-11-12", source: "photo", itemID: "synthetic-photo-1", hidden: false)
        #expect(try !JournalStore(directory: root).contextItemHidden(day: "2026-11-12", source: "photo", itemID: "synthetic-photo-1"))
        #expect(throws: ServiceError.self) { try reopened.contextItemHidden(day: "2026-11-12", source: "location", itemID: "x") }
    }
    @Test func bridgeValidatesEnvelopeParametersAndConsent() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let service = Dispatcher(store: try JournalStore(directory: root))
        let rid = UUID().uuidString
        func invoke(_ method: String, _ params: [String: Any]) -> [String: Any] { service.handle(["version":1,"requestId":rid,"method":method,"params":params]) }
        let caps = try #require(invoke("system.capabilities", [:])["result"] as? [String: Any])
        #expect(caps["storage"] as? String == "native-sqlite")
        #expect(caps["ai"] is Bool)
        #expect(caps["photos"] as? Bool == true && caps["calendar"] as? Bool == true && caps["media"] as? Bool == true)
        #expect(service.handle(["version":2,"requestId":rid,"method":"system.capabilities","params":[:]])["error"] != nil)
        #expect(invoke("journal.getDay", ["day":"2026-11-12","path":"/etc/passwd"])["error"] != nil)
        #expect(invoke("arbitrary.exec", [:])["error"] != nil)
        let params: [String: Any] = ["id":UUID().uuidString,"day":"2026-11-12","body":"Native bridge note","timezone":"UTC","allowsAI":false]
        #expect(invoke("journal.createEntry",params)["error"] == nil)
        #expect((invoke("journal.getDay", ["day":"2026-11-12"])["result"] as? [[String:Any]])?.count == 1)
        #expect(invoke("journal.getSummaryOverride", ["day":"2026-11-12"])["result"] is NSNull)
        let summary = invoke("journal.saveSummaryOverride", ["day":"2026-11-12","title":"Hungarian Costume Fitting","detail":"We tried on costumes together."])["result"] as? [String:Any]
        #expect(summary?["title"] as? String == "Hungarian Costume Fitting")
        #expect((invoke("journal.getSummaryOverride", ["day":"2026-11-12"])["result"] as? [String:Any])?["detail"] as? String == "We tried on costumes together.")
        #expect(invoke("journal.clearSummaryOverride", ["day":"2026-11-12"])["error"] == nil)
        #expect(invoke("journal.getSummaryOverride", ["day":"2026-11-12"])["result"] is NSNull)
        var invalid = params; invalid["allowsAI"] = 1
        #expect(invoke("journal.createEntry",invalid)["error"] != nil)
    }
    @Test func localDocumentPolicyRejectsExternalFramesTraversalAndSymlinks() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appendingPathComponent("WebAssets")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let page = bundle.appendingPathComponent("index.html")
        try Data("fixture".utf8).write(to: page)
        let outside = root.appendingPathComponent("outside.html")
        try Data("fixture".utf8).write(to: outside)
        let link = bundle.appendingPathComponent("escape.html")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let policy = LocalDocumentPolicy(root: bundle)
        #expect(policy.permits(frame: page, document: page, isMainFrame: true))
        #expect(!policy.permits(frame: page, document: page, isMainFrame: false))
        #expect(!policy.contains(URL(string: "https://example.com/index.html")))
        #expect(!policy.contains(bundle.appendingPathComponent("../outside.html")))
        #expect(!policy.contains(link))
        #expect(!policy.permits(frame: page, document: outside, isMainFrame: true))
    }
    @Test func draftRetainsNullAndNewerDatabaseIsNotDowngraded() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        do {
            let store = try JournalStore(directory: root)
            try store.saveDraft(day: "2026-11-12", body: "Before\0after")
            #expect(try store.draft(day: "2026-11-12") == "Before\0after")
        }
        var db: OpaquePointer?
        #expect(sqlite3_open(root.appendingPathComponent("journal.sqlite").path, &db) == SQLITE_OK)
        #expect(sqlite3_exec(db, "PRAGMA user_version=99", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)
        #expect(throws: ServiceError.self) { try JournalStore(directory: root) }
        #expect(sqlite3_open(root.appendingPathComponent("journal.sqlite").path, &db) == SQLITE_OK)
        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK)
        #expect(sqlite3_step(statement) == SQLITE_ROW)
        #expect(sqlite3_column_int(statement, 0) == 99)
        sqlite3_finalize(statement); sqlite3_close(db)
    }

    @Test func versionOneDatabaseMigratesAndMediaPersistsInChunks() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var db: OpaquePointer?
        #expect(sqlite3_open(root.appendingPathComponent("journal.sqlite").path, &db) == SQLITE_OK)
        let fixture = "CREATE TABLE entries(id TEXT PRIMARY KEY, day TEXT NOT NULL, payload TEXT NOT NULL); CREATE TABLE drafts(day TEXT PRIMARY KEY, body TEXT NOT NULL); PRAGMA user_version=1;"
        #expect(sqlite3_exec(db, fixture, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let store = try JournalStore(directory: root)
        let library = try MediaLibrary(vault: root, store: store)
        let id = UUID().uuidString
        let bytes = Data(repeating: 0x41, count: MediaLibrary.chunkSize + 3)
        let preview = Data([0xff, 0xd8, 0xff, 0xd9]).base64EncodedString()
        let upload = try library.begin(id: id, day: "2026-11-12", filename: "chosen.png", mimeType: "image/png", byteCount: bytes.count, previewBase64: preview)
        #expect(throws: ServiceError.self) { try library.append(uploadID: upload, chunkIndex: 1, base64: Data([0x41]).base64EncodedString()) }
        _ = try library.append(uploadID: upload, chunkIndex: 0, base64: bytes.prefix(MediaLibrary.chunkSize).base64EncodedString())
        #expect(throws: ServiceError.self) { try library.finish(uploadID: upload) }
        _ = try library.append(uploadID: upload, chunkIndex: 1, base64: bytes.suffix(3).base64EncodedString())
        let asset = try library.finish(uploadID: upload)
        #expect(asset.kind == "photo" && asset.hasPreview && asset.byteCount == bytes.count)
        #expect(try store.mediaAssets(day: "2026-11-12") == [asset])
        let days = try #require(Dispatcher(store: store).handle(["version":1,"requestId":UUID().uuidString,"method":"journal.listDays","params":[:]])["result"] as? [[String:Any]])
        #expect(days.first?["day"] as? String == "2026-11-12" && days.first?["count"] as? Int == 1)
        let first = try library.read(id: id, offset: 0, length: MediaLibrary.chunkSize)
        let last = try library.read(id: id, offset: MediaLibrary.chunkSize, length: MediaLibrary.chunkSize)
        #expect(Data(base64Encoded: first["data"] as? String ?? "") == bytes.prefix(MediaLibrary.chunkSize))
        #expect(Data(base64Encoded: last["data"] as? String ?? "") == bytes.suffix(3))
        #expect(try library.preview(id: id) == preview)
        try library.delete(id: id)
        #expect(try store.mediaAssets().isEmpty)
    }

    @Test func incompleteAndCancelledMediaUploadsAreNotSaved() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(directory: root), library = try MediaLibrary(vault: root, store: store)
        let upload = try library.begin(id: UUID().uuidString, day: "2026-11-12", filename: "voice.m4a", mimeType: "audio/mp4", byteCount: 4, previewBase64: nil)
        _ = try library.append(uploadID: upload, chunkIndex: 0, base64: Data([1,2]).base64EncodedString())
        #expect(throws: ServiceError.self) { try library.finish(uploadID: upload) }
        library.cancel(uploadID: upload)
        #expect(try store.mediaAssets().isEmpty)
        let staging = root.appendingPathComponent(".media-staging", isDirectory: true)
        #expect((try FileManager.default.contentsOfDirectory(atPath: staging.path)).isEmpty)
        #expect(throws: ServiceError.self) { _ = try library.begin(id: UUID().uuidString, day: "2026-11-12", filename: "payload.bin", mimeType: "application/octet-stream", byteCount: 1, previewBase64: nil) }
        #expect(throws: ServiceError.self) { _ = try library.begin(id: UUID().uuidString, day: "2026-11-12", filename: "large.mov", mimeType: "video/quicktime", byteCount: MediaLibrary.maxBytes + 1, previewBase64: nil) }
    }

}

@Suite struct RecordingTranscriptTests {
    func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    @Test func transcriptsPersistButExclusionAndStaleSourcesCannotPublish() throws {
        let root=directory(); defer { try? FileManager.default.removeItem(at:root) }
        let store=try JournalStore(directory:root), library=try MediaLibrary(vault:root,store:store)
        let bytes=Data("original audio fixture".utf8), id=UUID().uuidString
        let upload=try library.begin(id:id,day:"2026-11-12",filename:"speech.m4a",mimeType:"audio/mp4",byteCount:bytes.count,previewBase64:nil)
        try library.append(uploadID:upload,chunkIndex:0,base64:bytes.base64EncodedString())
        let original=try library.finish(uploadID:upload)
        #expect(original.transcript == nil && original.contentDigest?.count == 64)
        let excluded = try store.setMediaAI(id:id,enabled:false)
        #expect(throws:ServiceError.self){try store.saveMediaTranscript(source:excluded,transcript:"Should not publish")}
        let included=try store.setMediaAI(id:id,enabled:true)
        let processed=try store.saveMediaTranscript(source:included,transcript:"We watched the sunrise by the lake.")
        #expect(processed.transcript == "We watched the sunrise by the lake.")
        let reopened=try JournalStore(directory:root)
        #expect(try reopened.mediaAsset(id:id)?.transcript == processed.transcript)
        let chunk=try library.read(id:id,offset:0,length:MediaLibrary.chunkSize)
        #expect(chunk["data"] as? String == bytes.base64EncodedString())
        _ = try store.setMediaAI(id:id,enabled:false)
        #expect(try store.mediaAsset(id:id)?.transcript == nil)
        #expect(throws:ServiceError.self){try store.saveMediaTranscript(source:included,transcript:"Late output")}
        _ = try store.deleteMedia(id:id)
        #expect(throws:ServiceError.self){try store.saveMediaTranscript(source:processed,transcript:"Deleted recording")}
    }
    @Test @MainActor func injectedProcessingPublishesWithoutRequestingPermissions() async throws {
        let root=directory(); defer { try? FileManager.default.removeItem(at:root) }
        let store=try JournalStore(directory:root), library=try MediaLibrary(vault:root,store:store)
        let upload=try library.begin(id:UUID().uuidString,day:"2026-11-12",filename:"clip.mov",mimeType:"video/quicktime",byteCount:3,previewBase64:nil)
        try library.append(uploadID:upload,chunkIndex:0,base64:Data([1,2,3]).base64EncodedString())
        let asset=try library.finish(uploadID:upload)
        _ = try store.setMediaAI(id:asset.id,enabled:true)
        let jobs=SpeechJobs(store:store,library:library,processor:FixtureSpeech(),semanticIndex:LocalSemanticIndex(store:store))
        let started=try jobs.start(id:asset.id,purpose:"summary")
        for _ in 0..<100 { if try jobs.status(id:started.id).state != "running" { break }; await Task.yield() }
        #expect(try jobs.status(id:started.id).state == "complete")
        #expect(try store.mediaAsset(id:asset.id)?.transcript == "A synthetic spoken memory.")
    }
    @Test @MainActor func cancellationAndConsentChangesRejectLateResults() async throws {
        let root=directory(); defer { try? FileManager.default.removeItem(at:root) }
        let store=try JournalStore(directory:root), library=try MediaLibrary(vault:root,store:store)
        let upload=try library.begin(id:UUID().uuidString,day:"2026-11-12",filename:"voice.m4a",mimeType:"audio/mp4",byteCount:3,previewBase64:nil)
        try library.append(uploadID:upload,chunkIndex:0,base64:Data([1,2,3]).base64EncodedString())
        let asset=try library.finish(uploadID:upload)
        let delayed=DelayedFixtureSpeech(),jobs=SpeechJobs(store:store,library:library,processor:delayed,semanticIndex:LocalSemanticIndex(store:store))
        _ = try store.setMediaAI(id:asset.id,enabled:true)
        let job=try jobs.start(id:asset.id,purpose:"summary")
        while delayed.resume == nil { await Task.yield() }
        jobs.cancelAsset(id:asset.id)
        _ = try store.setMediaAI(id:asset.id,enabled:false)
        delayed.resume?.resume(returning:"Late recognition ignored by cancellation.");delayed.resume=nil
        for _ in 0..<20 { await Task.yield() }
        #expect(try jobs.status(id:job.id).state == "cancelled")
        #expect(try store.mediaAsset(id:asset.id)?.transcript == nil)
        #expect(try library.read(id:asset.id,offset:0,length:3)["data"] as? String == Data([1,2,3]).base64EncodedString())
    }
}
@MainActor private struct FixtureSpeech: RecordingTranscribing {
    func transcribe(url:URL,progress:@escaping(String)->Void) async throws -> String { progress("Synthetic processing");return "A synthetic spoken memory." }
}
@MainActor private final class DelayedFixtureSpeech: RecordingTranscribing {
    var resume:CheckedContinuation<String,Error>?
    func transcribe(url:URL,progress:@escaping(String)->Void) async throws -> String { try await withCheckedThrowingContinuation { resume=$0 } }
}
