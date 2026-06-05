import Testing
@testable import RDFCanonize

/// `workFactor` is the n-degree-hash poison-graph defense. The W3C
/// test074 covers one specific 10-node clique; these tests
/// parameterize the size + bound combination so future tweaks don't
/// silently regress the bounded-iteration safeguard.
@Suite("Poison-graph workFactor enforcement")
struct PoisonGraphTests {

    /// Build the n-node symmetric clique used by W3C test074:
    /// `_:b{i} <urn:p> _:b{j}` for every i ≠ j. The resulting graph
    /// is the canonical poison shape — every blank node has identical
    /// first-degree neighborhoods, so the algorithm has to permute
    /// all n! orderings to find the lexicographic minimum.
    private static func clique(nodes n: Int) -> [RDFCanonize.Quad] {
        var out: [RDFCanonize.Quad] = []
        out.reserveCapacity(n * (n - 1))
        for i in 0..<n {
            for j in 0..<n where i != j {
                out.append(.init(
                    subject: .blankNode("_:b\(i)"),
                    predicate: .iri("urn:p"),
                    object: .blankNode("_:b\(j)")
                ))
            }
        }
        return out
    }

    @Test(
        "Bounded-iteration safeguard rejects symmetric cliques larger than the workFactor budget",
        arguments: [
            // Small (nodes, workFactor) pairs that prove the budget
            // throws quickly. Larger combinations (e.g. 12 × wf:3) take
            // minutes of permutation search before throwing; the W3C
            // suite's `test074` covers the full 10-node clique at the
            // default unbounded workFactor.
            (nodes: 5, wf: 1),
            (nodes: 6, wf: 1),
            (nodes: 7, wf: 1),
            (nodes: 8, wf: 1),
        ]
    )
    func cliqueBound(_ args: (nodes: Int, wf: Int)) {
        let quads = Self.clique(nodes: args.nodes)
        #expect(throws: RDFCanonize.CanonicalizeError.self) {
            _ = try RDFCanonize.canonicalize(quads: quads, workFactor: args.wf)
        }
    }

    @Test("Three-node clique succeeds under a modest workFactor")
    func smallCliqueSucceeds() throws {
        let out = try RDFCanonize.canonicalize(quads: Self.clique(nodes: 3), workFactor: 3)
        // 3 nodes × 2 outgoing edges = 6 quads, three distinct canonical
        // labels. The exact serialization is asserted by the W3C suite;
        // here we only need non-empty output.
        #expect(!out.isEmpty)
    }

    @Test("Default workFactor (`.max`) canonicalizes a small clique without throwing")
    func smallCliqueDefaultBudget() throws {
        let out = try RDFCanonize.canonicalize(quads: Self.clique(nodes: 3))
        #expect(!out.isEmpty)
    }
}
