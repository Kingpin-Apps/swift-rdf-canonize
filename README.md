# swift-rdf-canonize

A pure-Swift implementation of [RDF Dataset Canonicalization](https://www.w3.org/TR/rdf-canon/)
(RDFC-1.0, also known as URDNA2015) — the algorithm that turns any RDF
dataset into a stable, byte-for-byte canonical N-Quads string suitable
for hashing or signing.

[![Swift 6](https://img.shields.io/badge/Swift-6.0%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20visionOS%20%7C%20Linux-blue.svg)](Package.swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

- **Spec-compliant.** Every entry in the [W3C `rdf-canon`](https://github.com/w3c/rdf-canon)
  conformance suite — all 86 tests, including SHA-384, full N-Quads
  escape fidelity, and the negative poison-graph test — passes on every
  `swift test` run.
- **Pure Swift.** `Foundation` + [swift-crypto](https://github.com/apple/swift-crypto),
  nothing else. Same code on Apple platforms and Linux; no FFI, no
  bridging headers, no JavaScript or C runtime.
- **Hardened beyond the spec.** ~180 in-house cases on top of the W3C
  suite: parser edge-cases, blank-node relabel independence, multi-run
  determinism, parameterized poison-graph generators with
  iteration-budget enforcement, full parse → serialize → parse round-trip
  on every expected output.
- **Benchmarked.** Reproducible numbers in [`CHANGELOG.md`](CHANGELOG.md);
  run the bench target locally to confirm — see
  [Benchmarks](#benchmarks).

## Quickstart

```swift
import RDFCanonize

let canonical = try RDFCanonize.canonicalize(nquads: """
_:b1 <http://example.org/p> _:b2 .
_:b2 <http://example.org/q> "leaf" .
""")
// → "_:c14n0 <http://example.org/p> _:c14n1 .\n_:c14n1 <http://example.org/q> \"leaf\" .\n"
```

Blank-node labels are reassigned to `_:c14n0`, `_:c14n1`, …; quads are
emitted in lexicographic order; duplicate quads collapse.

If you already have parsed quads — for example from a JSON-LD `toRdf`
pass — skip the parser:

```swift
let canonical = try RDFCanonize.canonicalize(quads: quads)
```

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/Kingpin-Apps/swift-rdf-canonize.git", from: "0.2.0"),
],
```

Then add `RDFCanonize` to your target's dependencies:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "RDFCanonize", package: "swift-rdf-canonize"),
]),
```

## Platforms

iOS 14+, macOS 13+, watchOS 9+, tvOS 14+, visionOS 1+, and Linux on
Swift 6.0+. Strict-concurrency clean (compiled at
`swiftLanguageModes: [.v6]`).

## Hash algorithm

SHA-256 by default, as the spec stipulates. Pass `hashAlgorithm: .sha384`
to opt into the alternative defined in [RDFC-1.0 §6](https://www.w3.org/TR/rdf-canon/#dfn-hash-algorithm).

```swift
let canonical = try RDFCanonize.canonicalize(
    nquads: input,
    hashAlgorithm: .sha384
)
```

## Poison-graph defense

Trusted inputs canonicalize without a bound — that's the default
(`workFactor: .max`). Pass a finite `workFactor` to reject inputs whose
symmetric topology would explode the N-Degree Hash recursion. The
deep-iteration budget is `nonUniqueBlankNodeCount ^ workFactor`;
exceeding it throws `RDFCanonize.CanonicalizeError.iterationLimitExceeded`.

```swift
do {
    let canonical = try RDFCanonize.canonicalize(
        nquads: untrustedInput,
        workFactor: 1  // tight bound — rejects poison cliques
    )
} catch RDFCanonize.CanonicalizeError.iterationLimitExceeded {
    // Input was symmetric beyond what we'll spend cycles on.
}
```

## Conformance suite

The [W3C `rdf-canon` test suite](https://github.com/w3c/rdf-canon) is
checked in as a git submodule:

```bash
git submodule update --init
swift test
```

All 86 manifest entries pass on every run. The harness lives in
[`Tests/RDFCanonizeTests/W3CSuite/`](Tests/RDFCanonizeTests/W3CSuite/);
each conformance entry becomes a parameterized Swift Testing case
mapping the manifest's `computationalComplexity` tag to the appropriate
`workFactor`.

## Benchmarks

```bash
swift run -c release RDFCanonizeBench
```

Baseline numbers for the 0.2.0 release are recorded in
[`CHANGELOG.md`](CHANGELOG.md). Scenarios cover linear-chain datasets
from 100 to 10,000 quads at 0%, 10%, and 100% blank-node density,
plus a symmetric-cluster generator that exercises the n-degree hash
recursion.

## Use cases

Canonicalization is the prerequisite for any deterministic hash or
signature over linked-data documents:

- **CIP-100** Cardano governance metadata signed by SPOs, dReps, and
  CC members.
- **W3C Verifiable Credentials** and other linked-data proofs.
- **DID document** integrity hashes.
- Any audit trail or merkleization scheme over JSON-LD / RDF datasets.

When called from JSON-LD, the [`canonicalize(quads:)`](Sources/RDFCanonize/RDFCanonize.swift)
entry point accepts already-materialized quads to avoid an unnecessary
N-Quads round-trip.

## License

MIT. See [`LICENSE`](LICENSE).
