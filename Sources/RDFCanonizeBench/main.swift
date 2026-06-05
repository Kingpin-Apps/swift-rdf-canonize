import Foundation
import RDFCanonize

/// Microbenchmark harness for `RDFCanonize.canonicalize(quads:)`.
///
/// Run with `swift run -c release RDFCanonizeBench`. Prints a markdown
/// table to stdout; the README / CHANGELOG can paste the baseline
/// numbers under `### Performance baseline (<version>)`.

print("# RDFCanonize benchmark")
print("Built: \(buildDescription())")
print()
print("| Scenario | iter | min | median | max |")
print("|---|---|---|---|---|")

let scenarios: [(name: String, iterations: Int, quads: [RDFCanonize.Quad])] = [
    ("linearChain quads=100  blanks=0%",   50, Scenarios.linearChain(quads: 100, blankPercent: 0)),
    ("linearChain quads=100  blanks=10%",  50, Scenarios.linearChain(quads: 100, blankPercent: 10)),
    ("linearChain quads=100  blanks=100%", 50, Scenarios.linearChain(quads: 100, blankPercent: 100)),
    ("linearChain quads=1000 blanks=0%",   10, Scenarios.linearChain(quads: 1000, blankPercent: 0)),
    ("linearChain quads=1000 blanks=10%",  10, Scenarios.linearChain(quads: 1000, blankPercent: 10)),
    ("linearChain quads=1000 blanks=100%", 10, Scenarios.linearChain(quads: 1000, blankPercent: 100)),
    ("linearChain quads=10000 blanks=0%",   3, Scenarios.linearChain(quads: 10_000, blankPercent: 0)),
    ("linearChain quads=10000 blanks=10%",  3, Scenarios.linearChain(quads: 10_000, blankPercent: 10)),
    ("linearChain quads=10000 blanks=100%", 3, Scenarios.linearChain(quads: 10_000, blankPercent: 100)),
    ("symmetricCluster clusters=5 size=3", 5, Scenarios.symmetricCluster(clusters: 5, perCluster: 3)),
]

for scenario in scenarios {
    do {
        let stats = try Stats.bench(
            scenario.name,
            iterations: scenario.iterations
        ) {
            _ = try RDFCanonize.canonicalize(quads: scenario.quads)
        }
        print(stats.markdownRow)
        // Flush so a long run shows progress without buffering.
        try? FileHandle.standardOutput.synchronize()
    } catch {
        print("| \(scenario.name) | — | — | — | THREW: \(error) |")
    }
}

print()
print("(All measurements use `ContinuousClock`; min/median/max over the iteration count.)")

func buildDescription() -> String {
    #if DEBUG
    return "DEBUG — re-run with -c release for representative numbers"
    #else
    return "RELEASE"
    #endif
}
