import Foundation
import Photos
import EventKit
import ImageIO
import JournalServices
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class ResourceConnections {
    private let preferences = UserDefaults.standard
    private let store: JournalStore
    private let eventStore = EKEventStore()
    private let photoKey = "resource.photos.enabled"
    private var visualCache: [String: (Date?, String?)] = [:]
    private let calendarKey = "resource.calendar.enabled"

    init(store: JournalStore) throws {
        self.store = store
        for (name, key) in [("photos", photoKey), ("calendar", calendarKey)] where try store.resourceEnabled(name) == nil {
            if let oldValue = preferences.object(forKey: key) as? Bool { try store.setResourceEnabled(name, enabled: oldValue) }
        }
    }

    func status() throws -> [String: Any] {
        let photos = photoAccess()
        let calendar = calendarAccess()
        return ["photos": ["enabled": try store.resourceEnabled("photos") == true && (photos == "authorized" || photos == "limited"), "access": photos],
                "calendar": ["enabled": try store.resourceEnabled("calendar") == true && (calendar == "fullAccess" || calendar == "authorized"), "access": calendar]]
    }

    func setEnabled(resource: String, enabled: Bool) async throws -> [String: Any] {
        guard resource == "photos" || resource == "calendar" else { throw ServiceError("invalid", "Unknown resource connection.") }
        let key = resource == "photos" ? photoKey : calendarKey
        if !enabled {
            try store.setResourceEnabled(resource, enabled: false)
            preferences.set(false, forKey: key)
            return try status()
        }
        let granted: Bool
        if resource == "photos" {
            let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            let result = current == .notDetermined ? await PHPhotoLibrary.requestAuthorization(for: .readWrite) : current
            granted = result == .authorized || result == .limited
        } else {
            let current = EKEventStore.authorizationStatus(for: .event)
            if current == .notDetermined {
                granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
            } else {
                granted = current == .fullAccess || current == .authorized
            }
        }
        try store.setResourceEnabled(resource, enabled: granted)
        preferences.set(granted, forKey: key)
        return try status()
    }

    func day(_ rawDay: String, previewLimit: Int = 12) async throws -> [String: Any] {
        let interval = try dayInterval(rawDay)
        guard (0...12).contains(previewLimit) else { throw ServiceError("invalid", "Request at most 12 Photos previews at a time.") }
        let photosAreConnected = try store.resourceEnabled("photos") == true && (photoAccess() == "authorized" || photoAccess() == "limited")
        let calendarAreConnected = try store.resourceEnabled("calendar") == true && (calendarAccess() == "fullAccess" || calendarAccess() == "authorized")
        if previewLimit > 0,
           let cache = try store.connectedDayCache(day: rawDay),
           let syncedAt = ISO8601DateFormatter().date(from: cache.syncedAt),
           Date().timeIntervalSince(syncedAt) >= 0,
           Date().timeIntervalSince(syncedAt) < 24 * 60 * 60,
           let raw = decodeCache(cache.payload),
           (raw["previewsIncluded"] as? Bool == true || previewLimit == 1),
           (!photosAreConnected || raw["photosIncluded"] as? Bool == true),
           (!calendarAreConnected || raw["calendarIncluded"] as? Bool == true) {
            return try present(raw, day: rawDay)
        }
        let raw = try await fetchDay(interval: interval, previewLimit: previewLimit)
        if previewLimit > 0 { try save(raw, day: rawDay) }
        return try present(raw, day: rawDay)
    }

    func needsSync(days: [String]) throws -> Bool {
        guard days.count <= 7 else { throw ServiceError("invalid", "Select at most seven days.") }
        let status = try status()
        guard (status["photos"] as? [String: Any])?["enabled"] as? Bool == true || (status["calendar"] as? [String: Any])?["enabled"] as? Bool == true else { return false }
        for day in days {
            _ = try dayInterval(day)
            guard let cache = try store.connectedDayCache(day: day),
                  let date = ISO8601DateFormatter().date(from: cache.syncedAt),
                  Date().timeIntervalSince(date) >= 0, Date().timeIntervalSince(date) < 86400 else { return true }
        }
        return false
    }

    func sync(days: [String]) async throws -> [String: Any] {
        guard !days.isEmpty, days.count <= 7, Set(days).count == days.count else {
            throw ServiceError("invalid", "Sync up to seven distinct journal days at a time.")
        }
        let connections = try status()
        let photosEnabled = (connections["photos"] as? [String: Any])?["enabled"] as? Bool == true
        let calendarEnabled = (connections["calendar"] as? [String: Any])?["enabled"] as? Bool == true
        guard photosEnabled || calendarEnabled else {
            throw ServiceError("notConnected", "Turn on Photos or Calendar in Workshop before syncing.")
        }
        for day in days {
            let interval = try dayInterval(day)
            // Refresh counts and calendar details cheaply. Full previews load only when a day is opened.
            var raw = try await fetchDay(interval: interval, previewLimit: 0)
            if let cache = try store.connectedDayCache(day: day), let previous = decodeCache(cache.payload) {
                raw["photos"] = previous["photos"]
                raw["previewsIncluded"] = previous["previewsIncluded"]
            }
            try save(raw, day: day)
        }
        return ["syncedDays": days.count, "syncedAt": ISO8601DateFormatter().string(from: Date())]
    }

    func syncBatch(day: String, offset: Int) async throws -> [String: Any] {
        guard offset >= 0 else { throw ServiceError("invalid", "Invalid Photos batch.") }
        let interval = try dayInterval(day)
        var raw = try await fetchDay(interval: interval, previewLimit: 0)
        let enabled = raw["photosIncluded"] as? Bool == true
        let previousRaw = try store.connectedDayCache(day: day).flatMap { decodeCache($0.payload) }
        let previousPhotos = previousRaw?["photos"] as? [[String: Any]] ?? []
        let batch = enabled ? await photosForDay(start: interval.start, end: interval.end, limit: 12, offset: offset, reusable: previousPhotos) : (items: [[String: Any]](), totalCount: 0)
        var photos: [[String: Any]] = []
        photos = previousPhotos
        let ids = Set(batch.items.compactMap { $0["id"] as? String })
        photos.removeAll { ids.contains($0["id"] as? String ?? "") }
        photos.append(contentsOf: batch.items)
        if offset + 12 >= batch.totalCount, enabled {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", interval.start as NSDate, interval.end as NSDate)
            let assets = PHAsset.fetchAssets(with: options)
            var currentIDs = Set<String>()
            assets.enumerateObjects { asset, _, _ in currentIDs.insert(asset.localIdentifier) }
            photos.removeAll { !currentIDs.contains($0["id"] as? String ?? "") }
        }
        raw["photos"] = photos
        raw["photoCount"] = batch.totalCount
        let nextOffset = min(offset + 12, batch.totalCount)
        raw["previewsIncluded"] = nextOffset >= batch.totalCount
        try save(raw, day: day)
        return ["nextOffset": nextOffset, "hasMore": nextOffset < batch.totalCount,
                "photoCount": batch.totalCount, "loadedCount": photos.count]
    }

    private func dayInterval(_ rawDay: String) throws -> DateInterval {
        try JournalStore.validateDay(rawDay)
        var journalCalendar = Calendar(identifier: .gregorian)
        journalCalendar.timeZone = .current
        let dateParts = rawDay.split(separator: "-").compactMap { Int($0) }
        guard dateParts.count == 3,
              let date = journalCalendar.date(from: DateComponents(year: dateParts[0], month: dateParts[1], day: dateParts[2])),
              let interval = journalCalendar.dateInterval(of: .day, for: date) else {
            throw ServiceError("invalid", "Supply a valid journal day.")
        }
        return interval
    }

    private func fetchDay(interval: DateInterval, previewLimit: Int = 12) async throws -> [String: Any] {
        var photos: [[String: Any]] = []
        var photoCount = 0
        var events: [[String: Any]] = []
        let photoAccess = photoAccess()
        let calendarAccess = calendarAccess()
        let photosIncluded = try store.resourceEnabled("photos") == true && (photoAccess == "authorized" || photoAccess == "limited")
        let calendarIncluded = try store.resourceEnabled("calendar") == true && (calendarAccess == "fullAccess" || calendarAccess == "authorized")
        if photosIncluded {
            let fetched = await photosForDay(start: interval.start, end: interval.end, limit: previewLimit)
            photos = fetched.items; photoCount = fetched.totalCount
        }
        if calendarIncluded {
            let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
            events = eventStore.events(matching: predicate).map { event in
                ["id": event.eventIdentifier ?? UUID().uuidString,
                 "title": event.title ?? "Untitled event",
                 "start": ISO8601DateFormatter().string(from: event.startDate),
                 "end": ISO8601DateFormatter().string(from: event.endDate),
                 "allDay": event.isAllDay,
                 "location": event.location ?? "",
                 "timeZone": event.timeZone?.identifier ?? TimeZone.current.identifier]
            }
        }
        return ["photos": photos, "photoCount": photoCount, "events": events,
                "photosIncluded": photosIncluded, "calendarIncluded": calendarIncluded,
                "previewsIncluded": previewLimit == 12]
    }

    private func save(_ raw: [String: Any], day: String) throws {
        let data = try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys])
        guard let payload = String(data: data, encoding: .utf8) else {
            throw ServiceError("cache", "Could not encode connected day data.")
        }
        try store.saveConnectedDayCache(day: day, syncedAt: ISO8601DateFormatter().string(from: Date()), payload: payload)
    }

    private func decodeCache(_ payload: String) -> [String: Any]? {
        guard let data = payload.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data),
              let object = value as? [String: Any], object["photos"] is [[String: Any]],
              object["events"] is [[String: Any]], object["photoCount"] is Int,
              object["photosIncluded"] is Bool, object["calendarIncluded"] is Bool,
              object["previewsIncluded"] is Bool else { return nil }
        return object
    }

    private func present(_ raw: [String: Any], day: String) throws -> [String: Any] {
        let photoAccess = photoAccess()
        let calendarAccess = calendarAccess()
        let photosEnabled = try store.resourceEnabled("photos") == true && (photoAccess == "authorized" || photoAccess == "limited")
        let calendarEnabled = try store.resourceEnabled("calendar") == true && (calendarAccess == "fullAccess" || calendarAccess == "authorized")
        let allPhotos = raw["photos"] as? [[String: Any]] ?? []
        let allEvents = raw["events"] as? [[String: Any]] ?? []
        let photos = photosEnabled ? try allPhotos.filter { photo in
            guard let id = photo["id"] as? String else { return false }
            return try !store.contextItemHidden(day: day, source: "photo", itemID: id)
        } : []
        let events = calendarEnabled ? try allEvents.filter { event in
            guard let id = event["id"] as? String else { return false }
            return try !store.contextItemHidden(day: day, source: "calendar", itemID: id)
        } : []
        var headlinePhotoID = try store.headlinePhotoID(day: day)
        if let selected = headlinePhotoID {
            let selectedPhotoHidden = try store.contextItemHidden(day: day, source: "photo", itemID: selected)
            let connectedPhotoAvailable = allPhotos.contains { ($0["id"] as? String) == selected } && !selectedPhotoHidden
            let uploadedPhotoAvailable = try store.mediaAsset(id: selected).map { $0.day == day && $0.kind == "photo" && $0.hasPreview } ?? false
            if !connectedPhotoAvailable && !uploadedPhotoAvailable {
                try store.saveHeadlinePhotoID(day: day, photoID: nil)
                headlinePhotoID = nil
            }
        }
        return ["photos": photos,
                "photoCount": photosEnabled ? (raw["photoCount"] as? Int ?? 0) : 0,
                "events": events,
                "photosAccess": photoAccess,
                "calendarAccess": calendarAccess,
                "headlinePhotoID": headlinePhotoID as Any? ?? NSNull(),
                "weatherHidden": try store.contextItemHidden(day: day, source: "weather", itemID: day)]
    }

    func setItemHidden(day: String, source: String, id: String, hidden: Bool) throws {
        try store.setContextItemHidden(day: day, source: source, itemID: id, hidden: hidden)
        if source == "photo", hidden, try store.headlinePhotoID(day: day) == id {
            try store.saveHeadlinePhotoID(day: day, photoID: nil)
        }
    }

    func setHeadlinePhoto(day: String, id: String?) throws -> [String: Any] {
        try JournalStore.validateDay(day)
        if let id {
            let connectedPhotoAvailable: Bool
            if let cache = try store.connectedDayCache(day: day), let raw = decodeCache(cache.payload) {
                let photos = raw["photos"] as? [[String: Any]] ?? []
                let isCached = photos.contains { ($0["id"] as? String) == id }
                let isHidden = try store.contextItemHidden(day: day, source: "photo", itemID: id)
                connectedPhotoAvailable = isCached && !isHidden
            } else {
                connectedPhotoAvailable = false
            }
            let uploadedPhotoAvailable = try store.mediaAsset(id: id).map { $0.day == day && $0.kind == "photo" && $0.hasPreview } ?? false
            guard connectedPhotoAvailable || uploadedPhotoAvailable else {
                throw ServiceError("notFound", "That photo is no longer available for this day.")
            }
        }
        try store.saveHeadlinePhotoID(day: day, photoID: id)
        return ["headlinePhotoID": id as Any? ?? NSNull()]
    }

    private func photoAccess() -> String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorized: "authorized"
        case .limited: "limited"
        @unknown default: "unknown"
        }
    }

    private func calendarAccess() -> String {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .fullAccess: "fullAccess"
        case .writeOnly: "writeOnly"
        case .authorized: "authorized"
        @unknown default: "unknown"
        }
    }

    private func photosForDay(start: Date, end: Date, limit: Int, offset: Int = 0, reusable: [[String: Any]] = []) async -> (items: [[String: Any]], totalCount: Int) {
        let countOptions = PHFetchOptions()
        countOptions.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
        let totalCount = PHAsset.fetchAssets(with: countOptions).count
        guard limit > 0 else { return ([], totalCount) }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
        // The daily preview limit should prioritize the photos the user just took.
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = offset + limit
        let assets = PHAsset.fetchAssets(with: options)
        var result: [[String: Any]] = []
        for index in min(offset, assets.count)..<assets.count {
            let asset = assets.object(at: index)
            let version = asset.modificationDate?.timeIntervalSince1970 ?? 0
            if let cached = reusable.first(where: { $0["id"] as? String == asset.localIdentifier && $0["assetVersion"] as? Double == version && $0["favorite"] as? Bool == asset.isFavorite }) {
                result.append(cached); continue
            }
            guard let data = await thumbnailData(for: asset),
                  let date = asset.creationDate else { continue }
            let clues: String?
            if let cached = visualCache[asset.localIdentifier], cached.0 == asset.modificationDate { clues = cached.1 }
            else {
                clues = await Task.detached(priority: .utility) {
                    try? OnDeviceVisualAnalyzer().analyze(imageData: data)
                }.value
                if visualCache.count > 200 { visualCache.removeAll() }
                visualCache[asset.localIdentifier] = (asset.modificationDate, clues)
            }
            result.append(["id": asset.localIdentifier,
                           "assetVersion": version,
                           "analysisText": clues ?? "",
                           "thumbnail": "data:image/jpeg;base64," + data.base64EncodedString(),
                           "createdAt": ISO8601DateFormatter().string(from: date),
                           "favorite": asset.isFavorite,
                           "kind": asset.mediaType == .video ? "video" : "photo"])
        }
        return (result, totalCount)
    }

    private func thumbnailData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true // Allows a small rendition to load from iCloud when needed.
            let gate = PhotoPreviewReply(continuation)
            let requestID = PHImageManager.default().requestImage(for: asset,
                                                  targetSize: CGSize(width: 240, height: 240),
                                                  contentMode: .aspectFit,
                                                  options: options) { image, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                #if os(macOS)
                let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                #else
                let cgImage = image?.cgImage
                #endif
                guard let cgImage else { gate.finish(nil); return }
                let output = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) else {
                    gate.finish(nil); return
                }
                CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary)
                gate.finish(CGImageDestinationFinalize(destination) ? output as Data : nil)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
                if gate.finish(nil) { PHImageManager.default().cancelImageRequest(requestID) }
            }
        }
    }
}

/// PhotoKit can reply late or more than once; resume each request exactly once.
private final class PhotoPreviewReply: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data?, Never>?
    init(_ continuation: CheckedContinuation<Data?, Never>) { self.continuation = continuation }
    @discardableResult func finish(_ data: Data?) -> Bool {
        lock.lock()
        let reply = continuation; continuation = nil
        lock.unlock()
        reply?.resume(returning: data)
        return reply != nil
    }
}
