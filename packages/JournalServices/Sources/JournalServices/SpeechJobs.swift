import Foundation

@MainActor public protocol RecordingTranscribing {
    func transcribe(url: URL, progress: @escaping (String) -> Void) async throws -> String
}
public struct SpeechJobStatus: Codable {
    public let id: String
    public let assetID: String
    public var state: String
    public var message: String
    public var transcript: String?
    public var asset: MediaAsset?
}
@MainActor public final class SpeechJobs {
    private let store: JournalStore
    private let library: MediaLibrary
    private let processor: any RecordingTranscribing
    private let semanticIndex: LocalSemanticIndex
    private var tasks: [String: Task<Void, Never>] = [:]
    private var jobs: [String: SpeechJobStatus] = [:]
    public init(store: JournalStore, library: MediaLibrary, processor: any RecordingTranscribing, semanticIndex: LocalSemanticIndex) {
        self.store = store; self.library = library; self.processor = processor; self.semanticIndex = semanticIndex
    }
    public func start(id: String, purpose: String) throws -> SpeechJobStatus {
        guard ["summary", "dictation"].contains(purpose), let source = try store.mediaAsset(id: id), ["audio", "video"].contains(source.kind),
              purpose == "dictation" || source.allowsAI == true else { throw ServiceError("excluded", "Enable recording inclusion before transcription.") }
        guard tasks.isEmpty else { throw ServiceError("busy", "Another recording is being transcribed. Finish or cancel it first.") }
        let url = try library.analysisSource(id: id)
        if jobs.count >= 20 { jobs.removeAll() }
        let jobID = UUID().uuidString
        let status = SpeechJobStatus(id: jobID, assetID: source.id, state: "running", message: "Preparing local speech recognition…")
        jobs[jobID] = status
        tasks[jobID] = Task { @MainActor [self] in
            defer { tasks.removeValue(forKey: jobID) }
            do {
                // Preserve the original bytes and give AVFoundation a codec-appropriate suffix.
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("recording-job-" + jobID)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                defer { try? FileManager.default.removeItem(at: folder) }
                let suffix = source.mimeType.contains("webm") ? "webm" : source.mimeType.contains("wav") ? "wav" : source.mimeType.contains("mpeg") ? "mp3" : source.mimeType.contains("quicktime") ? "mov" : source.kind == "audio" ? "m4a" : "mp4"
                let input = folder.appendingPathComponent("original." + suffix)
                try FileManager.default.copyItem(at: url, to: input)
                #if os(iOS)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: folder.path)
                #endif
                try Task.checkCancellation()
                let text = try await processor.transcribe(url: input) { [weak self] message in
                    guard self?.jobs[jobID]?.state == "running" else { return }
                    self?.jobs[jobID]?.message = message
                }
                try Task.checkCancellation()
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 100_000 else { throw ServiceError("noSpeech", "The on-device recognizer returned no words. The original is still saved. This can happen with silence, unclear audio, or speech in a different language. If you can hear the words, add a transcript manually or retry with clearer audio.") }
                guard try store.mediaAsset(id: source.id) == source else { throw ServiceError("staleRevision", "Recording changed or was removed while processing.") }
                let asset = purpose == "summary" ? try store.saveMediaTranscript(source: source, transcript: text) : nil
                if let asset, let revision = asset.analysisRevision {
                    let indexedText = [asset.analysisText, asset.transcript].compactMap { $0 }.joined(separator: "\n")
                    _ = try? semanticIndex.index(id: asset.id, type: asset.kind, revision: revision, text: indexedText)
                }
                jobs[jobID]?.state = "complete"; jobs[jobID]?.message = "Transcription complete. Recognition may contain mistakes."
                jobs[jobID]?.transcript = text; jobs[jobID]?.asset = asset
            } catch {
                guard jobs[jobID]?.state != "cancelled" else { return }
                jobs[jobID]?.state = error is CancellationError ? "cancelled" : "failed"
                jobs[jobID]?.message = error.localizedDescription
            }
        }
        return status
    }
    public func status(id: String) throws -> SpeechJobStatus {
        guard let job = jobs[id] else { throw ServiceError("notFound", "Processing job expired. Retry the saved recording.") }; return job
    }
    public func cancel(id: String) {
        tasks[id]?.cancel(); jobs[id]?.state = "cancelled"; jobs[id]?.message = "Processing cancelled. Original recording retained."
    }
    public func cancelAsset(id: String) {
        for (jobID, job) in jobs where job.assetID == id.uppercased() && job.state == "running" { cancel(id: jobID) }
    }
}
