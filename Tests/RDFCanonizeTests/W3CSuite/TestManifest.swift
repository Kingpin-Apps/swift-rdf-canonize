import Foundation

/// Decoded W3C rdf-canon test manifest (`tests/manifest.jsonld`).
///
/// The manifest is itself a JSON-LD document; we treat it as plain JSON
/// because the keys we care about are unambiguous without expansion.
struct TestManifest: Decodable, Sendable, Hashable {
    let label: String
    let comment: String?
    let entries: [TestEntry]

    enum CodingKeys: String, CodingKey {
        case label
        case comment
        case entries
    }
}

/// A single test case within the rdf-canon manifest.
struct TestEntry: Decodable, Sendable, Hashable, CustomStringConvertible {
    /// Fragment identifier like `"#test001c"`.
    let id: String
    /// Test type IRI, one of:
    /// - `rdfc:RDFC10EvalTest`         — canonicalization → expected N-Quads
    /// - `rdfc:RDFC10MapTest`          — canonicalization → expected blank-node map JSON
    /// - `rdfc:RDFC10NegativeEvalTest` — input the algorithm must reject
    let type: String
    /// Human-readable test name.
    let name: String
    /// Optional commentary from the suite editors.
    let comment: String?
    /// `low` for normal inputs, `high` for poison graphs that exercise
    /// the algorithm's bounded-complexity safeguards.
    let computationalComplexity: String?
    /// Hash function — defaults to `SHA256`; a handful of tests override
    /// to `SHA384`.
    let hashAlgorithm: String?
    /// Approval status (`rdft:Approved`, etc.).
    let approval: String?
    /// Manifest-relative path to the input `.nq` document.
    let action: String
    /// Manifest-relative path to the expected output. Absent on
    /// `RDFC10NegativeEvalTest`.
    let result: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case comment
        case computationalComplexity
        case hashAlgorithm
        case approval
        case action
        case result
    }

    var description: String { "\(id) \(name)" }

    enum Kind {
        case eval
        case map
        case negative
        case unknown(String)
    }

    var kind: Kind {
        switch type {
        case "rdfc:RDFC10EvalTest": return .eval
        case "rdfc:RDFC10MapTest": return .map
        case "rdfc:RDFC10NegativeEvalTest": return .negative
        default: return .unknown(type)
        }
    }
}

extension TestManifest {
    enum LoadError: Error, CustomStringConvertible {
        case manifestMissing(URL)
        case decodingFailed(URL, underlying: any Error)

        var description: String {
            switch self {
            case let .manifestMissing(url):
                return """
                W3C rdf-canon manifest not found at \(url.path).
                Did you run `git submodule update --init`?
                """
            case let .decodingFailed(url, err):
                return "Failed to decode \(url.lastPathComponent): \(err)"
            }
        }
    }

    /// Load and decode the rdf-canon manifest from the on-disk submodule.
    static func load() throws -> TestManifest {
        let url = SuiteLocator.manifestURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LoadError.manifestMissing(url)
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(TestManifest.self, from: data)
        } catch {
            throw LoadError.decodingFailed(url, underlying: error)
        }
    }
}
