// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-rdf-canonize",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "swift-rdf-canonize",
            targets: ["swift-rdf-canonize"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "swift-rdf-canonize"
        ),
        .testTarget(
            name: "swift-rdf-canonizeTests",
            dependencies: ["swift-rdf-canonize"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
