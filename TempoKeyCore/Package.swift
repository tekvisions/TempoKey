// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TempoKeyCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TempoKeyCore", targets: ["TempoKeyCore"]),
        .executable(name: "tempokey-benchmark", targets: ["TempoKeyBenchmark"]),
    ],
    targets: [
        .target(
            name: "TempoKeyCore",
            swiftSettings: [
                // Always compile the DSP-heavy core with optimizations, even inside a Debug
                // app build, so analysis stays fast (~40x vs -Onone) with identical behaviour.
                // Permitted because this is a local path dependency, not a versioned one.
                .unsafeFlags(["-O"]),
            ]
        ),
        .executableTarget(name: "TempoKeyBenchmark", dependencies: ["TempoKeyCore"]),
        .testTarget(name: "TempoKeyCoreTests", dependencies: ["TempoKeyCore"]),
    ]
)
