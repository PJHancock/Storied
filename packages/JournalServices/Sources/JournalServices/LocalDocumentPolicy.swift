import Foundation

/// Only the bundled document in the main frame may call native journal methods.
public struct LocalDocumentPolicy {
    private let root: URL
    public init(root: URL) { self.root = root.resolvingSymlinksInPath().standardizedFileURL }
    public func contains(_ url: URL?) -> Bool {
        guard let url, url.isFileURL else { return false }
        return url.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(root.path + "/")
    }
    public func permits(frame: URL?, document: URL?, isMainFrame: Bool) -> Bool {
        isMainFrame && contains(frame) && contains(document)
    }
}
