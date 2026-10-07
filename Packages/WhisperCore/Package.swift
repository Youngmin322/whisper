// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WhisperCore",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "WhisperCore",
            targets: ["WhisperCore", "WhisperDesignSystem"]
        ),
        .library(
            name: "WhisperDesignSystem",
            targets: ["WhisperDesignSystem"]
        )
    ],
    targets: [
        .target( // ../Sources/WhisperCore
            name: "WhisperCore"
               ),
        .target(
            name: "WhisperDesignSystem",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WhisperCoreTests", // ../Tests/WhisperCoreTests
            dependencies: ["WhisperCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
