// swift-tools-version:5.9
// Only for tests. The watch app is built from Tactus.xcodeproj; this package compiles the same
// platform-free files in Core/ on a Mac so `swift test` runs without a watch or a simulator.
import PackageDescription

let package = Package(
    name: "TactusCore",
    targets: [
        .target(name: "TactusCore", path: "Core"),
        .testTarget(name: "TactusCoreTests", dependencies: ["TactusCore"], path: "Tests/TactusCoreTests"),
    ]
)
