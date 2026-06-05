import Foundation

/// Locates the [W3C rdf-canon test suite](https://github.com/w3c/rdf-canon)
/// on disk.
///
/// The suite is checked in as a git submodule at
/// `Tests/RDFCanonizeTests/rdf-canon`. The path is resolved at compile
/// time via `#filePath`, which works for `swift test` runs on the same
/// machine that compiled the tests (the standard local + CI flow).
///
/// If the submodule has not been initialized
/// (`git submodule update --init`), `manifestURL` returns a non-existent
/// path and the smoke tests surface a clear failure.
enum SuiteLocator {
    /// Absolute path to `Tests/RDFCanonizeTests/rdf-canon/tests/`.
    static let testsDirectory: URL = {
        let thisFile = URL(fileURLWithPath: #filePath)
        // thisFile: .../Tests/RDFCanonizeTests/W3CSuite/SuiteLocator.swift
        return thisFile
            .deletingLastPathComponent()              // W3CSuite
            .deletingLastPathComponent()              // RDFCanonizeTests
            .appendingPathComponent("rdf-canon")
            .appendingPathComponent("tests")
    }()

    /// Path to the suite's top-level manifest.
    static var manifestURL: URL {
        testsDirectory.appendingPathComponent("manifest.jsonld")
    }

    /// Resolve a manifest-relative fixture path (e.g. `"rdfc10/test001-in.nq"`)
    /// against the suite's `tests/` root.
    static func fixtureURL(_ relativePath: String) -> URL {
        testsDirectory.appendingPathComponent(relativePath)
    }
}
