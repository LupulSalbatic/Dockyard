// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Dockyard",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "DockyardCore", path: "Sources/DockyardCore"),
        .executableTarget(name: "Dockyard", dependencies: ["DockyardCore"], path: "Sources/Dockyard"),
        .executableTarget(name: "DockyardFolder", dependencies: ["DockyardCore"], path: "Sources/DockyardFolder"),
    ],
    swiftLanguageModes: [.v5]
)
