// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Konus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Konus",
            path: "Sources/Konus",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
    ]
)
