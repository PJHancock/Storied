import SwiftUI
import WebKit
import JournalServices
import CoreFoundation
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

@main struct MemoryCatcherApp: App {
    var body: some Scene {
        #if os(macOS)
        WindowGroup {
                if Bundle.main.object(forInfoDictionaryKey: "MemoryCatcherDevelopmentDiagnostics") as? Bool == true { ModelDiagnosticsView() }
                else { JournalHost().frame(minWidth: 320, minHeight: 640) }
            }
            .defaultSize(width: CGFloat((Bundle.main.object(forInfoDictionaryKey: "MemoryCatcherDevelopmentWidth") as? NSNumber)?.doubleValue ?? 1280), height: 900)
        #else
        WindowGroup { JournalHost() }
        #endif
    }
}

struct JournalHost: View {
    @State private var error: String?
    var body: some View {
        Group {
            if let error { VStack(spacing: 20) { Text("Could not open Memory Catcher").font(.headline); Text(error).textSelection(.enabled); Button("Try again") { self.error = nil } }.padding() }
            else { WebJournal(failed: { error = $0 }) }
        }
    }
}
final class Bridge: NSObject, WKScriptMessageHandlerWithReply, WKNavigationDelegate, WKUIDelegate {
    let store: JournalStore
    let vault: URL
    #if os(macOS)
    private var restoredVault: URL?
    #endif
    let speechJobs: SpeechJobs
    let liveDictationJobs: LiveDictationJobs
    let visualJobs: VisualAnalysisJobs
    let summaryJobs: SummaryJobs
    let dispatcher: Dispatcher
    let policy: LocalDocumentPolicy
    let connections: ResourceConnections
    let mediaLibrary: MediaLibrary
    let semanticIndex: LocalSemanticIndex
    let failed: (String) -> Void
    init(root: URL, vault: URL, failed: @escaping (String) -> Void) throws {
        self.policy = LocalDocumentPolicy(root: root); self.failed = failed; self.vault = vault
        let store = try JournalStore(directory: vault)
        self.store = store
        summaryJobs = SummaryJobs(store: store, providerFactory: { try OpenAIProviderSettings.makeSummaryProvider() })
        let semanticIndex = LocalSemanticIndex(store: store)
        self.semanticIndex = semanticIndex
        dispatcher = Dispatcher(store: store, semanticIndex: semanticIndex)
        connections = try ResourceConnections(store: store)
        mediaLibrary = try MediaLibrary(vault: vault, store: store)
        speechJobs = SpeechJobs(store: store, library: mediaLibrary, processor: OnDeviceRecordingTranscriber(), semanticIndex: semanticIndex)
        liveDictationJobs = LiveDictationJobs()
        visualJobs = VisualAnalysisJobs(store: store, library: mediaLibrary, semanticIndex: semanticIndex)
    }
    #if os(macOS)
    @MainActor private func chooseFolder(title: String, prompt: String) async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSOpenPanel(); panel.title = title; panel.prompt = prompt
            panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
            panel.begin { result in continuation.resume(returning: result == .OK ? panel.url : nil) }
        }
    }
    #endif
    func trusted(_ url: URL?) -> Bool { policy.contains(url) }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let localMainFrame = policy.permits(frame: frame.request.url, document: webView.url, isMainFrame: frame.isMainFrame)
        decisionHandler(localMainFrame ? .grant : .deny)
    }
