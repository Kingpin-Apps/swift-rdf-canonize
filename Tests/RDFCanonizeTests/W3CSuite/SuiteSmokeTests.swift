import Testing
import Foundation

/// Verifies the W3C rdf-canon test suite is wired up and loadable.
///
/// These tests don't exercise the canonicalization algorithm — they
/// only prove the submodule is initialized and the manifest decoder
/// matches the suite's schema. Conformance tests live in
/// `ConformanceTests.swift`.
@Suite("W3C rdf-canon suite wiring")
struct SuiteSmokeTests {

    @Test("Submodule has been initialized")
    func submoduleInitialized() {
        let path = SuiteLocator.testsDirectory.path
        #expect(
            FileManager.default.fileExists(atPath: path),
            """
            W3C rdf-canon test suite not found at \(path).
            Run `git submodule update --init` and re-run the tests.
            """
        )
    }

    /// Lower bound on entry count for the pinned submodule commit.
    /// "At least N" lets the suite grow without churn; shrinking past
    /// this means something we should look at.
    @Test("Manifest loads with the expected entries")
    func manifestLoads() throws {
        let manifest = try TestManifest.load()
        #expect(manifest.entries.count >= 80,
                "Manifest has \(manifest.entries.count) entries, expected at least 80")
    }

    @Test("Every entry has a recognized test type")
    func everyEntryHasKnownKind() throws {
        let manifest = try TestManifest.load()
        for entry in manifest.entries {
            switch entry.kind {
            case .eval, .map, .negative: break
            case .unknown(let t):
                Issue.record("Entry \(entry.id) has unknown type \(t)")
            }
        }
    }

    @Test("Positive entries carry a result path; negative entries do not")
    func resultPathMatchesKind() throws {
        let manifest = try TestManifest.load()
        for entry in manifest.entries {
            switch entry.kind {
            case .eval, .map:
                #expect(entry.result != nil,
                        "Positive entry \(entry.id) missing result path")
            case .negative:
                #expect(entry.result == nil,
                        "Negative entry \(entry.id) unexpectedly has a result path")
            case .unknown:
                break
            }
        }
    }
}
