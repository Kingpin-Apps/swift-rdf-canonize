import Foundation

extension RDFCanonize {
    /// Serializer for RDF terms and quads in N-Quads form.
    enum NQuadsWriter {
        static func serialize(quads: [Quad]) -> String {
            var lines: [String] = []
            for q in quads { lines.append(serialize(quad: q)) }
            return lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        }

        static func serialize(quad: Quad) -> String {
            var s = "\(serialize(term: quad.subject)) \(serialize(term: quad.predicate)) \(serialize(term: quad.object))"
            if let g = quad.graph { s += " \(serialize(term: g))" }
            s += " ."
            return s
        }

        static func serialize(term: Term) -> String {
            switch term {
            case .iri(let iri):
                return "<\(iri)>"
            case .blankNode(let id):
                return id.hasPrefix("_:") ? id : "_:\(id)"
            case .literal(let lit):
                var s = "\"\(escape(lit.value))\""
                if let lang = lit.language {
                    s += "@\(lang)"
                } else if lit.datatype != Literal.xsdString {
                    s += "^^<\(lit.datatype)>"
                }
                return s
            }
        }

        private static func escape(_ s: String) -> String {
            var out = ""
            out.reserveCapacity(s.count)
            for ch in s {
                switch ch {
                case "\\": out += "\\\\"
                case "\"": out += "\\\""
                case "\n": out += "\\n"
                case "\r": out += "\\r"
                case "\t": out += "\\t"
                default: out.append(ch)
                }
            }
            return out
        }
    }
}
