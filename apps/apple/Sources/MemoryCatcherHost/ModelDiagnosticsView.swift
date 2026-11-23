import SwiftUI
import JournalServices

/// Enabled only in the isolated review bundle's Info.plist; never opens a journal vault.
struct ModelDiagnosticsView: View {
    @State private var report: AppleModelDiagnosticReport?
    @State private var running = false
    @State private var work: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Apple Intelligence diagnostic").font(.title)
            Text("Synthetic test only. No journal, Photos, Calendar, microphone or camera access.")
            Button(running ? "Testing…" : "Run synthetic model test") {
                running = true; report = nil
                work = Task { @MainActor in report = await AppleModelDiagnostics.run(); running = false }
            }.disabled(running)
            if running { Button("Cancel test") { work?.cancel(); running = false } }
            if let report {
                Text("Availability: \(report.available ? "available" : "unavailable")")
                Text("Minimal plain generation: \(report.plain)")
                Text("Structured summary: \(report.synthesis)")
                Text(report.detail).textSelection(.enabled)
            }
            Spacer()
        }.padding(30).frame(minWidth: 600, minHeight: 420)
            .onDisappear { work?.cancel() }
    }
}
