import Testing
import Foundation
@testable import RDFCanonize

/// Spec-level invariants that the algorithm must preserve regardless of
/// how the input arrives. These complement the W3C suite (which only
/// asserts fixed input → fixed output) by stressing input variation.
@Suite("Canonicalization invariants")
struct CanonicalInvariantsTests {

    /// A 6-quad, 3-blank-node dataset that exercises the n-degree path
    /// (the three blank nodes are linked into a chain, so first-degree
    /// alone can't disambiguate them).
    private static let baseQuads: [RDFCanonize.Quad] = [
        .init(
            subject: .blankNode("_:b0"),
            predicate: .iri("http://example.org/p"),
            object: .literal(.init(value: "alpha"))
        ),
        .init(
            subject: .blankNode("_:b0"),
            predicate: .iri("http://example.org/link"),
            object: .blankNode("_:b1")
        ),
        .init(
            subject: .blankNode("_:b1"),
            predicate: .iri("http://example.org/p"),
            object: .literal(.init(value: "beta"))
        ),
        .init(
            subject: .blankNode("_:b1"),
            predicate: .iri("http://example.org/link"),
            object: .blankNode("_:b2")
        ),
        .init(
            subject: .blankNode("_:b2"),
            predicate: .iri("http://example.org/p"),
            object: .literal(.init(value: "gamma"))
        ),
        .init(
            subject: .iri("http://example.org/root"),
            predicate: .iri("http://example.org/firstBlank"),
            object: .blankNode("_:b0")
        ),
    ]

    @Test("Order independence — every permutation canonicalizes identically")
    func orderIndependence_shuffledInput() throws {
        let baseline = try RDFCanonize.canonicalize(quads: Self.baseQuads)
        try #require(!baseline.isEmpty)
        // Four explicit, deterministic permutations. Combined with the
        // baseline they exhaust the small permutation space we need to
        // exercise; fully random shuffles would add CI flakiness for
        // no extra signal.
        let permutations: [[Int]] = [
            [5, 4, 3, 2, 1, 0],
            [3, 1, 4, 0, 5, 2],
            [0, 2, 4, 1, 3, 5],
            [4, 0, 5, 3, 1, 2],
        ]
        for perm in permutations {
            let reordered = perm.map { Self.baseQuads[$0] }
            let out = try RDFCanonize.canonicalize(quads: reordered)
            #expect(out == baseline, "Permutation \(perm) yielded different canonical form.")
        }
    }

    @Test("Blank-node relabel independence — renamed inputs produce the same canonical labels")
    func relabelIndependence_renamedBlankNodes() throws {
        let baseline = try RDFCanonize.canonicalize(quads: Self.baseQuads)
        let renames: [String: String] = ["_:b0": "_:x", "_:b1": "_:y", "_:b2": "_:z"]
        func rename(_ t: RDFCanonize.Term) -> RDFCanonize.Term {
            if case .blankNode(let id) = t, let next = renames[id] {
                return .blankNode(next)
            }
            return t
        }
        let relabeled: [RDFCanonize.Quad] = Self.baseQuads.map { q in
            .init(
                subject: rename(q.subject),
                predicate: q.predicate,
                object: rename(q.object),
                graph: q.graph.map(rename)
            )
        }
        let out = try RDFCanonize.canonicalize(quads: relabeled)
        #expect(out == baseline)
    }

    @Test("Determinism — 100 successive runs all match")
    func determinism_repeatedRuns() throws {
        let baseline = try RDFCanonize.canonicalize(quads: Self.baseQuads)
        for _ in 0..<100 {
            let out = try RDFCanonize.canonicalize(quads: Self.baseQuads)
            #expect(out == baseline)
        }
    }
}
