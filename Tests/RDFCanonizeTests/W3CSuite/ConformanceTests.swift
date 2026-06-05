import Testing
import Foundation
@testable import RDFCanonize

/// Runs the W3C rdf-canon conformance suite as parameterized tests.
///
/// Each manifest entry becomes one test case. Test types:
/// - `RDFC10EvalTest` — canonicalize input, string-compare to expected N-Quads.
/// - `RDFC10MapTest` — canonicalize input, compare the issued blank-node map
///   to the expected JSON (`{ originalId: canonicalId }`, both unprefixed).
/// - `RDFC10NegativeEvalTest` — canonicalization must throw.
///
/// Tests using `SHA384` and the "high" computational-complexity poison
/// graphs are reported as known-unsupported until the implementation
/// catches up. See [.agents/plan.md](../../.agents/plan.md).
@Suite("W3C rdf-canon conformance")
struct ConformanceTests {

    /// Entries that depend on features not yet implemented. Each is
    /// reported as a known-skip rather than a noisy failure so the
    /// baseline number stays meaningful.
    ///
    /// All conformance entries currently pass on this build.
    static let knownUnsupported: Set<String> = []

    /// Inputs whose canonicalization is intractable without a
    /// bounded-iteration safeguard. Now empty — the algorithm raises
    /// `CanonicalizeError.iterationLimitExceeded` for poison graphs
    /// (e.g. test #074's 10-node clique).
    static let knownHangs: Set<String> = []

    @Test(
        "RDFC10 conformance",
        arguments: Self.allEntries()
    )
    func conformance(_ entry: TestEntry) throws {
        if Self.knownHangs.contains(entry.id) {
            // Don't invoke the algorithm at all — it would not return.
            withKnownIssue("\(entry.id): \(entry.name) — needs bounded-iteration safeguard") {
                Issue.record("not run — algorithm requires maxDeepIterations safeguard")
            }
            return
        }
        if Self.knownUnsupported.contains(entry.id) {
            // Skip without failing — the baseline number reflects only
            // tests we expect this build to be able to answer.
            withKnownIssue("\(entry.id): \(entry.name) — known unsupported feature") {
                try Self.run(entry)
            }
            return
        }
        try Self.run(entry)
    }

    /// Single dispatch point — keeps the parameterized test body small
    /// and lets `withKnownIssue` wrap the same call path.
    private static func run(_ entry: TestEntry) throws {
        switch entry.kind {
        case .eval:
            try runEvalTest(entry)
        case .map:
            try runMapTest(entry)
        case .negative:
            try runNegativeTest(entry)
        case .unknown(let t):
            Issue.record("Entry \(entry.id) has unknown type \(t)")
        }
    }

    // MARK: Test runners

    private static func runEvalTest(_ entry: TestEntry) throws {
        guard let resultPath = entry.result else {
            Issue.record("Eval entry \(entry.id) missing result path")
            return
        }
        let input = try loadFixture(entry.action)
        let expected = try loadFixture(resultPath)
        let actual = try RDFCanonize.canonicalize(
            nquads: input,
            hashAlgorithm: hashAlgorithm(for: entry),
            workFactor: workFactor(for: entry)
        )
        #expect(
            actual == expected,
            """
            \(entry.id) (\(entry.name)) — canonicalization mismatch
            --- expected ---
            \(expected)
            --- actual ---
            \(actual)
            """
        )
    }

    private static func runMapTest(_ entry: TestEntry) throws {
        guard let resultPath = entry.result else {
            Issue.record("Map entry \(entry.id) missing result path")
            return
        }
        let input = try loadFixture(entry.action)
        let expectedJSON = try loadFixture(resultPath)
        let expected = try decodeMap(expectedJSON)
        let quads = try RDFCanonize.NQuadsParser.parse(input)
        let raw = try RDFCanonize.Canonicalizer.canonicalLabels(
            for: quads,
            hashAlgorithm: hashAlgorithm(for: entry),
            workFactor: workFactor(for: entry)
        )
        let actual = stripBlankNodePrefixes(raw)
        #expect(
            actual == expected,
            """
            \(entry.id) (\(entry.name)) — blank-node map mismatch
            --- expected ---
            \(expected)
            --- actual ---
            \(actual)
            """
        )
    }

    private static func runNegativeTest(_ entry: TestEntry) throws {
        let input = try loadFixture(entry.action)
        let algo = hashAlgorithm(for: entry)
        let wf = workFactor(for: entry)
        #expect(throws: (any Error).self) {
            _ = try RDFCanonize.canonicalize(
                nquads: input,
                hashAlgorithm: algo,
                workFactor: wf
            )
        }
    }

    /// Decode the manifest's `hashAlgorithm` field (defaults to SHA-256).
    private static func hashAlgorithm(for entry: TestEntry) -> RDFCanonize.HashAlgorithm {
        switch entry.hashAlgorithm?.uppercased() {
        case "SHA384": return .sha384
        default:       return .sha256
        }
    }

    /// Map the manifest's `computationalComplexity` tag to a workFactor,
    /// mirroring the JS reference's W3C suite runner:
    ///   low → 0 (no n-degree expected), medium → 2 (O(n²)), high → 3 (O(n³)).
    /// Tests without a tag are run unbounded.
    private static func workFactor(for entry: TestEntry) -> Int {
        switch entry.computationalComplexity?.lowercased() {
        case "low":    return 0
        case "medium": return 2
        case "high":   return 3
        default:       return .max
        }
    }

    // MARK: Helpers

    /// All manifest entries, loaded once at test-collection time.
    ///
    /// If the suite hasn't been initialized this returns `[]` — the
    /// smoke test in `SuiteSmokeTests` will surface the failure with a
    /// clearer message than a parameterized test array would.
    static func allEntries() -> [TestEntry] {
        (try? TestManifest.load().entries) ?? []
    }

    private static func loadFixture(_ relativePath: String) throws -> String {
        let url = SuiteLocator.fixtureURL(relativePath)
        let data = try Data(contentsOf: url)
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeMap(_ json: String) throws -> [String: String] {
        guard let data = json.data(using: .utf8) else { return [:] }
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    /// The suite's expected map JSON uses bare labels (`"e0"`, `"c14n0"`)
    /// while our internal map carries `_:` prefixes. Normalize both
    /// sides by stripping the prefix.
    private static func stripBlankNodePrefixes(_ raw: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        out.reserveCapacity(raw.count)
        for (k, v) in raw {
            out[strip(k)] = strip(v)
        }
        return out
    }

    private static func strip(_ s: String) -> String {
        s.hasPrefix("_:") ? String(s.dropFirst(2)) : s
    }
}

// Allow TestEntry to be used as a Swift-Testing parameter.
extension TestEntry: CustomTestStringConvertible {
    var testDescription: String { "\(id) — \(name)" }
}
