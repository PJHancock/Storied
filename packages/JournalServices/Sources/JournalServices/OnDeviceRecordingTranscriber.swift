import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

@MainActor public struct OnDeviceRecordingTranscriber: RecordingTranscribing {
    public init() {}
    public func transcribe(url: URL, progress: @escaping (String) -> Void) async throws -> String {
        try Task.checkCancellation()
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            progress("Allow Speech Recognition to transcribe this recording locally.")
            _ = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        }
        try Task.checkCancellation()
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw ServiceError("speechUnavailable", "On-device speech recognition is unavailable or not authorized for this language. Check Speech Recognition access in System Settings. Original recording remains saved.")
        }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0, duration <= 900 else { throw ServiceError("speechLimit", "Local transcription supports recordings up to 15 minutes. Original recording remains saved.") }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("memory-speech-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: folder) }
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: folder.path)
        #endif
        var parts: [String] = []
        for start in stride(from: 0.0, to: duration, by: 30) {
            try Task.checkCancellation()
            progress("Transcribing speech · \(Int(start)) of \(Int(duration.rounded(.up))) seconds")
            let segment = folder.appendingPathComponent("segment.m4a")
            try? FileManager.default.removeItem(at: segment)
            guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { throw ServiceError("speechAudio", "Audio extraction unavailable. Original recording retained.") }
            export.outputURL = segment; export.outputFileType = .m4a
            export.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: min(30, duration-start), preferredTimescale: 600))
            let gate = SpeechGate<Void>()
            try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { continuation in
                    gate.begin(continuation)
                    export.exportAsynchronously {
                        if export.status == .completed { gate.finish(.success(())) }
                        else { gate.finish(.failure(ServiceError("speechAudio", "Could not extract recording audio. Original retained."))) }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now()+45) { gate.finish(.failure(ServiceError("timeout", "Audio extraction timed out."))); export.cancelExport() }
                }
            }, onCancel: { gate.finish(.failure(CancellationError())); export.cancelExport() })
            try Task.checkCancellation()
            let text = try await recognize(segment, recognizer: recognizer)
            parts.append(text)
            guard parts.joined(separator: " ").utf8.count <= 100_000 else { throw ServiceError("speechLimit", "Transcript exceeds 100 KB. Original recording retained.") }
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }
    private func recognize(_ url: URL, recognizer: SFSpeechRecognizer) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = false
        let gate = SpeechGate<String>()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                gate.begin(continuation)
                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal { gate.finish(.success(result.bestTranscription.formattedString)) }
                    else if let error {
                        let speechError = error as NSError
                        if speechError.domain == "kAFAssistantErrorDomain", speechError.code == 1110 {
                            // A silent 30-second segment is expected in longer recordings.
                            // Skip it so later segments can still contribute speech.
                            gate.finish(.success(""))
                        } else {
                            gate.finish(.failure(ServiceError("speech", "Speech recognition failed: " + error.localizedDescription)))
                        }
                    }
                }
                gate.register { task.cancel() }
                DispatchQueue.global().asyncAfter(deadline: .now()+45) { gate.finish(.failure(ServiceError("timeout", "Local speech recognition timed out."))); gate.cancel() }
            }
        }, onCancel: { gate.finish(.failure(CancellationError())); gate.cancel() })
    }
}
private final class SpeechGate<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var result: Result<T, Error>?
    private var cancellation: (() -> Void)?
    func begin(_ value: CheckedContinuation<T, Error>) {
        lock.lock(); if let result { lock.unlock(); value.resume(with: result) } else { continuation = value; lock.unlock() }
    }
    func finish(_ value: Result<T, Error>) {
        lock.lock(); guard result == nil else { lock.unlock(); return }
        result = value; let saved = continuation; continuation = nil; lock.unlock(); saved?.resume(with: value)
    }
    func register(_ cancel: @escaping () -> Void) { lock.lock(); cancellation = cancel; let done = result != nil; lock.unlock(); if done { cancel() } }
    func cancel() { lock.lock(); let work = cancellation; cancellation = nil; lock.unlock(); work?() }
}
