// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RunCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RunCore", targets: ["RunCore"]),
    ],
    targets: [
        .target(name: "RunCore"),
        .testTarget(name: "RunCoreTests", dependencies: ["RunCore"]),
    ]
)
