// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MemoryCatcherHost", platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [.package(path: "../../packages/JournalServices")],
    targets: [.executableTarget(name: "MemoryCatcherHost", dependencies: [.product(name: "JournalServices", package: "JournalServices")])], swiftLanguageModes: [.v5])
