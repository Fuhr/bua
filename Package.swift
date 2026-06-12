// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bua",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Bua",
            path: "Sources/Bua"
        )
    ]
)
