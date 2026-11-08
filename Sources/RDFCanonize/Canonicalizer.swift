import Foundation
import Crypto

extension RDFCanonize {
    /// Implements [RDFC-1.0 §4.4 Canonicalization Algorithm](https://www.w3.org/TR/rdf-canon/#canon-algorithm)
    /// including the n-degree hash recursion ([§4.8](https://www.w3.org/TR/rdf-canon/#hash-nd-quads))
    /// required to canonicalize symmetric blank-node graphs.
    ///
    /// Use `canonicalLabels(for:)` to obtain the `[originalID: canonicalID]`
    /// map for a dataset; `RDFCanonize.canonicalize(quads:)` is the
    /// public, end-to-end entry point that also applies the labels and
    /// emits sorted N-Quads.
    struct Canonicalizer {
        // MARK: Inputs

        private let quads: [Quad]
        private let hashAlgorithm: HashAlgorithm
        private let workFactor: Int

        // MARK: State

        /// Per-blank-node info: every quad that mentions the blank node,
        /// plus the cached first-degree hash (filled in during step 2).
        private var blankNodeInfo: [String: BlankNodeInfo] = [:]

        /// The canonical issuer (prefix `c14n`). Mutated in steps 3 and 4.
        private var canonicalIssuer = IdentifierIssuer(prefix: "c14n")

        /// Remaining N-Degree calls before we throw `.iterationLimitExceeded`.
        /// Computed in `run()` from the number of non-unique blank nodes
        /// raised to `workFactor`. Decremented at the head of every
        /// `hashNDegreeQuads` invocation.
        private var remainingDeepIterations: Int = .max
        /// Permutations visited across all n-degree hashes. A node with
        /// many identical neighbours enumerates n! orderings without
        /// recursing, which the deep-iteration budget alone never sees.
        private var remainingPermutations: Int = .max

        private struct BlankNodeInfo {
            var quads: [Quad] = []
            var firstDegreeHash: String = ""
        }

        // MARK: Public entry

        /// Compute the canonical label map (`originalID → _:c14nN`) for
        /// the dataset.
        ///
        /// Throws `CanonicalizeError.iterationLimitExceeded` when the
        /// N-Degree Hash recursion exceeds `nonUniqueCount ^ workFactor`.
        /// `Int.max` disables the bound (the default for trusted inputs).
        static func canonicalLabels(
            for quads: [Quad],
            hashAlgorithm: HashAlgorithm = .sha256,
            workFactor: Int = .max
        ) throws -> [String: String] {
            var c = Canonicalizer(
                quads: quads,
                hashAlgorithm: hashAlgorithm,
                workFactor: workFactor
            )
            return try c.run()
        }

        // MARK: Algorithm

        private init(quads: [Quad], hashAlgorithm: HashAlgorithm, workFactor: Int) {
            self.quads = quads
            self.hashAlgorithm = hashAlgorithm
            self.workFactor = workFactor
        }

        private mutating func run() throws -> [String: String] {
            // Steps 1–2: build blank-node → quads map.
            for quad in quads {
                addBlankInfo(quad: quad, component: quad.subject)
                addBlankInfo(quad: quad, component: quad.object)
                if let g = quad.graph { addBlankInfo(quad: quad, component: g) }
            }

            if blankNodeInfo.isEmpty { return [:] }

            // Step 5: compute first-degree hashes and bucket by hash.
            var hashToBN: [String: [String]] = [:]
            for id in blankNodeInfo.keys {
                let h = hashFirstDegreeQuads(id: id)
                blankNodeInfo[id]!.firstDegreeHash = h
                hashToBN[h, default: []].append(id)
            }

            // Step 5.4: assign canonical labels for unique first-degree
            // hashes (sorted by hash); collect non-unique groups for the
            // n-degree pass.
            var nonUnique: [[String]] = []
            for hash in hashToBN.keys.sorted() {
                var ids = hashToBN[hash]!
                if ids.count > 1 {
                    // Sort so the iteration order in step 6.2 is stable.
                    ids.sort()
                    nonUnique.append(ids)
                    continue
                }
                canonicalIssuer.getId(ids[0])
            }

            // Compute the deep-iteration budget. `Int.max` short-circuits
            // to "unbounded" — that's the default for trusted inputs.
            // Otherwise: limit = nonUniqueCount ^ workFactor (matches
            // the JS reference, mapping low/medium/high complexity →
            // workFactor 0/2/3 in the W3C conformance runner).
            if workFactor == .max {
                remainingDeepIterations = .max
                remainingPermutations = .max
            } else {
                let nonUniqueCount = nonUnique.reduce(0) { $0 + $1.count }
                remainingDeepIterations = boundedPow(nonUniqueCount, workFactor)
                let (scaled, overflow) = remainingDeepIterations.multipliedReportingOverflow(by: 1024)
                remainingPermutations = overflow ? .max : max(scaled, 1024)
            }

            // Step 6: resolve non-unique groups via n-degree hashing.
            for idList in nonUnique {
                var hashPathList: [(hash: String, issuer: IdentifierIssuer)] = []
                for id in idList {
                    // 6.2.1: skip ids already assigned by a prior group.
                    if canonicalIssuer.hasId(id) { continue }
                    // 6.2.2-3: fresh temporary issuer, seeded with `id`.
                    var temp = IdentifierIssuer(prefix: "b")
                    temp.getId(id)
                    // 6.2.4: full n-degree hash.
                    let result = try hashNDegreeQuads(id: id, issuer: temp)
                    hashPathList.append(result)
                }
                // 6.3: in order of hash, transfer temporary labels into
                // the canonical issuer in their original issuance order.
                hashPathList.sort { $0.hash < $1.hash }
                for entry in hashPathList {
                    for oldID in entry.issuer.issuedOrder {
                        canonicalIssuer.getId(oldID)
                    }
                }
            }

            return canonicalIssuer.existing
        }

