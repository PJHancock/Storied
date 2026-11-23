import Foundation
import Testing
@testable import JournalServices

private actor WeekFailureProvider: SummaryProvider {
    var dailyCalls = 0
    func summarize(_ evidence: [SummaryEvidence], weekly: Bool) async throws -> GroundedSummary {
        if weekly { throw ServiceError("synthetic", "Weekly generation failed") }
        dailyCalls += 1
        try await Task.sleep(for: .milliseconds(30))
        return GroundedSummary(title: "My lakeside afternoon", detail: "I spent time beside the water and enjoyed the afternoon.", sourceIDs: evidence.map(\.id))
    }
    func calls() -> Int { dailyCalls }
}
@Suite struct FluidSummaryTests {
    @Test func weatherCacheSurvivesStoreRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try JournalStore(directory: root).saveWeatherCache(key: "synthetic-city:2026-11-12", payload: "cached synthetic weather")
        #expect(try JournalStore(directory: root).weatherCache(key: "synthetic-city:2026-11-12") == "cached synthetic weather")
    }

    @Test @MainActor func dailySuccessSurvivesWeeklyFailureAndRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(directory: root), day = "2026-11-12", provider = WeekFailureProvider()
        _ = try store.save(id: UUID().uuidString, day: day, body: "I visited a lake on Thursday.", timezone: "UTC", allowsAI: true, expectedRevision: nil)
        let jobs = SummaryJobs(store: store, provider: provider)
        let first = try jobs.start(days: [day], contexts: [])
        #expect(try jobs.start(days: [day], contexts: []).id == first.id)
        var state = try jobs.status(id: first.id)
        for _ in 0..<200 where state.state == "running" {
            try await Task.sleep(for: .milliseconds(10)); state = try jobs.status(id: first.id)
        }
        #expect(state.state == "failed")
        #expect(try store.savedSummary(key: "day:" + day) != nil)
        let restarted = SummaryJobs(store: try JournalStore(directory: root), provider: provider)
        let retry = try restarted.start(days: [day], contexts: [])
        for _ in 0..<200 where try restarted.status(id: retry.id).state == "running" { try await Task.sleep(for: .milliseconds(10)) }
        #expect(await provider.calls() == 1)
    }
    @Test @MainActor func navigationKeepsOtherWeekRunningAndExclusionRemovesOldDisplay() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(directory: root), jobs = SummaryJobs(store: store, provider: WeekFailureProvider())
        let id = UUID().uuidString
        _ = try store.save(id: id, day: "2026-11-05", body: "I visited a lake on Thursday.", timezone: "UTC", allowsAI: true, expectedRevision: nil)
        _ = try store.save(id: UUID().uuidString, day: "2026-11-12", body: "I visited a lake again.", timezone: "UTC", allowsAI: true, expectedRevision: nil)
        let old = try jobs.start(days: ["2026-11-05"], contexts: [])
        _ = try jobs.start(days: ["2026-11-12"], contexts: [])
        for _ in 0..<200 where try jobs.status(id: old.id).state == "running" { try await Task.sleep(for: .milliseconds(10)) }
        #expect(try store.savedSummary(key: "day:2026-11-05") != nil)
        _ = try store.save(id: id, day: "2026-11-05", body: "I visited a lake on Thursday.", timezone: "UTC", allowsAI: false, expectedRevision: 1)
        let excluded = try jobs.start(days: ["2026-11-05"], contexts: [])
        #expect(excluded.summaries["2026-11-05"] == nil)
    }
}
