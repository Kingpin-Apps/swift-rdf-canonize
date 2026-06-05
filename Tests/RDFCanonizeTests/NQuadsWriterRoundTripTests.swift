import Testing
import Foundation
@testable import RDFCanonize

/// Confirm `NQuadsWriter`'s output is stable under re-parsing — i.e.
/// `parse(serialize(parse(x))) == parse(x)` for every W3C eval
/// expected output. Catches escape-fidelity regressions where the
/// writer emits something the parser can't read back.
@Suite("Writer round-trip")
struct NQuadsWriterRoundTripTests {

    /// All `-rdfc10.nq` expected outputs in the W3C suite. Each one is
    /// a small, valid canonical N-Quads document — ideal round-trip
    /// material because the algorithm has already produced exactly the
    /// form the parser is supposed to accept.
    static let fixtures: [String] = {
        let dir = SuiteLocator.testsDirectory.appendingPathComponent("rdfc10")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return []
        }
        return names
            .filter { $0.hasSuffix("-rdfc10.nq") }
            .sorted()
    }()

    @Test(
        "Parse → serialize → parse yields the same quads",
        arguments: Self.fixtures
    )
    func roundTrip(_ filename: String) throws {
        let url = SuiteLocator.testsDirectory
            .appendingPathComponent("rdfc10")
            .appendingPathComponent(filename)
        let raw = try String(decoding: Data(contentsOf: url), as: UTF8.self)
        let first = try RDFCanonize.NQuadsParser.parse(raw)
        let serialized = RDFCanonize.NQuadsWriter.serialize(quads: first)
        let second = try RDFCanonize.NQuadsParser.parse(serialized)
        #expect(
            first == second,
            "\(filename): re-parsed serialized quads diverged from the original parse."
        )
    }
}
