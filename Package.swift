// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AmosTTS",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "AmosTTS",
            targets: ["AmosTTS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/wyk111wyk/AmosBase.git", branch: "main")
    ],
    targets: [
        .target(
            name: "AmosTTS",
            dependencies: ["AmosBase", "MSTTSFramework"],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .binaryTarget(
            name: "MSTTSFramework",
            path: "./Sources/Frameworks/MicrosoftCognitiveServicesSpeech.xcframework"
        )
    ]
)
