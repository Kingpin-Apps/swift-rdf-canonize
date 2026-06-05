# swift-rdf-canonize

A pure-Swift implementation of [RDF Dataset Canonicalization](https://www.w3.org/TR/rdf-canon/)
(RDFC-1.0, also known as URDNA2015).

Sibling leaf of [swift-jsonld](https://github.com/Kingpin-Apps/swift-jsonld) —
this package provides only the canonicalization algorithm, mirroring the
[`rdf-canonize`](https://github.com/digitalbazaar/rdf-canonize) /
[`jsonld.js`](https://github.com/digitalbazaar/jsonld.js) split in the
JavaScript ecosystem. Use it directly when you need to hash an RDF
dataset deterministically (CIP-100 governance signatures, verifiable
credentials, etc.) without pulling in the full JSON-LD surface.

> **Status:** Full RDFC-1.0 implementation — n-degree hash recursion,
> SHA-256 and SHA-384, full N-Quads escape fidelity, and bounded-iteration
> poison-graph rejection. Every entry in the
> [W3C `rdf-canon` test suite](https://github.com/w3c/rdf-canon) passes
> on every `swift test` run.

## Quickstart

```swift
import RDFCanonize

let canonical = try RDFCanonize.canonicalize(nquads: """
_:b1 <http://example.org/p> _:b2 .
_:b2 <http://example.org/q> "leaf" .
""")
```

Blank-node labels are reassigned to `_:c14n0`, `_:c14n1`, …; quads are
emitted in lexicographic order; duplicate quads collapse. The
quads-based variant (`RDFCanonize.canonicalize(quads:)`) is the entry
point used by [swift-jsonld](https://github.com/Kingpin-Apps/swift-jsonld)'s
`JSONLD.canonize()`.

## Platforms

Pure Swift, Foundation only. iOS 14+, macOS 13+, watchOS 9+, tvOS 14+,
visionOS 1+, Linux (Swift 6.0+).

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/Kingpin-Apps/swift-rdf-canonize.git", from: "0.1.0"),
],
```

## Running the conformance suite

The W3C `rdf-canon` test suite is checked in as a git submodule:

```bash
git submodule update --init
swift test
```

## License

MIT. See [`LICENSE`](LICENSE).
