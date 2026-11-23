import Foundation

/// Serializes model calls across weeks; presentation changes never own job lifetimes.
private actor SummaryModelQueue {
    private var busy = false
    private var preferred = ""
    private var waiting: [UUID: String] = [:]
    func prioritize(_ key: String) { preferred = key }
    func acquire(key: String) async throws {
        let ticket = UUID(); waiting[ticket] = key
        defer { waiting.removeValue(forKey: ticket) }
        while busy || (key != preferred && waiting.values.contains(preferred)) {
            try await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
        busy = true
    }
    func release() { busy = false }
}
private struct QueuedSummaryProvider: SummaryProvider {
    let base: any SummaryProvider
    let queue: SummaryModelQueue
    let key: String
    var sourceLabel: String { base.sourceLabel }
    func summarize(_ evidence: [SummaryEvidence], weekly: Bool) async throws -> GroundedSummary {
        try await queue.acquire(key: key)
        do {
            let result = try await base.summarize(evidence, weekly: weekly)
            await queue.release()
            return result
        } catch { await queue.release(); throw error }
    }
}
@MainActor public final class SummaryJobs {
    private let store: JournalStore
    private let factory: @Sendable () throws -> any SummaryProvider
    private let queue = SummaryModelQueue()
    private var workers: [String: SummaryWorker] = [:]
    private var owners: [String: SummaryWorker] = [:]
    public init(store: JournalStore, provider: any SummaryProvider = AppleSummaryProvider()) {
        self.store = store; factory = { provider }
    }
    public init(store: JournalStore, providerFactory: @escaping @Sendable () throws -> any SummaryProvider) {
        self.store = store; factory = providerFactory
    }
    public func evidence(days: [String], contexts: [SummaryContext]) throws -> [SummaryEvidence] {
        try SummaryWorker(store: store).evidence(days: days, contexts: contexts)
    }
    public func start(days: [String], contexts: [SummaryContext]) throws -> SummaryJob {
        let key = days.sorted().first ?? ""
        Task { await queue.prioritize(key) }
        let worker: SummaryWorker
        if let existing = workers[key] { worker = existing }
        else {
            let factory = self.factory, queue = self.queue
            worker = SummaryWorker(store: store, providerFactory: { QueuedSummaryProvider(base: try factory(), queue: queue, key: key) })
            workers[key] = worker
        }
        let job = try worker.start(days: days.sorted(), contexts: contexts)
        owners[job.id] = worker
        return job
    }
    public func status(id: String) throws -> SummaryJob {
        guard let worker = owners[id] else { throw ServiceError("missing", "Summary job expired.") }
        return try worker.status(id: id)
    }
    public func sources(id: String, scope: String) throws -> [SummaryEvidence] {
        guard let worker = owners[id] else { throw ServiceError("missing", "Summary job expired. Refresh the summary.") }
        return try worker.sources(id: id, scope: scope)
    }
    public func cancel(id: String) { owners[id]?.cancel(id: id) }
    public func cancelAll() { for (id, worker) in owners { worker.cancel(id: id) } }
}
