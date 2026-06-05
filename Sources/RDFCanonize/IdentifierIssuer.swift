import Foundation
import Crypto

extension RDFCanonize {
    /// Assigns canonical `_:c14n0`, `_:c14n1`, … labels to the blank
    /// nodes in a dataset.
    ///
    /// > **Status — Phase 5 partial.** Implements the first-degree
    /// > hash phase of [RDFC-1.0 §4.4.4](https://www.w3.org/TR/rdf-canon/#hash-1d-quads):
    /// > each blank node is hashed against its surrounding quads;
    /// > nodes are then sorted by hash and assigned canonical labels.
    /// > The n-degree hash recursion that breaks ties for symmetric
    /// > graphs is not yet implemented — colliding blank nodes get
    /// > labels in their original-id order as a deterministic
    /// > fallback.
    enum IdentifierIssuer {
        /// Compute canonical labels for every blank node referenced
        /// by `quads`. Returns a `[originalID: canonicalID]` map.
        static func canonicalIdentifiers(for quads: [Quad]) -> [String: String] {
            // Gather all blank nodes referenced in the dataset.
            var blankIDs: Set<String> = []
            for q in quads {
                if case .blankNode(let id) = q.subject { blankIDs.insert(id) }
                if case .blankNode(let id) = q.object { blankIDs.insert(id) }
                if let g = q.graph, case .blankNode(let id) = g { blankIDs.insert(id) }
            }
            if blankIDs.isEmpty { return [:] }

            // First-degree hash per blank node.
            var hashes: [(id: String, hash: String)] = []
            for id in blankIDs {
                let h = firstDegreeHash(for: id, quads: quads)
                hashes.append((id, h))
            }

            // Sort by (hash, original-id) so ties resolve deterministically.
            hashes.sort {
                if $0.hash != $1.hash { return $0.hash < $1.hash }
                return $0.id < $1.id
            }

            var canonical: [String: String] = [:]
            for (index, entry) in hashes.enumerated() {
                canonical[entry.id] = "_:c14n\(index)"
            }
            return canonical
        }

        /// First-Degree Hash — [RDFC-1.0 §4.7.1](https://www.w3.org/TR/rdf-canon/#hash-first-degree-quads).
        ///
        /// Hash the canonical N-Quads form of every quad that mentions
        /// the target blank node, with the target's id replaced by
        /// `_:a` and other blank-node ids replaced by `_:z`.
        private static func firstDegreeHash(for target: String, quads: [Quad]) -> String {
            var nquads: [String] = []
            for quad in quads {
                if !mentions(quad, blankNode: target) { continue }
                let masked = mask(quad, target: target)
                nquads.append(NQuadsWriter.serialize(quad: masked))
            }
            nquads.sort()
            let joined = nquads.joined(separator: "\n") + (nquads.isEmpty ? "" : "\n")
            return sha256Hex(joined)
        }

        private static func mentions(_ quad: Quad, blankNode target: String) -> Bool {
            if case .blankNode(let id) = quad.subject, id == target { return true }
            if case .blankNode(let id) = quad.object, id == target { return true }
            if let g = quad.graph, case .blankNode(let id) = g, id == target { return true }
            return false
        }

        private static func mask(_ quad: Quad, target: String) -> Quad {
            Quad(
                subject: mask(quad.subject, target: target),
                predicate: quad.predicate,
                object: mask(quad.object, target: target),
                graph: quad.graph.map { mask($0, target: target) }
            )
        }

        private static func mask(_ term: Term, target: String) -> Term {
            guard case .blankNode(let id) = term else { return term }
            return .blankNode(id == target ? "_:a" : "_:z")
        }

        private static func sha256Hex(_ s: String) -> String {
            let digest = SHA256.hash(data: Data(s.utf8))
            return digest.map { String(format: "%02x", $0) }.joined()
        }
    }
}