        // MARK: Blank-node info

        private mutating func addBlankInfo(quad: Quad, component: Term) {
            guard case .blankNode(let id) = component else { return }
            blankNodeInfo[id, default: BlankNodeInfo()].quads.append(quad)
        }

        // MARK: Hash First Degree Quads — §4.7

        private func hashFirstDegreeQuads(id: String) -> String {
            guard let info = blankNodeInfo[id] else { return hashHex("") }
            var nquads: [String] = []
            for quad in info.quads {
                let masked = mask(quad, target: id)
                nquads.append(NQuadsWriter.serialize(quad: masked))
            }
            nquads.sort()
            let joined = nquads.joined(separator: "\n") + (nquads.isEmpty ? "" : "\n")
            return hashHex(joined)
        }

        private func mask(_ quad: Quad, target: String) -> Quad {
            Quad(
                subject: mask(quad.subject, target: target),
                predicate: quad.predicate,
                object: mask(quad.object, target: target),
                graph: quad.graph.map { mask($0, target: target) }
            )
        }

        private func mask(_ term: Term, target: String) -> Term {
            guard case .blankNode(let id) = term else { return term }
            return .blankNode(id == target ? "_:a" : "_:z")
        }

        // MARK: Hash Related Blank Node — §4.7

        /// §4.7 Hash Related Blank Node. The "input" string is
        /// `position` + (optional) `<predicate>` + identifier-for-related.
        private func hashRelatedBlankNode(
            related: String,
            quad: Quad,
            issuer: IdentifierIssuer,
            position: Character
        ) -> String {
            var input = String(position)
            if position != "g" {
                if case .iri(let pred) = quad.predicate {
                    input += "<\(pred)>"
                }
            }
            let id: String
            if canonicalIssuer.hasId(related) {
                id = canonicalIssuer.existing[related]!
            } else if issuer.hasId(related) {
                id = issuer.existing[related]!
            } else {
                id = blankNodeInfo[related]?.firstDegreeHash ?? hashFirstDegreeQuads(id: related)
            }
            input += id
            return hashHex(input)
        }

        // MARK: Hash N-Degree Quads — §4.8

