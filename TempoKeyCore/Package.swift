// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TempoKeyCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TempoKeyCore", targets: ["TempoKeyCore"]),
    ],
    targets: [
        .target(name: "TempoKeyCore"),
        .testTarget(name: "TempoKeyCoreTests", dependencies: ["TempoKeyCore"]),
    ]
)
