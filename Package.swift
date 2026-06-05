// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RDFCanonize",
    platforms: [
        .iOS(.v14),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "RDFCanonize",
            targets: ["RDFCanonize"]
        ),
    ],
    targets: [
        .target(
            name: "RDFCanonize"
        ),
        .testTarget(
            name: "RDFCanonizeTests",
            dependencies: ["RDFCanonize"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
