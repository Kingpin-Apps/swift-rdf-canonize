# ``RDFCanonize``

Pure-Swift, spec-conformant, benchmarked canonicalization of RDF datasets.

## Overview

`RDFCanonize` implements [RDF Dataset Canonicalization (RDFC-1.0)](https://www.w3.org/TR/rdf-canon/) —
also published as URDNA2015 — the W3C Recommendation that turns any RDF
dataset into a stable, byte-for-byte canonical N-Quads string.
Canonicalization is the prerequisite for hashing or signing
linked-data: two datasets with the same RDF semantics produce the same
canonical bytes regardless of the input's blank-node label choice,
triple order, or duplicate quads.

The implementation is pure Swift on top of `Foundation` and
[swift-crypto](https://github.com/apple/swift-crypto), with no other
runtime dependencies — the same code runs on every supported Apple
platform and on Linux.

### Conformance

Every entry in the
[W3C `rdf-canon` test suite](https://github.com/w3c/rdf-canon) passes
on every `swift test` run. That includes the full N-Degree Hash
recursion for symmetric blank-node graphs ([§4.8](https://www.w3.org/TR/rdf-canon/#hash-nd-quads)),
both spec-mandated hash algorithms (SHA-256 default, SHA-384 opt-in),
the canonical N-Quads escape rules for every code-point class
([test #060](https://w3c.github.io/rdf-canon/tests/rdfc10/test060-in.nq)),
and the bounded-iteration safeguard that lets the algorithm reject
poison-graph inputs ([test #074](https://w3c.github.io/rdf-canon/tests/rdfc10/test074-in.nq)).

Beyond the W3C suite, the test target carries ~180 in-house cases
covering parser escape edge-cases, blank-node relabel independence,
multi-run determinism, parameterized poison-graph generators, and a
full parse → serialize → parse round-trip on every expected output in
the suite.

### Strict concurrency

Compiled at `swiftLanguageModes: [.v6]` — types are `Sendable` and
`Hashable` where the API exposes them, and there are no implicit-actor
warnings on any supported platform.

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

If you already have ``RDFCanonize/Quad`` values, skip the parser and
call ``RDFCanonize/canonicalize(quads:hashAlgorithm:workFactor:)``
directly:

```swift
let quads: [RDFCanonize.Quad] = …
let canonical = try RDFCanonize.canonicalize(quads: quads)
```

This is the path JSON-LD callers should take after their `toRdf` pass
materializes the document — it avoids an unnecessary N-Quads
round-trip.

## Hash algorithm

The default is SHA-256, as the spec stipulates. Pass `hashAlgorithm: .sha384`
to opt into the alternative defined in
[RDFC-1.0 §6](https://www.w3.org/TR/rdf-canon/#dfn-hash-algorithm):

```swift
let canonical = try RDFCanonize.canonicalize(
    nquads: input,
    hashAlgorithm: .sha384
)
```

## Poison-graph defense

Trusted inputs canonicalize without a bound (`workFactor: .max`, the
default). To reject inputs whose symmetric topology would explode the
N-Degree Hash recursion, pass a finite `workFactor`. The deep-iteration
budget is then `nonUniqueBlankNodeCount ^ workFactor`; exceeding it
raises ``RDFCanonize/CanonicalizeError/iterationLimitExceeded(limit:)``.

```swift
do {
    let canonical = try RDFCanonize.canonicalize(
        nquads: untrustedInput,
        workFactor: 1
    )
} catch RDFCanonize.CanonicalizeError.iterationLimitExceeded(let limit) {
    // Input would have required more than `limit` N-Degree iterations.
}
```

The conformance test runner mirrors the W3C suite's mapping from
`computationalComplexity` to workFactor: `low → 0`, `medium → 2`,
`high → 3`.

## Performance

Benchmarks for each release live in [`CHANGELOG.md`](https://github.com/Kingpin-Apps/swift-rdf-canonize/blob/main/CHANGELOG.md).
Run them yourself with:

```bash
swift run -c release RDFCanonizeBench
```

Scenarios cover linear-chain datasets from 100 to 10,000 quads at 0%,
10%, and 100% blank-node density, plus a symmetric-cluster generator
that exercises the n-degree hash recursion.

## Algorithm reference

The algorithm is defined by the W3C Recommendation. Rather than
reproduce it here, refer to the source:

- [RDF Dataset Canonicalization (RDFC-1.0)](https://www.w3.org/TR/rdf-canon/) — the spec.
- [§4.7 Hash First Degree Quads](https://www.w3.org/TR/rdf-canon/#hash-first-degree-quads)
- [§4.8 Hash N-Degree Quads](https://www.w3.org/TR/rdf-canon/#hash-nd-quads)
- [RDF 1.1 N-Quads](https://www.w3.org/TR/n-quads/) — the input/output format.

## Topics

### Canonicalization

- ``RDFCanonize/canonicalize(nquads:hashAlgorithm:workFactor:)``
- ``RDFCanonize/canonicalize(quads:hashAlgorithm:workFactor:)``

### Options

- ``RDFCanonize/HashAlgorithm``
- ``RDFCanonize/CanonicalizeError``

### RDF model

- ``RDFCanonize/Quad``
- ``RDFCanonize/Term``
- ``RDFCanonize/Literal``
