// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RunPlan",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "RunPlan",
            targets: ["RunPlan"]
        ),
    ],
    dependencies: [
        .package(path: "RunCore"),
    ],
    targets: [
        .target(
            name: "RunPlan",
            dependencies: [
                .product(name: "RunCore", package: "RunCore"),
            ],
            resources: [
                .copy("Resources/beep.wav"),
                .copy("Resources/silence.wav"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
