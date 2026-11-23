import Foundation
import CoreFoundation
import NaturalLanguage

public final class Dispatcher {
    private let store: JournalStore
    private let semanticIndex: LocalSemanticIndex
    public init(store: JournalStore, semanticIndex: LocalSemanticIndex? = nil) { self.store = store; self.semanticIndex = semanticIndex ?? LocalSemanticIndex(store: store) }
    public func handle(_ object: Any) -> [String: Any] {
        let input = object as? [String: Any] ?? [:]
        let requestID = input["requestId"] as? String ?? "invalid"
        do {
            guard let version = input["version"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(), version.intValue == 1, version.doubleValue == 1,
                  UUID(uuidString: requestID) != nil, let method = input["method"] as? String,
                  let params = input["params"] as? [String: Any],
                  let bytes = try? JSONSerialization.data(withJSONObject: input), bytes.count <= 120_000,
                  Set(input.keys) == ["version", "requestId", "method", "params"] else { throw ServiceError("protocol", "Invalid bridge request or version.") }
            func text(_ key: String) throws -> String { guard let s = params[key] as? String else { throw ServiceError("invalid", "Missing " + key) }; return s }
            func revision() throws -> Int {
                guard let n = params["expectedRevision"] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.rounded() == n.doubleValue, n.intValue >= 1 else { throw ServiceError("invalid", "Supply a valid revision.") }; return n.intValue
            }
            func keys(_ allowed: Set<String>) throws { guard Set(params.keys) == allowed else { throw ServiceError("invalid", "Unexpected or missing parameters.") } }
            func json<T: Encodable>(_ value: T) throws -> Any { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) }
            let result: Any
            switch method {
            case "journal.pageText.get":
                try keys(["weekOf"]); result = try json(store.pageText(weekOf: text("weekOf")))
            case "journal.pageText.save":
                try keys(["weekOf", "fields", "expectedRevision"])
                guard let fields = params["fields"] as? [String: String], let revision = params["expectedRevision"] as? NSNumber,
                      CFGetTypeID(revision) != CFBooleanGetTypeID(), revision.doubleValue.rounded() == revision.doubleValue, revision.intValue >= 0 else { throw ServiceError("invalid", "Supply valid page text and revision.") }
                result = try json(store.savePageText(weekOf: text("weekOf"), fields: fields, expectedRevision: revision.intValue))
            case "context.guidance.get":
                try keys([]); result = ["text": try store.summaryGuidance()]
            case "context.guidance.save":
                try keys(["text"]); result = ["text": try store.saveSummaryGuidance(text("text"))]
            case "context.items.list":
                try keys([]); result = try json(store.journalContextItems())
            case "context.item.create":
                try keys(["id", "kind", "title", "aliases", "details"])
                result = try json(store.saveJournalContextItem(id: text("id"), kind: text("kind"), title: text("title"), aliases: text("aliases"), details: text("details"), expectedRevision: nil))
            case "context.item.update":
                try keys(["id", "kind", "title", "aliases", "details", "expectedRevision"])
                result = try json(store.saveJournalContextItem(id: text("id"), kind: text("kind"), title: text("title"), aliases: text("aliases"), details: text("details"), expectedRevision: revision()))
            case "context.item.delete":
                try keys(["id", "expectedRevision"]); try store.deleteJournalContextItem(id: text("id"), expectedRevision: revision()); result = ["deleted": true]
            case "context.day.list":
                try keys(["day"]); result = try json(store.dayJournalContextItems(day: text("day")))
            case "context.day.set":
                try keys(["day", "id", "linked"])
                guard let linked = params["linked"] as? NSNumber, CFGetTypeID(linked) == CFBooleanGetTypeID() else { throw ServiceError("invalid", "Supply whether this context should be linked to the day.") }
                try store.setDayJournalContext(day: text("day"), contextID: text("id"), linked: linked.boolValue); result = ["linked": linked.boolValue]
            case "search.query":
                try keys(["query", "scope"])
                let scope = try text("scope")
                guard ["all", "visual", "other"].contains(scope) else { throw ServiceError("invalid", "Choose a supported search scope.") }
                let response = try semanticIndex.search(text("query"), scope: scope)
                result = ["hits": try json(response.hits), "semanticAvailable": response.semanticAvailable] as [String: Any]
            case "system.capabilities":
                try keys([])
                result = ["storage": "native-sqlite", "contractVersion": 1, "media": true, "photos": true, "calendar": true, "weather": false, "ai": NLEmbedding.sentenceEmbedding(for: .english) != nil, "crossDeviceSync": ["provider": "CloudKit", "state": "not-configured", "message": "CloudKit sync is not active. This build has no registered CloudKit container or iCloud signing entitlements."], "message": "Semantic embeddings and Vision labels/OCR run on device. Apple Intelligence can add image descriptions on supported systems. Optional OpenAI summaries and uploaded-media descriptions can be enabled independently in Settings."] as [String: Any]
            case "journal.listDays":
                try keys([])
                var counts = Dictionary(grouping: try store.entries(), by: \.day).mapValues(\.count)
                for attachment in try store.mediaAssets() { counts[attachment.day, default: 0] += 1 }
                result = counts.map { ["day": $0.key, "count": $0.value] as [String: Any] }.sorted { ($0["day"] as! String) > ($1["day"] as! String) }
            case "journal.getDay":
                try keys(["day"]); let day = try text("day"); try JournalStore.validateDay(day)
                result = try json(store.entries(day: day))
            case "journal.createEntry", "journal.updateEntry":
                try keys(method == "journal.createEntry" ? ["id", "day", "body", "timezone", "allowsAI"] : ["id", "day", "body", "timezone", "allowsAI", "expectedRevision"])
                guard let flag = params["allowsAI"] as? NSNumber, CFGetTypeID(flag) == CFBooleanGetTypeID() else { throw ServiceError("invalid", "Supply AI preference.") }
                let saved = try store.save(id: text("id"), day: text("day"), body: text("body"), timezone: text("timezone"), allowsAI: flag.boolValue, expectedRevision: method == "journal.updateEntry" ? revision() : nil)
                if saved.allowsAI { _ = try semanticIndex.index(id: saved.id, type: "text", revision: saved.revision, text: saved.body) }
                result = try json(saved)
            case "journal.deleteEntry":
                try keys(["id", "expectedRevision"]); try store.delete(id: text("id"), expectedRevision: revision()); result = ["deleted": true]
            case "draft.get": try keys(["day"]); result = ["body": try store.draft(day: text("day"))]
            case "draft.save": try keys(["day", "body"]); try store.saveDraft(day: text("day"), body: text("body")); result = ["saved": true]
            case "journal.getSummaryOverride":
                try keys(["day"])
                let value = try store.daySummaryOverride(day: text("day"))
                result = try value.map { try json($0) } ?? NSNull()
            case "journal.saveSummaryOverride":
                try keys(["day", "title", "detail"])
                result = try json(store.saveDaySummaryOverride(day: text("day"), title: text("title"), detail: text("detail")))
            case "journal.clearSummaryOverride":
                try keys(["day"]); try store.clearDaySummaryOverride(day: text("day")); result = ["cleared": true]
            case "journal.getWeeklySummaryOverride":
                try keys(["weekOf"])
                let value = try store.weeklySummaryOverride(weekOf: text("weekOf"))
                result = try value.map { try json($0) } ?? NSNull()
            case "journal.saveWeeklySummaryOverride":
                try keys(["weekOf", "title", "detail"])
                result = try json(store.saveWeeklySummaryOverride(weekOf: text("weekOf"), title: text("title"), detail: text("detail")))
            case "journal.clearWeeklySummaryOverride":
                try keys(["weekOf"]); try store.clearWeeklySummaryOverride(weekOf: text("weekOf")); result = ["cleared": true]
            case "journal.getDayWeatherLocation":
                try keys(["day"])
                let value = try store.dayWeatherLocation(day: text("day"))
                result = try value.map { try json($0) } ?? NSNull()
            case "journal.saveDayWeatherLocation":
                try keys(["day", "location"])
                guard let location = params["location"] as? [String: Any], Set(location.keys) == ["name", "latitude", "longitude"],
                      let name = location["name"] as? String,
                      let latitudeValue = location["latitude"] as? NSNumber, CFGetTypeID(latitudeValue) != CFBooleanGetTypeID(),
                      let longitudeValue = location["longitude"] as? NSNumber, CFGetTypeID(longitudeValue) != CFBooleanGetTypeID() else { throw ServiceError("invalid", "Supply a valid city for this day.") }
                result = try json(store.saveDayWeatherLocation(day: text("day"), name: name, latitude: latitudeValue.doubleValue, longitude: longitudeValue.doubleValue))
            case "journal.clearDayWeatherLocation":
                try keys(["day"]); try store.clearDayWeatherLocation(day: text("day")); result = ["cleared": true]
            case "journal.hiddenAnniversaryDays":
                try keys([]); result = try store.hiddenAnniversaryDays()
            case "journal.setAnniversaryHidden":
                try keys(["day", "hidden"])
                guard let hidden = params["hidden"] as? NSNumber, CFGetTypeID(hidden) == CFBooleanGetTypeID() else { throw ServiceError("invalid", "Supply a valid hide or restore choice.") }
                result = try store.setAnniversaryHidden(day: text("day"), hidden: hidden.boolValue)
            case "journal.monthlySynopsis.get":
                try keys(["month", "fingerprint"])
                let value = try store.monthlySynopsis(month: text("month"), fingerprint: text("fingerprint"))
                result = try value.map { try json($0) } ?? NSNull()
            case "journal.monthlySynopsis.save":
                try keys(["month", "fingerprint", "bullets"])
                guard let rawBullets = params["bullets"] as? [[String: Any]], rawBullets.allSatisfy({ Set($0.keys) == ["day", "text"] && $0["day"] is String && $0["text"] is String }) else { throw ServiceError("invalid", "Monthly synopsis bullets are invalid.") }
                let bullets = rawBullets.compactMap { item -> MonthlySynopsisBullet? in
                    guard let day = item["day"] as? String, let text = item["text"] as? String else { return nil }
                    return MonthlySynopsisBullet(day: day, text: text)
                }
                result = try json(store.saveMonthlySynopsis(month: text("month"), fingerprint: text("fingerprint"), bullets: bullets))
            default: throw ServiceError("unknownMethod", "This capability is not implemented.")
            }
            return ["version": 1, "requestId": requestID, "result": result]
        } catch {
            let failure = error as? ServiceError ?? ServiceError("storage", "The journal operation could not finish.")
            return ["version": 1, "requestId": requestID, "error": ["code": failure.code, "message": failure.message, "retryable": failure.code == "storage"]]
        }
    }
}
