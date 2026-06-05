import RDFCanonize

/// Deterministic quad generators for the benchmark suite. No
/// randomness — each call returns the same dataset so benchmark
/// numbers are reproducible across runs.
enum Scenarios {

    /// Build `count` triples in a linear chain. `blankPercent` controls
    /// the share of subjects / objects that are blank nodes; the rest
    /// are unique IRIs from the `urn:bench:` namespace.
    ///
    /// At 0% blanks the algorithm short-circuits — no n-degree work.
    /// At 100% blanks every term is non-unique, exercising the full
    /// canonicalization path.
    static func linearChain(quads count: Int, blankPercent: Int) -> [RDFCanonize.Quad] {
        precondition((0...100).contains(blankPercent))
        var out: [RDFCanonize.Quad] = []
        out.reserveCapacity(count)
        let blankThreshold = blankPercent
        for i in 0..<count {
            let s = (i % 100) < blankThreshold
                ? RDFCanonize.Term.blankNode("_:s\(i)")
                : RDFCanonize.Term.iri("urn:bench:s\(i)")
            let o = ((i + 13) % 100) < blankThreshold
                ? RDFCanonize.Term.blankNode("_:o\(i)")
                : RDFCanonize.Term.iri("urn:bench:o\(i)")
            out.append(.init(
                subject: s,
                predicate: .iri("urn:bench:p"),
                object: o
            ))
        }
        return out
    }

    /// Build `clusters` symmetric clusters, each containing `perCluster`
    /// blank nodes wired into a fully-connected sub-graph. Cluster size
    /// stays small (3 nodes recommended) so the n-degree permutation
    /// search stays tractable under the default `workFactor` budget.
    static func symmetricCluster(clusters: Int, perCluster: Int) -> [RDFCanonize.Quad] {
        var out: [RDFCanonize.Quad] = []
        for c in 0..<clusters {
            for i in 0..<perCluster {
                for j in 0..<perCluster where i != j {
                    out.append(.init(
                        subject: .blankNode("_:c\(c)n\(i)"),
                        predicate: .iri("urn:bench:edge"),
                        object: .blankNode("_:c\(c)n\(j)")
                    ))
                }
            }
        }
        return out
    }
}
