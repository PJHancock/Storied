import Foundation
import NaturalLanguage

public struct SemanticHit: Codable, Equatable {
    public let id: String
    public let day: String
    public let kind: String
    public let text: String
    public let score: Double
}

/// Uses the OS sentence model only. There is deliberately no remote fallback.
public final class LocalSemanticIndex {
    private let store: JournalStore
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    private let modelName = "NaturalLanguage.sentenceEmbedding.english.v1"

    public init(store: JournalStore) { self.store = store }

    @discardableResult public func index(id: String, type: String, revision: Int, text: String) throws -> Bool {
        guard let embedding else { return false }
        let pieces = text.components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ".!?")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(64)
        let vectors = pieces.compactMap { embedding.vector(for: $0) }
        guard let first = vectors.first, vectors.allSatisfy({ $0.count == first.count }) else { return false }
        let vector = first.indices.map { dimension in vectors.reduce(0.0) { $0 + $1[dimension] } / Double(vectors.count) }
        try store.saveSemanticEmbedding(id: id, type: type, revision: revision, model: modelName, vector: vector)
        return true
    }

    public func search(_ query: String, scope: String = "all", limit: Int = 30) throws -> (hits: [SemanticHit], semanticAvailable: Bool) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return ([], embedding != nil) }
        let entries = try store.entries()
        let media = try store.mediaAssets()
        // Backfill only entries that were explicitly marked for local AI processing.
        if embedding != nil {
            let known = Set(try store.semanticEmbeddings().map { "\($0.id):\($0.revision):\($0.model)" })
            for entry in entries where entry.allowsAI {
                if !known.contains("\(entry.id):\(entry.revision):\(modelName)") { _ = try index(id: entry.id, type: "text", revision: entry.revision, text: entry.body) }
            }
        }
        guard let embedding, let queryVector = embedding.vector(for: query) else {
            let matches = entries.filter { $0.allowsAI && $0.body.localizedCaseInsensitiveContains(query) }.prefix(limit)
            let textHits = scope == "visual" ? [] : matches.map { SemanticHit(id: $0.id, day: $0.day, kind: "text", text: $0.body, score: 0) }
            let mediaHits = media.compactMap { asset -> SemanticHit? in
                guard scope == "all" || (scope == "visual" ? ["photo", "video"].contains(asset.kind) : !["photo", "video"].contains(asset.kind)) else { return nil }
                let content = [asset.transcript, asset.analysisText].compactMap { $0 }.joined(separator: "\n")
                guard asset.allowsAI == true, !content.isEmpty, content.localizedCaseInsensitiveContains(query) else { return nil }
                return SemanticHit(id: asset.id, day: asset.day, kind: asset.kind, text: content, score: 0)
            }
            return (Array((textHits + mediaHits).prefix(limit)), false)
        }
        let current = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let currentMedia = Dictionary(uniqueKeysWithValues: media.map { ($0.id, $0) })
        let indexed = try store.semanticEmbeddings()
        let ranked: [SemanticHit] = indexed.compactMap { record in
            guard record.model == modelName, record.vector.count == queryVector.count else { return nil }
            let score = Self.cosine(queryVector, record.vector)
            if record.type == "text", scope != "visual", let entry = current[record.id], entry.allowsAI, entry.revision == record.revision {
                return SemanticHit(id: entry.id, day: entry.day, kind: "text", text: entry.body, score: score)
            }
            if let asset = currentMedia[record.id], asset.allowsAI == true,
               scope == "all" || (scope == "visual" ? ["photo", "video"].contains(asset.kind) : !["photo", "video"].contains(asset.kind)),
               asset.analysisRevision == record.revision {
                let content = [asset.transcript, asset.analysisText].compactMap { $0 }.joined(separator: "\n")
                if !content.isEmpty { return SemanticHit(id: asset.id, day: asset.day, kind: asset.kind, text: content, score: score) }
            }
            return nil
        }.sorted { $0.score > $1.score }
        return (Array(ranked.prefix(limit)), true)
    }

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        var dot = 0.0, normA = 0.0, normB = 0.0
        for index in a.indices { dot += a[index] * b[index]; normA += a[index] * a[index]; normB += b[index] * b[index] }
        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dot / denominator : 0
    }
}
