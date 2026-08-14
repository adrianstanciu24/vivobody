// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VivoKit",
    platforms: [
        .iOS("26.0"),
        .macOS("14.0"),
    ],
    products: [
        .library(name: "VivoKit", targets: ["VivoKit"]),
    ],
    targets: [
        .target(
            name: "VivoKitSnapshotCore",
            path: "Sources/VivoKit",
            exclude: [
                "DesignTokens.swift",
                "SignatureEmblemTuning.swift",
                "SnapshotExports.swift",
                "WeightFormatter+Shared.swift",
                "WidgetIntents.swift",
                "WorkoutActivityAttributes.swift",
            ],
            sources: ["WidgetData.swift"]
        ),
        .target(
            name: "VivoKit",
            dependencies: ["VivoKitSnapshotCore"],
            path: "Sources/VivoKit",
            exclude: ["WidgetData.swift"]
        ),
        .testTarget(
            name: "VivoKitTests",
            dependencies: ["VivoKitSnapshotCore"],
            path: "Tests/VivoKitTests"
        ),
    ]
)
