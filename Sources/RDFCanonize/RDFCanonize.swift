import Foundation

/// Swift implementation of [RDF Dataset Canonicalization](https://www.w3.org/TR/rdf-canon/)
/// (RDFC-1.0, also known as URDNA2015).
///
/// `RDFCanonize` is the public namespace for the package. Public entry
/// points are static functions; there is no instance to construct.
///
/// > **Status — Phase 5 in progress.** The straightforward path
/// > (datasets with no blank-node label collisions) is working.
/// > The n-degree hash recursion that handles symmetric blank-node
/// > graphs is partial — full RDFC-1.0 conformance is iterative work
/// > against the [w3c/rdf-canon](https://github.com/w3c/rdf-canon)
/// > test suite.
public enum RDFCanonize {}

extension RDFCanonize {
    /// Canonicalize an N-Quads document. Returns canonical N-Quads
    /// with `_:c14n0`, `_:c14n1`, … blank-node labels in lexicographic
    /// order.
    public static func canonicalize(nquads: String) throws -> String {
        let quads = try NQuadsParser.parse(nquads)
        return canonicalize(quads: quads)
    }

    /// Canonicalize an already-parsed list of quads.
    public static func canonicalize(quads: [Quad]) -> String {
        let labels = IdentifierIssuer.canonicalIdentifiers(for: quads)
        let relabeled = quads.map { relabel($0, with: labels) }
        return NQuadsWriter.serialize(quads: relabeled.sorted { $0.canonicalKey < $1.canonicalKey })
    }

    private static func relabel(_ quad: Quad, with labels: [String: String]) -> Quad {
        Quad(
            subject: relabel(quad.subject, with: labels),
            predicate: quad.predicate,
            object: relabel(quad.object, with: labels),
            graph: quad.graph.map { relabel($0, with: labels) }
        )
    }

    private static func relabel(_ term: Term, with labels: [String: String]) -> Term {
        if case .blankNode(let id) = term, let canonical = labels[id] {
            return .blankNode(canonical)
        }
        return term
    }
}

extension RDFCanonize.Quad {
    /// Stable sort key for canonical N-Quads output (the canonical
    /// blank-node labels have already been applied).
    var canonicalKey: String {
        let w = RDFCanonize.NQuadsWriter.self
        var s = "\(w.serialize(term: subject)) \(w.serialize(term: predicate)) \(w.serialize(term: object))"
        if let g = graph { s += " \(w.serialize(term: g))" }
        return s
    }
}
