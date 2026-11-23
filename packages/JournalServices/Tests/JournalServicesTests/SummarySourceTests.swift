import Foundation
import Testing
@testable import JournalServices

private struct SourceTestProvider: SummaryProvider {
    func summarize(_ evidence: [SummaryEvidence], weekly: Bool) async throws -> GroundedSummary {
        try await Task.sleep(for: .milliseconds(20))
        let selected = evidence.filter { $0.kind == "reported_text" }
        return GroundedSummary(title: "A day by the lake", detail: "I spent a quiet afternoon by the water.", sourceIDs: selected.map(\.id))
    }
}
@Suite struct SummarySourceTests {
    @Test @MainActor func referencedSourcesRespectScopeAndEligibility() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store=try JournalStore(directory:root),first=UUID().uuidString,second=UUID().uuidString,secret=UUID().uuidString
        _ = try store.save(id:first,day:"2026-11-15",body:"I visited a quiet lakeside park.",timezone:"UTC",allowsAI:true,expectedRevision:nil)
        _ = try store.save(id:second,day:"2026-11-16",body:"I made a meal with friends.",timezone:"UTC",allowsAI:true,expectedRevision:nil)
        _ = try store.save(id:secret,day:"2026-11-16",body:"Excluded private note",timezone:"UTC",allowsAI:false,expectedRevision:nil)
        let jobs=SummaryJobs(store:store,provider:SourceTestProvider())
        let job=try jobs.start(days:["2026-11-15","2026-11-16"],contexts:[])
        #expect(throws:ServiceError.self) { try jobs.sources(id:job.id,scope:"week") }
        var status=try jobs.status(id:job.id)
        for _ in 0..<200 where status.state == "running" { try await Task.sleep(for:.milliseconds(10));status=try jobs.status(id:job.id) }
        #expect(status.state == "complete")
        let daySources=try jobs.sources(id:job.id,scope:"2026-11-15")
        #expect(daySources.map(\.id)==[first])
        let weekSources=try jobs.sources(id:job.id,scope:"week")
        #expect(Set(weekSources.map(\.id))==Set([first,second]))
        #expect(!weekSources.contains { $0.id == secret })
        #expect(throws:ServiceError.self) { try jobs.sources(id:job.id,scope:"2026-11-17") }
        #expect(throws:ServiceError.self) { try jobs.sources(id:UUID().uuidString,scope:"week") }
        try store.delete(id:second,expectedRevision:1)
        #expect(throws:ServiceError.self) { try jobs.sources(id:job.id,scope:"week") }
        let updated=try jobs.start(days:["2026-11-15","2026-11-16"],contexts:[])
        var refreshed=try jobs.status(id:updated.id)
        for _ in 0..<200 where refreshed.state == "running" { try await Task.sleep(for:.milliseconds(10));refreshed=try jobs.status(id:updated.id) }
        #expect(refreshed.state == "complete")
        #expect(!((try jobs.sources(id:updated.id,scope:"week")).contains { $0.id == second }))
        _ = try store.save(id:first,day:"2026-11-15",body:"I visited a quiet lakeside park.",timezone:"UTC",allowsAI:false,expectedRevision:1)
        #expect(throws:ServiceError.self) { try jobs.sources(id:updated.id,scope:"week") }
    }
}
