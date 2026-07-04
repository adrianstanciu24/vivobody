// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VivoKit",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        .library(name: "VivoKit", targets: ["VivoKit"]),
    ],
    targets: [
        .target(
            name: "VivoKit",
            path: "Sources/VivoKit"
        ),
    ]
)
