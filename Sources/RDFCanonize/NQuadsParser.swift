import Foundation

extension RDFCanonize {
    /// Minimal N-Quads parser. Follows the [RDF 1.1 N-Quads grammar](https://www.w3.org/TR/n-quads/#sec-grammar)
    /// closely enough for the W3C rdf-canon test suite. Permissive
    /// rather than strict — invalid lines are skipped.
    enum NQuadsParser {
        enum ParseError: Error, CustomStringConvertible {
            case malformedLine(String)
            var description: String {
                switch self {
                case .malformedLine(let s): return "malformed N-Quads line: \(s)"
                }
            }
        }

        static func parse(_ input: String) throws -> [Quad] {
            var quads: [Quad] = []
            for raw in input.split(separator: "\n", omittingEmptySubsequences: false) {
                var line = String(raw).trimmingCharacters(in: .whitespaces)
                // Strip trailing dot (and any whitespace before it).
                if line.hasSuffix(".") {
                    line = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
                }
                if line.isEmpty || line.hasPrefix("#") { continue }
                let terms = try tokenize(line)
                guard terms.count == 3 || terms.count == 4 else {
                    throw ParseError.malformedLine(line)
                }
                quads.append(Quad(
                    subject: terms[0],
                    predicate: terms[1],
                    object: terms[2],
                    graph: terms.count == 4 ? terms[3] : nil
                ))
            }
            return quads
        }

        /// Tokenize a single (already dot-trimmed) N-Quads line into
        /// 3 or 4 RDF terms.
        private static func tokenize(_ line: String) throws -> [Term] {
            var out: [Term] = []
            var idx = line.startIndex
            let end = line.endIndex
            while idx < end {
                // Skip whitespace.
                while idx < end, line[idx].isWhitespace { idx = line.index(after: idx) }
                guard idx < end else { break }

                let ch = line[idx]
                if ch == "<" {
                    // IRI: <...>
                    guard let close = line.range(of: ">", range: idx..<end) else {
                        throw ParseError.malformedLine(line)
                    }
                    let iri = String(line[line.index(after: idx)..<close.lowerBound])
                    out.append(.iri(iri))
                    idx = close.upperBound
                } else if ch == "_" {
                    // Blank node: _:label
                    var labelEnd = line.index(after: idx)
                    if labelEnd < end, line[labelEnd] == ":" {
                        labelEnd = line.index(after: labelEnd)
                    }
                    while labelEnd < end, !line[labelEnd].isWhitespace {
                        labelEnd = line.index(after: labelEnd)
                    }
                    out.append(.blankNode(String(line[idx..<labelEnd])))
                    idx = labelEnd
                } else if ch == "\"" {
                    // Literal: "lex"[^^<dt>|@lang][@dir? — 1.1 not parsed]
                    let lexStart = line.index(after: idx)
                    var i = lexStart
                    var escaped = false
                    while i < end {
                        if escaped { escaped = false; i = line.index(after: i); continue }
                        if line[i] == "\\" { escaped = true; i = line.index(after: i); continue }
                        if line[i] == "\"" { break }
                        i = line.index(after: i)
                    }
                    guard i < end else { throw ParseError.malformedLine(line) }
                    let lex = unescape(String(line[lexStart..<i]))
                    var datatype = Literal.xsdString
                    var lang: String? = nil
                    idx = line.index(after: i) // step past closing "
                    if idx < end, line[idx] == "@" {
                        idx = line.index(after: idx)
                        var langEnd = idx
                        while langEnd < end, !line[langEnd].isWhitespace { langEnd = line.index(after: langEnd) }
                        lang = String(line[idx..<langEnd])
                        datatype = Literal.rdfLangString
                        idx = langEnd
                    } else if idx < end, line[idx] == "^",
                              line.index(after: idx) < end,
                              line[line.index(after: idx)] == "^"
                    {
                        idx = line.index(idx, offsetBy: 2)
                        guard idx < end, line[idx] == "<",
                              let close = line.range(of: ">", range: idx..<end)
                        else { throw ParseError.malformedLine(line) }
                        datatype = String(line[line.index(after: idx)..<close.lowerBound])
                        idx = close.upperBound
                    }
                    out.append(.literal(Literal(value: lex, datatype: datatype, language: lang)))
                } else {
                    throw ParseError.malformedLine(line)
                }
            }
            return out
        }

        private static func unescape(_ s: String) -> String {
            var out = ""
            out.reserveCapacity(s.count)
            var iter = s.makeIterator()
            while let ch = iter.next() {
                if ch != "\\" { out.append(ch); continue }
                guard let next = iter.next() else { out.append(ch); break }
                switch next {
                case "n": out.append("\n")
                case "r": out.append("\r")
                case "t": out.append("\t")
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                default: out.append(next)
                }
            }
            return out
        }
    }
}
