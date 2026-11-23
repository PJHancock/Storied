import Foundation

public struct VisualAnalysisJob: Codable {
    public let id: String
    public let assetID: String
    public var state: String
    public var message: String
    public var asset: MediaAsset?
}

@MainActor public final class VisualAnalysisJobs {
    private let store: JournalStore
    private let library: MediaLibrary
    private let semanticIndex: LocalSemanticIndex
    private var tasks: [String: Task<Void, Never>] = [:]
    private var jobs: [String: VisualAnalysisJob] = [:]

    public init(store: JournalStore, library: MediaLibrary, semanticIndex: LocalSemanticIndex) {
        self.store = store
        self.library = library
        self.semanticIndex = semanticIndex
    }

    public func start(id: String) throws -> VisualAnalysisJob {
        guard let source = try store.mediaAsset(id: id), ["photo", "video"].contains(source.kind), source.allowsAI == true else {
            throw ServiceError("excluded", "Enable visual clues for this photo or video before analyzing it.")
        }
        guard tasks.isEmpty else { throw ServiceError("busy", "Another photo or video is being analyzed. Finish or cancel it first.") }
        let (url, kind, mimeType) = try library.visualSource(id: id)
        let openAIProvider = try OpenAIProviderSettings.makeVisualDescriptionProvider()
        if jobs.count >= 20 { jobs = jobs.filter { $0.value.state == "running" } }
        let jobID = UUID().uuidString
        let startMessage = openAIProvider == nil ? "Preparing local photo/video understanding…" : "Sending resized uploaded media to OpenAI for visual understanding…"
        jobs[jobID] = VisualAnalysisJob(id: jobID, assetID: source.id, state: "running", message: startMessage, asset: nil)
        tasks[jobID] = Task { @MainActor [self] in
            defer { tasks.removeValue(forKey: jobID) }
            do {
                try Task.checkCancellation()
                let result = try await OnDeviceVisualAnalyzer().analyze(url: url, kind: kind, mimeType: mimeType, openAIProvider: openAIProvider)
                try Task.checkCancellation()
                guard try store.mediaAsset(id: source.id) == source, source.allowsAI == true else {
                    throw ServiceError("staleRevision", "The photo/video changed or was excluded. Retry its analysis.")
                }
                let asset = try store.saveMediaAnalysis(source: source, text: result.text)
                if let revision = asset.analysisRevision {
                    let indexedText = [asset.analysisText, asset.transcript].compactMap { $0 }.joined(separator: "\n")
                    _ = try? semanticIndex.index(id: asset.id, type: asset.kind, revision: revision, text: indexedText)
                }
                jobs[jobID]?.state = "complete"
                if let providerFailure = result.providerFailure {
                    jobs[jobID]?.message = "OpenAI visual analysis failed (\(providerFailure)); saved local Vision clues only. Retry when ready."
                } else if result.provider == "OpenAI" {
                    jobs[jobID]?.message = "OpenAI visual description and local Vision text/labels are ready. Review uncertain details."
                } else if result.provider == "Apple Intelligence" {
                    jobs[jobID]?.message = "Apple on-device visual description and Vision text/labels are ready. Review uncertain details."
                } else {
                    jobs[jobID]?.message = "Apple's image model was unavailable; local Vision text and labels are ready. Review them for omissions."
                }
                jobs[jobID]?.asset = asset
            } catch {
                guard jobs[jobID]?.state != "cancelled" else { return }
                jobs[jobID]?.state = error is CancellationError ? "cancelled" : "failed"
                jobs[jobID]?.message = error.localizedDescription
            }
        }
        return jobs[jobID]!
    }

    public func status(id: String) throws -> VisualAnalysisJob {
        guard let job = jobs[id] else { throw ServiceError("notFound", "Visual-analysis job expired. Retry the saved photo or video.") }
        return job
    }

    public func cancel(id: String) {
        tasks[id]?.cancel()
        jobs[id]?.state = "cancelled"
        jobs[id]?.message = "Analysis cancelled. Original photo/video retained."
    }

    public func cancelAsset(id: String) {
        for (jobID, job) in jobs where job.assetID == id.uppercased() && job.state == "running" { cancel(id: jobID) }
    }
}
