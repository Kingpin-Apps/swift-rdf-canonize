# ``RDFCanonize``

Deterministic, spec-conformant canonicalization of RDF datasets in pure Swift.

## Overview

`RDFCanonize` implements [RDF Dataset Canonicalization (RDFC-1.0)](https://www.w3.org/TR/rdf-canon/) —
also published in earlier drafts as URDNA2015 — the algorithm that
produces a stable, byte-for-byte canonical serialization of an RDF
dataset. Canonicalization is the prerequisite for hashing or signing
linked-data documents: two datasets with the same RDF semantics produce
the same N-Quads string, even when the original input differs in
blank-node label choice, triple order, or duplicate quads.

This package is a leaf sibling of
[swift-jsonld](https://github.com/Kingpin-Apps/swift-jsonld), mirroring
the [`rdf-canonize`](https://github.com/digitalbazaar/rdf-canonize) /
[`jsonld.js`](https://github.com/digitalbazaar/jsonld.js) split in the
JavaScript ecosystem. Use it directly when you only need the
canonicalization step and want to avoid the full JSON-LD surface —
typical cases include hashing
[CIP-100 governance metadata](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0100),
[Verifiable Credentials](https://www.w3.org/TR/vc-data-model/), or any
linked-data document destined for a signature.

The implementation is pure Swift on top of `Foundation` and
[swift-crypto](https://github.com/apple/swift-crypto), with no other
runtime dependencies.

## Quickstart

The most common path: feed N-Quads in, receive canonical N-Quads out.

```swift
import RDFCanonize

let input = """
_:b1 <http://example.org/p> _:b2 .
_:b2 <http://example.org/q> "leaf" .
"""

let canonical = try RDFCanonize.canonicalize(nquads: input)
// → "_:c14n0 <http://example.org/p> _:c14n1 .\n_:c14n1 <http://example.org/q> \"leaf\" .\n"
```

Blank-node labels are reassigned to `_:c14n0`, `_:c14n1`, …; quads are
emitted in lexicographic order; duplicate quads collapse.

## Working from parsed quads

If you already have ``RDFCanonize/Quad`` values — for example, from a
JSON-LD `toRdf` pass — skip the parser and call
``RDFCanonize/canonicalize(quads:)`` directly:

```swift
let quads: [RDFCanonize.Quad] = …
let canonical = RDFCanonize.canonicalize(quads: quads)
```

This is the path [swift-jsonld](https://github.com/Kingpin-Apps/swift-jsonld)'s
`JSONLD.canonize()` takes — it materializes the JSON-LD document as
`[Quad]` and hands it off here, avoiding an unnecessary N-Quads
round-trip.

## Conformance

The implementation runs against the
[W3C `rdf-canon` test suite](https://github.com/w3c/rdf-canon) as part
of `swift test` and passes every entry — including SHA-384, the full
N-Quads escape-fidelity test, and the negative poison-graph test gated
on the bounded-iteration safeguard. The suite is wired in as a git
submodule under `Tests/RDFCanonizeTests/rdf-canon`; run
`git submodule update --init` after cloning.

### Hash algorithm

The default is SHA-256, as the spec stipulates. Pass `hashAlgorithm: .sha384`
to opt into the alternative defined in [RDFC-1.0 §6](https://www.w3.org/TR/rdf-canon/#dfn-hash-algorithm).

### Poison-graph defense

Trusted inputs canonicalize without a bound (`workFactor: .max`, the
default). To reject inputs whose symmetric topology would explode the
N-Degree Hash recursion, pass a finite `workFactor`. The deep-iteration
budget is then `nonUniqueCount ^ workFactor`; exceeding it raises
``RDFCanonize/CanonicalizeError/iterationLimitExceeded(limit:)``.

## Algorithm reference

The algorithm is defined by the W3C Recommendation. Rather than
reproduce it here, see:

- [RDF Dataset Canonicalization (RDFC-1.0)](https://www.w3.org/TR/rdf-canon/) — the spec.
- [§4.7 Hash First Degree Quads](https://www.w3.org/TR/rdf-canon/#hash-first-degree-quads)
- [§4.8 Hash N-Degree Quads](https://www.w3.org/TR/rdf-canon/#hash-nd-quads)
- [RDF 1.1 N-Quads](https://www.w3.org/TR/n-quads/) — the input/output format.

## Topics

### Canonicalization

- ``RDFCanonize/canonicalize(nquads:)``
- ``RDFCanonize/canonicalize(quads:)``

### RDF model

- ``RDFCanonize/Quad``
- ``RDFCanonize/Term``
- ``RDFCanonize/Literal``
