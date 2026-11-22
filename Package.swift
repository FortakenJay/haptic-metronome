// swift-tools-version:5.9
// Only for tests. The watch apps are built from Tactus.xcodeproj; this package compiles the same
// platform-free files on a Mac so `swift test` runs without a watch or a simulator:
//   Core/     tempo, beat clock, meters (both apps)
//   LabCore/  onset detection and timing analysis (Tactus Lab)
import PackageDescription

let package = Package(
    name: "TactusCore",
    platforms: [.macOS(.v13), .watchOS(.v10)],
    targets: [
        .target(name: "TactusCore", path: "Core"),
        .target(name: "LabCore", path: "LabCore"),
        .testTarget(name: "TactusCoreTests", dependencies: ["TactusCore"], path: "Tests/TactusCoreTests"),
        .testTarget(name: "LabCoreTests", dependencies: ["LabCore"], path: "Tests/LabCoreTests"),
    ]
)