        private mutating func hashNDegreeQuads(
            id: String,
            issuer: IdentifierIssuer
        ) throws -> (hash: String, issuer: IdentifierIssuer) {
            // Bounded-iteration safeguard. Without this, poison graphs
            // (e.g. the 10-node clique in W3C test #074) would explore
            // n! permutations recursively and never return.
            if remainingDeepIterations == 0 {
                throw CanonicalizeError.iterationLimitExceeded(
                    limit: boundedPow(blankNodeInfo.count, workFactor)
                )
            }
            remainingDeepIterations -= 1

            // Step 1–3: build the hash-to-related-blank-nodes map.
            let hashToRelated = createHashToRelated(id: id, issuer: issuer)

            // Step 4–5: walk related-hash groups in sorted order,
            // accumulating chosen-path strings.
            var dataToHash = ""
            var workingIssuer = issuer

            for relatedHash in hashToRelated.keys.sorted() {
                dataToHash += relatedHash
                let relatedList = hashToRelated[relatedHash]!

                var chosenPath = ""
                var chosenIssuer: IdentifierIssuer? = nil

                for permutation in Self.permutations(of: relatedList) {
                    // Each permutation is work too: a node with many
                    // identical neighbours enumerates n! orderings
                    // without recursing, so a finite budget must cover
                    // them as well as the recursive calls, with a
                    // separate, larger allowance than recursion.
                    if remainingPermutations != .max {
                        if remainingPermutations == 0 {
                            throw CanonicalizeError.iterationLimitExceeded(
                                limit: boundedPow(blankNodeInfo.count, workFactor)
                            )
                        }
                        remainingPermutations -= 1
                    }
                    var issuerCopy = workingIssuer
                    var path = ""
                    var recursionList: [String] = []
                    var skipPermutation = false

                    // 5.4.4: build the first part of the path from the
                    // permutation directly.
                    for related in permutation {
                        if canonicalIssuer.hasId(related) {
                            path += canonicalIssuer.existing[related]!
                        } else {
                            if !issuerCopy.hasId(related) {
                                recursionList.append(related)
                            }
                            path += issuerCopy.getId(related)
                        }
                        if !chosenPath.isEmpty && path > chosenPath {
                            skipPermutation = true
                            break
                        }
                    }
                    if skipPermutation { continue }

                    // 5.4.5: recurse into related blank nodes that need
                    // further disambiguation.
                    for related in recursionList {
                        let result = try hashNDegreeQuads(id: related, issuer: issuerCopy)
                        path += issuerCopy.getId(related)
                        path += "<\(result.hash)>"
                        issuerCopy = result.issuer
                        if !chosenPath.isEmpty && path > chosenPath {
                            skipPermutation = true
                            break
                        }
                    }
                    if skipPermutation { continue }

                    // 5.4.6: keep the lexicographically-smallest path.
                    if chosenPath.isEmpty || path < chosenPath {
                        chosenPath = path
                        chosenIssuer = issuerCopy
                    }
                }

                dataToHash += chosenPath
                if let chosen = chosenIssuer {
                    workingIssuer = chosen
                }
            }

            return (hashHex(dataToHash), workingIssuer)
        }

        /// §4.8 step 3: for each quad mentioning `id`, hash every OTHER
        /// blank node component grouped by (position, predicate, target id).
        private func createHashToRelated(
            id: String,
            issuer: IdentifierIssuer
        ) -> [String: [String]] {
            guard let info = blankNodeInfo[id] else { return [:] }
            var map: [String: [String]] = [:]
            for quad in info.quads {
                addRelatedHash(quad: quad, component: quad.subject, position: "s",
                               id: id, issuer: issuer, into: &map)
                addRelatedHash(quad: quad, component: quad.object, position: "o",
                               id: id, issuer: issuer, into: &map)
                if let g = quad.graph {
                    addRelatedHash(quad: quad, component: g, position: "g",
                                   id: id, issuer: issuer, into: &map)
                }
            }
            return map
        }

        private func addRelatedHash(
            quad: Quad,
            component: Term,
            position: Character,
            id: String,
            issuer: IdentifierIssuer,
            into map: inout [String: [String]]
        ) {
            guard case .blankNode(let related) = component, related != id else { return }
            let h = hashRelatedBlankNode(related: related, quad: quad,
                                         issuer: issuer, position: position)
            map[h, default: []].append(related)
        }

        // MARK: Iteration budget

        /// `base ^ exp` with overflow clamped to `Int.max`. Used to size
        /// the deep-iteration budget — overflow effectively disables the
        /// bound (mirrors the reference implementation's `Infinity`).
        private func boundedPow(_ base: Int, _ exp: Int) -> Int {
            if base <= 0 || exp <= 0 { return base == 0 ? 0 : 1 }
            var result = 1
            for _ in 0..<exp {
                let (next, overflow) = result.multipliedReportingOverflow(by: base)
                if overflow { return .max }
                result = next
            }
            return result
        }

        // MARK: Permuter

        /// All permutations of `list`, produced lazily in lexicographic
        /// order of positions so memory stays linear in `list.count`
        /// however many permutations are visited.
        static func permutations<T>(of list: [T]) -> LazyPermutations<T> {
            LazyPermutations(list)
        }

        struct LazyPermutations<T>: Sequence, IteratorProtocol {
            private let items: [T]
            private var indices: [Int]
            private var done = false

            init(_ items: [T]) {
                self.items = items
                self.indices = Array(items.indices)
            }

            mutating func next() -> [T]? {
                guard !done else { return nil }
                let current = indices.map { items[$0] }
                // Advance to the next lexicographic permutation of indices.
                var i = indices.count - 2
                while i >= 0 && indices[i] >= indices[i + 1] { i -= 1 }
                if i < 0 {
                    done = true
                } else {
                    var j = indices.count - 1
                    while indices[j] <= indices[i] { j -= 1 }
                    indices.swapAt(i, j)
                    indices[(i + 1)...].reverse()
                }
                return current
            }
        }

        // MARK: Hash

        private func hashHex(_ s: String) -> String {
            hashAlgorithm.hex(s)
        }
    }
}
