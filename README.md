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

> **Status: skeleton only.** The algorithm lands in Phase 5 of the
> swift-jsonld build plan. Track progress in
> [swift-jsonld#README](https://github.com/Kingpin-Apps/swift-jsonld#build-plan).

## Platforms

Pure Swift, Foundation only. iOS 14+, macOS 13+, watchOS 9+, tvOS 14+,
visionOS 1+, Linux (Swift 6.0+).

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/Kingpin-Apps/swift-rdf-canonize.git", from: "0.1.0"),
],
```

## License

MIT. See [`LICENSE`](LICENSE).
