import Foundation
import Testing
@testable import JournalServices

@Suite struct JournalBackupTests {
    private func folder() throws -> URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-backup-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true);return url
    }
    @Test func backupRestoresJournalMediaDraftAndPageEdits() throws {
        let root=try folder();defer{try? FileManager.default.removeItem(at:root)}
        let vault=root.appendingPathComponent("vault"),destination=root.appendingPathComponent("backups"),restores=root.appendingPathComponent("restores")
        try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:restores,withIntermediateDirectories:true)
        let store=try JournalStore(directory:vault),library=try MediaLibrary(vault:vault,store:store)
        let day="2026-11-16",id=UUID().uuidString
        _ = try store.save(id:UUID().uuidString,day:day,body:"Synthetic writing",timezone:"UTC",allowsAI:true,expectedRevision:nil)
        try store.saveDraft(day:day,body:"Synthetic unsaved draft")
        _ = try store.savePageText(weekOf:"2026-11-15",fields:["week.subtitle":"Synthetic title","day.2026-11-16.style":"ticket"],expectedRevision:0)
        try store.setResourceEnabled("photos",enabled:true)
        let bytes=Data((0..<256).map(UInt8.init)),preview=Data([0xff,0xd8,0xff,0xd9])
        let upload=try library.begin(id:id,day:day,filename:"synthetic.jpg",mimeType:"image/jpeg",byteCount:bytes.count,previewBase64:preview.base64EncodedString())
        _ = try library.append(uploadID:upload,chunkIndex:0,base64:bytes.base64EncodedString());_ = try library.finish(uploadID:upload)
        let backup=try JournalBackup.create(store:store,vault:vault,destinationParent:destination)
        #expect(backup.mediaCount == 1)
        let restored=try JournalBackup.restore(backup:backup.url,destinationParent:restores)
        try JournalBackup.validateRestored(restored.url)
        let copy=try JournalStore(directory:restored.url)
        #expect(try copy.entries(day:day).first?.body == "Synthetic writing")
        #expect(try copy.draft(day:day) == "Synthetic unsaved draft")
        #expect(try copy.pageText(weekOf:"2026-11-15").fields["day.2026-11-16.style"] == "ticket")
        #expect(try copy.resourceEnabled("photos") == false)
        #expect(try Data(contentsOf:restored.url.appendingPathComponent("media/"+id+".bin")) == bytes)
        #expect(try Data(contentsOf:restored.url.appendingPathComponent("media/"+id+".preview.jpg")) == preview)
        #expect(try store.entries(day:day).first?.body == "Synthetic writing")
        #expect(try store.resourceEnabled("photos") == true)
    }
    @Test func damagedMediaAndMissingFilesFailWithoutRestoring() throws {
        let root=try folder();defer{try? FileManager.default.removeItem(at:root)}
        let vault=root.appendingPathComponent("vault"),dest=root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at:dest,withIntermediateDirectories:true)
        let store=try JournalStore(directory:vault),library=try MediaLibrary(vault:vault,store:store),id=UUID().uuidString,bytes=Data("original".utf8)
        let upload=try library.begin(id:id,day:"2026-11-16",filename:"photo.jpg",mimeType:"image/jpeg",byteCount:bytes.count,previewBase64:nil)
        _ = try library.append(uploadID:upload,chunkIndex:0,base64:bytes.base64EncodedString());_ = try library.finish(uploadID:upload)
        let backup=try JournalBackup.create(store:store,vault:vault,destinationParent:dest)
        try Data("tampered".utf8).write(to:backup.url.appendingPathComponent("media/"+id+".bin"))
        #expect(throws:ServiceError.self) { try JournalBackup.restore(backup:backup.url,destinationParent:dest) }
        let remaining=try FileManager.default.contentsOfDirectory(atPath:dest.path)
        #expect(remaining.count == 1)
        #expect(try Data(contentsOf:vault.appendingPathComponent("media/"+id+".bin")) == bytes)
        try FileManager.default.removeItem(at:vault.appendingPathComponent("media/"+id+".bin"))
        #expect(throws:Error.self) { try JournalBackup.create(store:store,vault:vault,destinationParent:dest) }
        #expect(try FileManager.default.contentsOfDirectory(atPath:dest.path).count == 1)
    }
    @Test func invalidManifestPathAndNestedDestinationAreRejected() throws {
        let root=try folder();defer{try? FileManager.default.removeItem(at:root)}
        let vault=root.appendingPathComponent("vault"),dest=root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at:dest,withIntermediateDirectories:true)
        let store=try JournalStore(directory:vault)
        let backup=try JournalBackup.create(store:store,vault:vault,destinationParent:dest)
        #expect(throws:ServiceError.self) { try JournalBackup.create(store:store,vault:vault,destinationParent:vault) }
        #expect(throws:ServiceError.self) { try JournalBackup.restore(backup:backup.url,destinationParent:backup.url) }
        let manifest=backup.url.appendingPathComponent("manifest.json")
        var obj=try #require(try JSONSerialization.jsonObject(with:Data(contentsOf:manifest)) as? [String:Any])
        var files=try #require(obj["files"] as? [[String:Any]])
        files.append(["name":"../escape","bytes":0,"sha256":String(repeating:"0",count:64)])
        obj["files"]=files
        try JSONSerialization.data(withJSONObject:obj).write(to:manifest)
        #expect(throws:ServiceError.self) { try JournalBackup.restore(backup:backup.url,destinationParent:dest) }
        #expect(try FileManager.default.contentsOfDirectory(atPath:dest.path).count == 1)
    }
}
