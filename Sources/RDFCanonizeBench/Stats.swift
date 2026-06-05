import Foundation

/// Run `body` `iterations` times and capture min / median / max wall
/// time via `ContinuousClock`. Throws if `body` throws.
///
/// Avoids any external dependency (the sister `swift-numerics` is
/// kept out of `Package.swift`) — sorting the captured samples is
/// enough for a baseline-tracking microbench.
struct Stats {
    let name: String
    let iterations: Int
    let min: Duration
    let median: Duration
    let max: Duration

    static func bench(
        _ name: String,
        iterations: Int,
        body: () throws -> Void
    ) rethrows -> Stats {
        precondition(iterations > 0, "iterations must be positive")
        let clock = ContinuousClock()
        var samples: [Duration] = []
        samples.reserveCapacity(iterations)
        for _ in 0..<iterations {
            let elapsed = try clock.measure { try body() }
            samples.append(elapsed)
        }
        samples.sort()
        let mid = samples[samples.count / 2]
        return Stats(
            name: name,
            iterations: iterations,
            min: samples.first!,
            median: mid,
            max: samples.last!
        )
    }

    /// Markdown table row: name, iterations, min, median, max.
    var markdownRow: String {
        "| \(name) | \(iterations) | \(format(min)) | \(format(median)) | \(format(max)) |"
    }

    private func format(_ d: Duration) -> String {
        // Render in ms with three decimals — `Duration.formatted` would
        // require macOS 13.5+ and adds locale variance. Use the
        // component arithmetic instead.
        let components = d.components
        let totalNanos = components.seconds * 1_000_000_000
            + components.attoseconds / 1_000_000_000
        let ms = Double(totalNanos) / 1_000_000.0
        return String(format: "%.3f ms", ms)
    }
}