#if os(macOS)
    @MainActor func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                            initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        guard policy.permits(frame: frame.request.url, document: webView.url, isMainFrame: frame.isMainFrame) else {
            completionHandler(nil)
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        var contentTypes: [UTType] = [.image, .audio, .movie, .plainText]
        if let markdown = UTType(filenameExtension: "md") { contentTypes.append(markdown) }
        panel.allowedContentTypes = contentTypes
        panel.begin { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }
#endif
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { failed(error.localizedDescription) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failed("The journal interface stopped. Try again to reopen your saved memories.") }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard policy.permits(frame: message.frameInfo.request.url, document: message.webView?.url, isMainFrame: message.frameInfo.isMainFrame) else { replyHandler(nil, "Untrusted bridge caller."); return }
        if let input = message.body as? [String: Any], let method = input["method"] as? String,
           ["backup.openFolder", "backup.status", "backup.export", "backup.restore", "backup.openRestored", "summary.sources", "resources.needsSync", "summary.cancelAll", "weather.cache.get", "weather.cache.save", "summary.start", "summary.status", "summary.cancel", "openai.status", "openai.configure", "openai.setEnabled", "openai.setVisualEnabled", "openai.remove", "resources.status", "resources.setEnabled", "resources.day", "resources.sync", "resources.syncBatch", "resources.hideItem", "resources.setHeadlinePhoto", "media.list", "media.begin", "media.append", "media.finish", "media.cancel", "media.preview", "media.read", "media.delete", "media.move", "media.setAI", "media.updateTranscript", "visual.start", "visual.status", "visual.cancel", "speech.start", "speech.status", "speech.cancel", "dictation.start", "dictation.status", "dictation.stop", "dictation.cancel"].contains(method) {
            guard let version = input["version"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(), version.intValue == 1, version.doubleValue == 1,
                  let requestID = input["requestId"] as? String, UUID(uuidString: requestID) != nil,
                  let params = input["params"] as? [String: Any], Set(input.keys) == ["version", "requestId", "method", "params"],
                  let payloadSize = try? JSONSerialization.data(withJSONObject: input).count, payloadSize <= 500_000 else {
                replyHandler(nil, "Invalid native request."); return
            }
            func integer(_ key: String, in values: [String: Any]) throws -> Int {
                guard let number = values[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.rounded() == number.doubleValue else { throw ServiceError("invalid", "Invalid numeric parameter.") }
                return number.intValue
            }
            func encoded<T: Encodable>(_ value: T) throws -> Any { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) }
            Task { @MainActor in
                do {
                    let result: Any
                    switch method {
                    case "openai.status":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        result = try encoded(OpenAIProviderSettings.status())
                    case "openai.configure":
                        guard Set(params.keys) == ["apiKey"], let apiKey = params["apiKey"] as? String else { throw ServiceError("invalid", "Supply an OpenAI API key.") }
                        result = try encoded(await OpenAIProviderSettings.configure(apiKey: apiKey))
                    case "openai.setEnabled":
                        guard Set(params.keys) == ["enabled"], let enabled = params["enabled"] as? NSNumber,
                              CFGetTypeID(enabled) == CFBooleanGetTypeID() else { throw ServiceError("invalid", "Supply the OpenAI summaries setting.") }
                        result = try encoded(OpenAIProviderSettings.setEnabled(enabled.boolValue))
                    case "openai.setVisualEnabled":
                        guard Set(params.keys) == ["enabled"], let enabled = params["enabled"] as? NSNumber,
                              CFGetTypeID(enabled) == CFBooleanGetTypeID() else { throw ServiceError("invalid", "Supply the OpenAI visual-understanding setting.") }
                        result = try encoded(OpenAIProviderSettings.setVisualEnabled(enabled.boolValue))
                    case "openai.remove":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        result = try encoded(OpenAIProviderSettings.remove())
                    case "summary.cancelAll":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        summaryJobs.cancelAll(); result = ["cancelled": true]
                    case "weather.cache.get":
                        guard Set(params.keys) == ["key"], let key = params["key"] as? String else { throw ServiceError("invalid", "Invalid weather key.") }
                        result = ["payload": try store.weatherCache(key: key) as Any? ?? NSNull()]
                    case "weather.cache.save":
                        guard Set(params.keys) == ["key", "payload"], let key = params["key"] as? String, let payload = params["payload"] as? String else { throw ServiceError("invalid", "Invalid weather cache.") }
                        try store.saveWeatherCache(key: key, payload: payload); result = ["saved": true]
                    case "summary.start":
                        guard Set(params.keys) == ["days", "contexts"], let days = params["days"] as? [String],
                              let values = params["contexts"] as? [[String: Any]] else { throw ServiceError("invalid", "Supply summary days and context.") }
                        let contexts = try JSONDecoder().decode([SummaryContext].self, from: JSONSerialization.data(withJSONObject: values))
                        result = try encoded(summaryJobs.start(days: days, contexts: contexts))
                    case "backup.status":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        #if os(macOS)
                        result = ["available": true, "restoredReady": restoredVault != nil]
                        #else
                        result = ["available": false, "restoredReady": false]
                        #endif
                    case "backup.export":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        #if os(macOS)
                        guard let folder = await chooseFolder(title: "Choose where to save your journal backup", prompt: "Save backup here") else { result = ["cancelled": true]; break }
                        let accessing = folder.startAccessingSecurityScopedResource(); defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
                        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("memory-catcher-snapshot-" + UUID().uuidString, isDirectory: true)
                        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                        defer { try? FileManager.default.removeItem(at: temp) }
                        try store.snapshotDatabase(to: temp.appendingPathComponent("journal.sqlite"))
                        let originalVault = vault
                        let backup = try await Task.detached(priority: .utility) {
                            let snapshot = try JournalStore(directory: temp)
                            return try JournalBackup.create(store: snapshot, vault: originalVault, destinationParent: folder)
                        }.value
                        result = ["cancelled": false, "name": backup.url.lastPathComponent, "mediaCount": backup.mediaCount]
                        #else
                        throw ServiceError("unavailable", "Backup is not available on this device yet.")
                        #endif
                    case "backup.restore":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        #if os(macOS)
                        guard let backupFolder = await chooseFolder(title: "Choose a Memory Catcher backup folder", prompt: "Choose backup") else { result = ["cancelled": true]; break }
                        let accessingBackup = backupFolder.startAccessingSecurityScopedResource(); defer { if accessingBackup { backupFolder.stopAccessingSecurityScopedResource() } }
                        guard let targetFolder = await chooseFolder(title: "Choose where to create the restored journal", prompt: "Restore here") else { result = ["cancelled": true]; break }
                        let accessingTarget = targetFolder.startAccessingSecurityScopedResource(); defer { if accessingTarget { targetFolder.stopAccessingSecurityScopedResource() } }
                        let current = vault.standardizedFileURL.resolvingSymlinksInPath().path
                        let targetPath = targetFolder.standardizedFileURL.resolvingSymlinksInPath().path
                        guard targetPath != current && !targetPath.hasPrefix(current + "/") else { throw ServiceError("backup", "Choose a restore location outside the open journal.") }
                        let source = backupFolder, target = targetFolder
                        let restored = try await Task.detached(priority: .utility) { try JournalBackup.restore(backup: source, destinationParent: target) }.value
                        restoredVault = restored.url
                        result = ["cancelled": false, "name": restored.url.lastPathComponent, "mediaCount": restored.mediaCount]
                        #else
                        throw ServiceError("unavailable", "Restore is not available on this device yet.")
                        #endif
                    case "backup.openFolder":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        #if os(macOS)
                        guard let selected = await chooseFolder(title: "Choose a restored Memory Catcher journal", prompt: "Open journal") else { result = ["cancelled": true]; break }
                        let accessing = selected.startAccessingSecurityScopedResource(); defer { if accessing { selected.stopAccessingSecurityScopedResource() } }
                        let current = vault.standardizedFileURL.resolvingSymlinksInPath().path
                        guard selected.standardizedFileURL.resolvingSymlinksInPath().path != current else { throw ServiceError("backup", "This journal is already open.") }
                        try await Task.detached(priority: .utility) { try JournalBackup.validateRestored(selected) }.value
                        let configuration = NSWorkspace.OpenConfiguration(); configuration.arguments = ["--vault", selected.path]; configuration.createsNewApplicationInstance = true
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
                                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                            }
                        }
                        result = ["cancelled": false, "opened": true]
                        #else
                        throw ServiceError("unavailable", "Opening a restored journal is not available on this device yet.")
                        #endif
                    case "backup.openRestored":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        #if os(macOS)
                        guard let restoredVault else { throw ServiceError("missing", "Restore a backup first.") }
                        let configuration = NSWorkspace.OpenConfiguration(); configuration.arguments = ["--vault", restoredVault.path]; configuration.createsNewApplicationInstance = true
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
                                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                            }
                        }
                        result = ["opened": true]
                        #else
                        throw ServiceError("unavailable", "Opening a restored journal is not available on this device yet.")
                        #endif
                    case "summary.sources":
                        guard Set(params.keys) == ["id", "scope"], let id = params["id"] as? String, let scope = params["scope"] as? String else { throw ServiceError("invalid", "Select a summary.") }
                        let sources = try summaryJobs.sources(id: id, scope: scope)
                        let status = try connections.status()
                        let photosEnabled = (status["photos"] as? [String: Any])?["enabled"] as? Bool == true
                        let calendarEnabled = (status["calendar"] as? [String: Any])?["enabled"] as? Bool == true
                        let eligible = try sources.filter { source in
                            if source.kind == "photo_inventory" || source.kind == "uncertain_visual" {
                                guard photosEnabled else { return false }
                                if source.kind == "uncertain_visual" {
                                    guard let cache = try store.connectedDayCache(day: source.day), let data = cache.payload.data(using: .utf8),
                                          let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let photos = raw["photos"] as? [[String: Any]] else { return false }
                                    let matching = photos.filter { ($0["analysisText"] as? String) == source.text }
                                    guard !matching.isEmpty else { return false }
                                    for photo in matching { if let photoID = photo["id"] as? String, try !store.contextItemHidden(day: source.day, source: "photo", itemID: photoID) { return true } }
                                    return false
                                }
                            }
                            if source.kind == "calendar_plan" && !calendarEnabled { return false }
                            if source.kind == "selected_city_weather" { if try store.contextItemHidden(day: source.day, source: "weather", itemID: source.day) { return false } }
                            return true
                        }
                        result = try eligible.map { source -> [String: Any] in
                            guard var item = try encoded(source) as? [String: Any] else { throw ServiceError("resource", "Could not encode summary sources.") }
                            if source.kind == "uncertain_visual", let cache = try store.connectedDayCache(day: source.day),
                               let data = cache.payload.data(using: .utf8), let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let photos = raw["photos"] as? [[String: Any]] {
                                var visibleIDs: [String] = []
                                for photo in photos where (photo["analysisText"] as? String) == source.text {
                                    if let photoID = photo["id"] as? String, try !store.contextItemHidden(day: source.day, source: "photo", itemID: photoID) { visibleIDs.append(photoID) }
                                }
                                if visibleIDs.count == 1 { item["targetID"] = visibleIDs[0] }
                            }
                            return item
                        }
                    case "summary.status":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a summary job.") }
                        result = try encoded(summaryJobs.status(id: id))
                    case "summary.cancel":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a summary job.") }
                        summaryJobs.cancel(id: id); result = ["cancelled": true]
                    case "resources.status":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        result = try connections.status()
                    case "resources.setEnabled":
                        guard Set(params.keys) == ["resource", "enabled"], let resource = params["resource"] as? String,
                              let enabled = params["enabled"] as? Bool else { throw ServiceError("invalid", "Supply a resource and enabled state.") }
                        result = try await connections.setEnabled(resource: resource, enabled: enabled)
                    case "resources.day":
                        guard let day = params["day"] as? String,
                              (Set(params.keys) == ["day"] || Set(params.keys) == ["day", "previewLimit"]) else { throw ServiceError("invalid", "Supply a journal day.") }
                        let previewLimit = params["previewLimit"] == nil ? 12 : try integer("previewLimit", in: params)
                        result = try await connections.day(day, previewLimit: previewLimit)
                    case "resources.needsSync":
                        guard Set(params.keys) == ["days"], let days = params["days"] as? [String] else { throw ServiceError("invalid", "Select sync days.") }
                        result = ["needed": try connections.needsSync(days: days)]
                    case "resources.sync":
                        guard Set(params.keys) == ["days"], let days = params["days"] as? [String] else { throw ServiceError("invalid", "Supply journal days to sync.") }
                        result = try await connections.sync(days: days)
                    case "resources.syncBatch":
                        guard Set(params.keys) == ["day", "offset"], let day = params["day"] as? String else { throw ServiceError("invalid", "Supply a sync day and batch.") }
                        result = try await connections.syncBatch(day: day, offset: integer("offset", in: params))
                    case "resources.hideItem":
                        guard Set(params.keys) == ["day", "source", "id", "hidden"], let day = params["day"] as? String,
                              let source = params["source"] as? String, let id = params["id"] as? String,
                              let hidden = params["hidden"] as? Bool else { throw ServiceError("invalid", "Supply a connected item.") }
                        try connections.setItemHidden(day: day, source: source, id: id, hidden: hidden)
                        result = ["hidden": hidden]
                    case "resources.setHeadlinePhoto":
                        guard Set(params.keys) == ["day", "id"], let day = params["day"] as? String,
                              params["id"] is NSNull || params["id"] is String else { throw ServiceError("invalid", "Choose a photo for this day.") }
                        result = try connections.setHeadlinePhoto(day: day, id: params["id"] as? String)
                    case "speech.start":
                        guard Set(params.keys) == ["id", "purpose"], let id = params["id"] as? String, let purpose = params["purpose"] as? String else { throw ServiceError("invalid", "Choose a saved recording and purpose.") }
                        result = try encoded(speechJobs.start(id: id, purpose: purpose))
                    case "speech.status":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a processing job.") }
                        result = try encoded(speechJobs.status(id: id))
                    case "speech.cancel":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a processing job.") }
                        speechJobs.cancel(id: id); result = ["cancelled": true]
                    case "dictation.start":
                        guard params.isEmpty else { throw ServiceError("invalid", "Unexpected parameters.") }
                        result = try encoded(await liveDictationJobs.start())
                    case "dictation.status":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a dictation session.") }
                        result = try encoded(liveDictationJobs.status(id: id))
                    case "dictation.stop":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a dictation session.") }
                        result = try encoded(liveDictationJobs.stop(id: id))
                    case "dictation.cancel":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a dictation session.") }
                        result = try encoded(liveDictationJobs.cancel(id: id))
                    case "visual.start":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a photo or video memory.") }
                        result = try encoded(visualJobs.start(id: id))
                    case "visual.status":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a visual-analysis job.") }
                        result = try encoded(visualJobs.status(id: id))
                    case "visual.cancel":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply a visual-analysis job.") }
                        visualJobs.cancel(id: id); result = ["cancelled": true]
                    case "media.setAI":
                        guard Set(params.keys) == ["id", "enabled"], let id = params["id"] as? String,
                              let enabled = params["enabled"] as? NSNumber, CFGetTypeID(enabled) == CFBooleanGetTypeID() else { throw ServiceError("invalid", "Supply recording inclusion.") }
                        speechJobs.cancelAsset(id: id); visualJobs.cancelAsset(id: id)
                        let asset = try store.setMediaAI(id: id, enabled: enabled.boolValue)
                        result = try encoded(asset)
                    case "media.updateTranscript":
                        guard Set(params.keys) == ["id", "transcript", "expectedRevision"],
                              let id = params["id"] as? String, let transcript = params["transcript"] as? String else { throw ServiceError("invalid", "Supply the edited transcript and its revision.") }
                        let asset = try store.updateMediaTranscript(id: id, transcript: transcript, expectedRevision: integer("expectedRevision", in: params))
                        if asset.allowsAI == true, let revision = asset.analysisRevision {
                            let indexedText = [asset.analysisText, asset.transcript].compactMap { $0 }.joined(separator: "\n")
                            _ = try? semanticIndex.index(id: asset.id, type: asset.kind, revision: revision, text: indexedText)
                        }
                        result = try encoded(asset)
                    case "media.list":
                        guard Set(params.keys) == ["day"], let day = params["day"] as? String else { throw ServiceError("invalid", "Supply a journal day.") }
                        result = try encoded(mediaLibrary.list(day: day))
                    case "media.move":
                        guard Set(params.keys) == ["id", "toDay"], let id = params["id"] as? String, let toDay = params["toDay"] as? String else { throw ServiceError("invalid", "Supply an attachment and destination day.") }
                        speechJobs.cancelAsset(id: id); visualJobs.cancelAsset(id: id)
                        result = try encoded(mediaLibrary.move(id: id, toDay: toDay))
                    case "media.begin":
                        guard Set(params.keys) == ["id", "day", "filename", "mimeType", "byteCount", "previewBase64"],
                              let id = params["id"] as? String, let day = params["day"] as? String,
                              let filename = params["filename"] as? String, let mime = params["mimeType"] as? String,
                              let preview = params["previewBase64"] as? String else { throw ServiceError("invalid", "Supply complete attachment details.") }
                        result = ["uploadId": try mediaLibrary.begin(id: id, day: day, filename: filename, mimeType: mime,
                                                                      byteCount: integer("byteCount", in: params),
                                                                      previewBase64: preview.isEmpty ? nil : preview)]
                    case "media.append":
                        guard Set(params.keys) == ["uploadId", "chunkIndex", "data"],
                              let upload = params["uploadId"] as? String, let data = params["data"] as? String else { throw ServiceError("invalid", "Supply an attachment chunk.") }
                        result = ["receivedBytes": try mediaLibrary.append(uploadID: upload, chunkIndex: integer("chunkIndex", in: params), base64: data)]
                    case "media.finish":
                        guard Set(params.keys) == ["uploadId"], let upload = params["uploadId"] as? String else { throw ServiceError("invalid", "Supply an upload identifier.") }
                        result = try encoded(mediaLibrary.finish(uploadID: upload))
                    case "media.cancel":
                        guard Set(params.keys) == ["uploadId"], let upload = params["uploadId"] as? String else { throw ServiceError("invalid", "Supply an upload identifier.") }
                        mediaLibrary.cancel(uploadID: upload); result = ["cancelled": true]
                    case "media.preview":
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply an attachment identifier.") }
                        result = ["base64": try mediaLibrary.preview(id: id)]
                    case "media.read":
                        guard Set(params.keys) == ["id", "offset", "length"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply an attachment read range.") }
                        result = try mediaLibrary.read(id: id, offset: integer("offset", in: params), length: integer("length", in: params))
                    default:
                        guard Set(params.keys) == ["id"], let id = params["id"] as? String else { throw ServiceError("invalid", "Supply an attachment identifier.") }
                        visualJobs.cancelAsset(id: id)
                        speechJobs.cancelAsset(id: id)
                        try mediaLibrary.delete(id: id); result = ["deleted": true]
                    }
                    replyHandler(["version": 1, "requestId": requestID, "result": result], nil)
                } catch {
                    let failure = error as? ServiceError ?? ServiceError("resource", "Could not read this resource.")
                    replyHandler(["version": 1, "requestId": requestID, "error": ["code": failure.code, "message": failure.message, "retryable": false]], nil)
                }
            }
            return
        }
        replyHandler(dispatcher.handle(message.body), nil)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.targetFrame?.isMainFrame == true && trusted(navigationAction.request.url) ? .allow : .cancel)
    }
}
#if os(macOS)
struct WebJournal: NSViewRepresentable {
    let failed: (String) -> Void
    func makeCoordinator() -> Holder { Holder() }
    func makeNSView(context: Context) -> WKWebView { build(holder: context.coordinator) }
    func updateNSView(_ view: WKWebView, context: Context) {}
    private func build(holder: Holder) -> WKWebView { makeJournal(holder: holder, failed: failed) }
}
#else
struct WebJournal: UIViewRepresentable {
    let failed: (String) -> Void
    func makeCoordinator() -> Holder { Holder() }
    func makeUIView(context: Context) -> WKWebView { makeJournal(holder: context.coordinator, failed: failed) }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#endif
final class Holder { var bridge: Bridge? }
func makeJournal(holder: Holder, failed: @escaping (String) -> Void) -> WKWebView {
    let config = WKWebViewConfiguration()
    do {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("WebAssets"), FileManager.default.fileExists(atPath: root.appendingPathComponent("index.html").path) else { throw ServiceError("assets", "Bundle the React interface with scripts/package-mac.sh.") }
        let args = ProcessInfo.processInfo.arguments
        let vault: URL
        if let index = args.firstIndex(of: "--vault"), args.indices.contains(index+1) { vault = URL(fileURLWithPath: args[index+1], isDirectory: true) }
        else if let development = Bundle.main.object(forInfoDictionaryKey: "MemoryCatcherDevelopmentVault") as? String { vault = URL(fileURLWithPath: development, isDirectory: true) }
        else { vault = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("MemoryCatcher3", isDirectory: true) }
        let bridge = try Bridge(root: root, vault: vault, failed: failed); holder.bridge = bridge
        config.websiteDataStore = .nonPersistent()
        config.userContentController.addScriptMessageHandler(bridge, contentWorld: .page, name: "journal")
        let web = WKWebView(frame: .zero, configuration: config); web.navigationDelegate = bridge; web.uiDelegate = bridge
        web.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
        return web
    } catch { DispatchQueue.main.async { failed(error.localizedDescription) }; return WKWebView(frame: .zero, configuration: config) }
}
