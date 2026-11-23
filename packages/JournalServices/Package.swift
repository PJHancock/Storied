// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "JournalServices", platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "JournalServices", targets: ["JournalServices"])],
    targets: [.systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "JournalServices", dependencies: ["CSQLite"]),
        .testTarget(name: "JournalServicesTests", dependencies: ["JournalServices", "CSQLite"])],
    swiftLanguageModes: [.v5])
