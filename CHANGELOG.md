## 0.2.0 (2026-06-05)

### Feat

- **bench**: add RDFCanonizeBench executable target

### Fix

- **parser**: split lines on CR / LF / CRLF only, not all Unicode newlines

### Test

- hardening tests beyond the 5 smoke + 86 W3C cases:
  - `NQuadsParserTests` — escape edge cases (BMP + supplementary `\u`/`\U`, short escapes, IRI escapes), CRLF, comments + blank lines, malformed input
  - `CanonicalInvariantsTests` — order independence, blank-node relabel independence, 100-run determinism
  - `PoisonGraphTests` — parameterized clique generator + `workFactor` budget enforcement
  - `IdentifierIssuerTests` — value-type copy semantics, monotonic + idempotent label issuance
  - `NQuadsWriterRoundTripTests` — parse → serialize → parse on all 64 W3C `-rdfc10.nq` expected outputs

### Performance baseline (0.2.0)

`swift run -c release RDFCanonizeBench` on Apple Silicon (arm64e-macos14):

| Scenario | iter | min | median | max |
|---|---|---|---|---|
| linearChain quads=100  blanks=0%   | 50 | 0.827 ms | 0.877 ms | 2.333 ms |
| linearChain quads=100  blanks=10%  | 50 | 1.569 ms | 1.673 ms | 1.858 ms |
| linearChain quads=100  blanks=100% | 50 | 19.903 ms | 20.619 ms | 22.960 ms |
| linearChain quads=1000 blanks=0%   | 10 | 7.183 ms | 7.632 ms | 7.792 ms |
| linearChain quads=1000 blanks=10%  | 10 | 20.645 ms | 21.181 ms | 23.601 ms |
| linearChain quads=1000 blanks=100% | 10 | 203.617 ms | 209.330 ms | 211.592 ms |
| linearChain quads=10000 blanks=0%   | 3 | 53.560 ms | 57.054 ms | 61.758 ms |
| linearChain quads=10000 blanks=10%  | 3 | 250.844 ms | 257.028 ms | 260.141 ms |
| linearChain quads=10000 blanks=100% | 3 | 2026.902 ms | 2064.765 ms | 2084.306 ms |
| symmetricCluster clusters=5 size=3 | 5 | 13.480 ms | 13.938 ms | 16.128 ms |

## 0.1.0 (2026-06-05)

### Feat

- implement full RDFC-1.0 — N-degree hash, SHA-384, escape fidelity, poison-graph defense
- implement URDNA2015 baseline
