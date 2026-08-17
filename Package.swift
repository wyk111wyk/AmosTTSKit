// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AmosTTSKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "AmosTTSKit",
            targets: ["AmosTTSKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/wyk111wyk/AmosBase.git", branch: "main")
    ],
    targets: [
        .target(
            name: "AmosTTSKit",
            dependencies: ["AmosBase", "MSTTSFramework"],
            path: "Sources",
            exclude: ["Frameworks"],
            resources: [
                .process("Resources")
            ]
        ),
        .binaryTarget(
            name: "MSTTSFramework",
            path: "./Sources/Frameworks/MicrosoftCognitiveServicesSpeech.xcframework"
        ),
        .testTarget(
            name: "AmosTTSKitTests",
            dependencies: ["AmosTTSKit"],
            path: "Tests/AmosTTSKitTests"
        )
    ]
)
