// swift-tools-version: 6.1
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
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.5.0"),
    ],
    targets: [
        .target(
            name: "RDFCanonize",
            dependencies: [.product(name: "Crypto", package: "swift-crypto")]
        ),
        .executableTarget(
            name: "RDFCanonizeBench",
            dependencies: ["RDFCanonize"],
            path: "Sources/RDFCanonizeBench"
        ),
        .testTarget(
            name: "RDFCanonizeTests",
            dependencies: ["RDFCanonize"],
            // The W3C rdf-canon conformance suite is a git submodule.
            // Fixtures are read from disk at runtime via #filePath, not
            // bundled as resources, so SPM should ignore the directory.
            exclude: ["rdf-canon"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
