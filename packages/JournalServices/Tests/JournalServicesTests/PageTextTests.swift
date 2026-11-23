import Foundation
import Testing
@testable import JournalServices

@Suite struct PageTextTests {
    @Test func photoLayoutSavesAndResetsIndependently() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(directory: root), week = "2026-11-15"
        let original = ["day.2026-11-16.photoPlacement":"beside", "day.2026-11-16.photoSize":"large", "day.2026-11-16.style":"ticket"]
        let first = try store.savePageText(weekOf: week, fields: original, expectedRevision: 0)
        #expect(try JournalStore(directory: root).pageText(weekOf: week).fields == original)
        var fields = original; fields.removeValue(forKey: "day.2026-11-16.photoPlacement")
        let reset = try store.savePageText(weekOf: week, fields: fields, expectedRevision: first.revision)
        #expect(reset.fields["day.2026-11-16.photoSize"] == "large")
        #expect(reset.fields["day.2026-11-16.style"] == "ticket")
        #expect(throws: ServiceError.self) { try store.savePageText(weekOf: week, fields: ["day.2026-11-16.photoPlacement":"diagonal"], expectedRevision: reset.revision) }
        #expect(throws: ServiceError.self) { try store.savePageText(weekOf: week, fields: ["day.2026-11-22.photoSize":"small"], expectedRevision: reset.revision) }
        #expect(throws: ServiceError.self) { try store.savePageText(weekOf: week, fields: original, expectedRevision: first.revision) }
    }

    @Test func cardStylePersistsAndAutomaticRemovesOnlySelectedStyle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(directory: root), week = "2026-11-15"
        let original = ["week.subtitle":"My week", "day.2026-11-16.style":"ticket", "day.2026-11-17.style":"photo"]
        let first = try store.savePageText(weekOf: week, fields: original, expectedRevision: 0)
        #expect(try JournalStore(directory: root).pageText(weekOf: week).fields == original)
        var reset = original; reset.removeValue(forKey: "day.2026-11-16.style")
        let second = try store.savePageText(weekOf: week, fields: reset, expectedRevision: first.revision)
        #expect(second.fields["day.2026-11-16.style"] == nil)
        #expect(second.fields["day.2026-11-17.style"] == "photo")
        #expect(second.fields["week.subtitle"] == "My week")
        #expect(throws: ServiceError.self) { try store.savePageText(weekOf: week, fields: ["day.2026-11-16.style":"invalid"], expectedRevision: second.revision) }
        #expect(throws: ServiceError.self) { try store.savePageText(weekOf: week, fields: ["day.2026-11-22.style":"ticket"], expectedRevision: second.revision) }
        #expect(throws: ServiceError.self) { try store.savePageText(weekOf: week, fields: original, expectedRevision: first.revision) }
    }

    @Test func editsPersistAndConcurrentWritesAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(directory: root)
        let fields = ["week.subtitle": "My own week", "week.summaryDetail": "First paragraph\n\nSecond paragraph", "day.2026-11-16.title": "An afternoon together"]
        let saved = try store.savePageText(weekOf: "2026-11-15", fields: fields, expectedRevision: 0)
        #expect(saved.revision == 1)
        #expect(try JournalStore(directory: root).pageText(weekOf: "2026-11-15").fields == fields)
        #expect(throws: ServiceError.self) { try store.savePageText(weekOf: "2026-11-15", fields: [:], expectedRevision: 0) }
        #expect(try store.pageText(weekOf: "2026-11-15").fields == fields)
        let reset = try store.savePageText(weekOf: "2026-11-15", fields: [:], expectedRevision: 1)
        #expect(reset.fields.isEmpty)
    }
    @Test func rejectsUnknownFieldsAndPreservesSourceMemory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(directory: root), id = UUID().uuidString
        _ = try store.save(id: id, day: "2026-11-16", body: "An original memory", timezone: "UTC", allowsAI: true, expectedRevision: nil)
        #expect(throws: ServiceError.self) { try store.savePageText(weekOf: "2026-11-15", fields: ["system.apiKey": "invalid"], expectedRevision: 0) }
        _ = try store.savePageText(weekOf: "2026-11-15", fields: ["day.2026-11-16.title": "My title"], expectedRevision: 0)
        #expect(try store.entries(day: "2026-11-16").first?.body == "An original memory")
        _ = try store.save(id: id, day: "2026-11-16", body: "Updated source", timezone: "UTC", allowsAI: true, expectedRevision: 1)
        #expect(try store.pageText(weekOf: "2026-11-15").fields["day.2026-11-16.title"] == "My title")
    }
}
