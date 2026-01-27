// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NotificationIntelligence",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "NotificationIntelligence",
            targets: ["NotificationIntelligence"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NotificationIntelligence",
            dependencies: [],
            path: "Sources/NotificationIntelligence"
        ),
        .testTarget(
            name: "NotificationIntelligenceTests",
            dependencies: ["NotificationIntelligence"],
            path: "Tests/NotificationIntelligenceTests",
            resources: [
                .copy("test-vectors.json")
            ]
        ),
    ]
)
