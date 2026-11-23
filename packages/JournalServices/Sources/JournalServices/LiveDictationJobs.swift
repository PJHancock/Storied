import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

public struct LiveDictationStatus: Codable, Sendable {
    public let id: String
    public var state: String
    public var message: String
    public var transcript: String
}

/// Streams microphone audio to Apple's on-device recognizer and exposes interim text to the UI.
@MainActor public final class LiveDictationJobs {
    private var statuses: [String: LiveDictationStatus] = [:]
    private var engines: [String: AVAudioEngine] = [:]
    private var requests: [String: SFSpeechAudioBufferRecognitionRequest] = [:]
    private var recognitionTasks: [String: SFSpeechRecognitionTask] = [:]
    private var timeouts: [String: Task<Void, Never>] = [:]

    public init() {}

    public func start() async throws -> LiveDictationStatus {
        guard !statuses.values.contains(where: { $0.state == "running" || $0.state == "stopping" }) else {
            throw ServiceError("busy", "Finish the current dictation before starting another.")
        }
        try await authorizeSpeech()
        try await authorizeMicrophone()
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            throw ServiceError("speechUnavailable", "On-device speech recognition is unavailable for this language. Dictation stays on this device.")
        }

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true)
        #endif

        let id = UUID().uuidString
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
            throw ServiceError("microphoneUnavailable", "No microphone input is available.")
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in request.append(buffer) }
        engine.prepare()
        do { try engine.start() }
        catch {
            input.removeTap(onBus: 0)
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
            throw ServiceError("microphoneUnavailable", "Could not start microphone dictation. Check microphone access and try again.")
        }

        statuses[id] = LiveDictationStatus(id: id, state: "running", message: "Listening…", transcript: "")
        engines[id] = engine
        requests[id] = request
        recognitionTasks[id] = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in self?.receive(id: id, result: result, error: error) }
        }
        timeouts[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000_000)
            guard !Task.isCancelled else { return }
            self?.stop(id: id, message: "Two-minute limit reached. Finishing dictation…")
        }
        return statuses[id]!
    }

    public func status(id: String) throws -> LiveDictationStatus {
        guard let status = statuses[id] else { throw ServiceError("notFound", "Dictation session expired.") }
        return status
    }

    public func stop(id: String) -> LiveDictationStatus {
        stop(id: id, message: "Finishing dictation…")
        return statuses[id] ?? LiveDictationStatus(id: id, state: "failed", message: "Dictation session expired.", transcript: "")
    }

    public func cancel(id: String) -> LiveDictationStatus {
        guard var status = statuses[id] else {
            return LiveDictationStatus(id: id, state: "cancelled", message: "Dictation cancelled.", transcript: "")
        }
        status.state = "cancelled"
        status.message = "Dictation cancelled. Draft text was restored."
        statuses[id] = status
        recognitionTasks[id]?.cancel()
        stopAudio(id: id)
        return status
    }

    private func stop(id: String, message: String) {
        guard var status = statuses[id], status.state == "running" else { return }
        status.state = "stopping"
        status.message = message
        statuses[id] = status
        timeouts[id]?.cancel()
        requests[id]?.endAudio()
        engines[id]?.stop()
        timeouts[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self, !Task.isCancelled, self.statuses[id]?.state == "stopping" else { return }
            self.fail(id: id, message: "Speech recognition did not finish. Any recognized text remains in the draft.")
        }
    }

    private func receive(id: String, result: SFSpeechRecognitionResult?, error: Error?) {
        guard var status = statuses[id], status.state == "running" || status.state == "stopping" else { return }
        if let result {
            let transcript = result.bestTranscription.formattedString
            guard transcript.utf8.count <= 100_000 else {
                fail(id: id, message: "Dictation exceeded the 100 KB text limit. Recognized text up to that point remains in the draft.")
                return
            }
            status.transcript = transcript
            if result.isFinal {
                status.state = "complete"
                status.message = "Dictation complete. Review the recognized text."
                statuses[id] = status
                stopAudio(id: id)
                return
            }
        }
        if let error {
            fail(id: id, message: "Speech recognition stopped: \(error.localizedDescription)")
            return
        }
        statuses[id] = status
    }

    private func fail(id: String, message: String) {
        guard var status = statuses[id], status.state == "running" || status.state == "stopping" else { return }
        status.state = "failed"
        status.message = message
        statuses[id] = status
        recognitionTasks[id]?.cancel()
        stopAudio(id: id)
    }

    private func stopAudio(id: String) {
        timeouts[id]?.cancel(); timeouts.removeValue(forKey: id)
        if let engine = engines.removeValue(forKey: id) {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        requests.removeValue(forKey: id)
        recognitionTasks.removeValue(forKey: id)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func authorizeSpeech() async throws {
        let current = SFSpeechRecognizer.authorizationStatus()
        let status: SFSpeechRecognizerAuthorizationStatus
        if current == .notDetermined {
            status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        } else { status = current }
        guard status == .authorized else {
            throw ServiceError("speechPermission", "Allow Speech Recognition to use Dictate text.")
        }
    }

    private func authorizeMicrophone() async throws {
        let current = AVCaptureDevice.authorizationStatus(for: .audio)
        let authorized: Bool
        if current == .notDetermined {
            authorized = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
            }
        } else { authorized = current == .authorized }
        guard authorized else { throw ServiceError("microphonePermission", "Allow microphone access to use Dictate text.") }
    }
}
