import Testing
import Foundation
@testable import RDFCanonize

/// Edge-case coverage for the N-Quads parser. Exercises the escape
/// machinery in `NQuadsParser.unescape` / `unescapeIRI` (the public
/// surface only round-trips through the W3C suite) plus the malformed
/// inputs that must throw `ParseError` rather than crash.
@Suite("N-Quads parser edge cases")
struct NQuadsParserTests {

    // MARK: - Literal escapes

    @Test("\\uXXXX escape decodes to the BMP scalar")
    func unicode4HexEscape_inLiteral() throws {
        let line = #"<urn:s> <urn:p> "café" ."#
        let quads = try RDFCanonize.NQuadsParser.parse(line)
        try #require(quads.count == 1)
        guard case .literal(let lit) = quads[0].object else {
            Issue.record("object was not a literal: \(quads[0].object)")
            return
        }
        #expect(lit.value == "café")
    }

    @Test("\\UXXXXXXXX escape decodes to a supplementary-plane scalar")
    func unicode8HexEscape_inLiteral() throws {
        // \U0001F600 → 😀
        let line = #"<urn:s> <urn:p> "\U0001F600" ."#
        let quads = try RDFCanonize.NQuadsParser.parse(line)
        try #require(quads.count == 1)
        guard case .literal(let lit) = quads[0].object else {
            Issue.record("object was not a literal")
            return
        }
        #expect(lit.value == "😀")
    }

    @Test("Short escapes \\b \\t \\n \\f \\r \\\" \\' \\\\ all decode")
    func allShortEscapes_inLiteral() throws {
        // We build a literal with every short escape per the spec.
        let line = #"<urn:s> <urn:p> "\b\t\n\f\r\"\'\\" ."#
        let quads = try RDFCanonize.NQuadsParser.parse(line)
        try #require(quads.count == 1)
        guard case .literal(let lit) = quads[0].object else {
            Issue.record("object was not a literal")
            return
        }
        let expected = "\u{0008}\t\n\u{000C}\r\"'\\"
        #expect(lit.value == expected)
    }

    @Test("Unknown short escape preserves the escaped character")
    func unknownShortEscape_passesThroughChar() throws {
        // `\x` isn't a recognized N-Quads escape — current parser
        // returns the char after the backslash (line 149-150 in the
        // parser). Pin that behavior so it's an intentional choice.
        let line = #"<urn:s> <urn:p> "a\xb" ."#
        let quads = try RDFCanonize.NQuadsParser.parse(line)
        try #require(quads.count == 1)
        guard case .literal(let lit) = quads[0].object else {
            Issue.record("object was not a literal")
            return
        }
        #expect(lit.value == "axb")
    }

    // MARK: - IRI escapes

    @Test("\\uXXXX inside an IRI decodes")
    func unicodeEscape_inIRI() throws {
        let line = #"<http://example.org/café> <urn:p> "v" ."#
        let quads = try RDFCanonize.NQuadsParser.parse(line)
        try #require(quads.count == 1)
        guard case .iri(let s) = quads[0].subject else {
            Issue.record("subject was not an IRI")
            return
        }
        #expect(s == "http://example.org/café")
    }

    @Test("Irrelevant backslash inside an IRI is preserved")
    func irrelevantBackslash_inIRI() throws {
        // `\n` (not `\u…` / `\U…`) inside an IRI isn't an N-Quads
        // escape; the parser preserves it verbatim (NQuadsParser.swift
        // lines 175-177).
        let line = #"<http://example.org/path\n> <urn:p> "v" ."#
        let quads = try RDFCanonize.NQuadsParser.parse(line)
        try #require(quads.count == 1)
        guard case .iri(let s) = quads[0].subject else {
            Issue.record("subject was not an IRI")
            return
        }
        #expect(s == #"http://example.org/path\n"#)
    }

    // MARK: - Datatype + language tag

    @Test("Datatype IRI is decoded for typed literals")
    func typedLiteral_datatypeDecoded() throws {
        let line = #"<urn:s> <urn:p> "42"^^<http://www.w3.org/2001/XMLSchema#integer> ."#
        let quads = try RDFCanonize.NQuadsParser.parse(line)
        try #require(quads.count == 1)
        guard case .literal(let lit) = quads[0].object else {
            Issue.record("object was not a literal")
            return
        }
        #expect(lit.value == "42")
        #expect(lit.datatype == "http://www.w3.org/2001/XMLSchema#integer")
    }

    @Test("Language tag stripped from the lexical form")
    func languageTaggedLiteral() throws {
        let line = #"<urn:s> <urn:p> "hello"@en ."#
        let quads = try RDFCanonize.NQuadsParser.parse(line)
        try #require(quads.count == 1)
        guard case .literal(let lit) = quads[0].object else {
            Issue.record("object was not a literal")
            return
        }
        #expect(lit.value == "hello")
        #expect(lit.language == "en")
        #expect(lit.datatype == RDFCanonize.Literal.rdfLangString)
    }

    // MARK: - Multi-line input

    @Test("Comments and blank lines are skipped")
    func commentAndBlankLines() throws {
        let input = """
        # leading comment

        <urn:s> <urn:p> "v" .
        # mid comment
        <urn:s> <urn:p2> "v2" .

        """
        let quads = try RDFCanonize.NQuadsParser.parse(input)
        #expect(quads.count == 2)
    }

    @Test("CRLF line endings parse the same as LF")
    func crlfLineEndings() throws {
        let input = "<urn:s> <urn:p> \"v\" .\r\n<urn:s> <urn:p2> \"v2\" .\r\n"
        let quads = try RDFCanonize.NQuadsParser.parse(input)
        // `split(separator: "\n")` leaves the trailing `\r`; the
        // `trimmingCharacters(in: .whitespaces)` call at line 20 of
        // NQuadsParser.swift removes it.
        #expect(quads.count == 2)
    }

    // MARK: - Malformed input

    @Test("Unterminated IRI throws ParseError.malformedLine")
    func malformed_unterminatedIRI() {
        let line = #"<urn:s> <urn:p> <http://missing ."#
        #expect(throws: RDFCanonize.NQuadsParser.ParseError.self) {
            _ = try RDFCanonize.NQuadsParser.parse(line)
        }
    }

    @Test("Unterminated literal throws ParseError.malformedLine")
    func malformed_unterminatedLiteral() {
        let line = #"<urn:s> <urn:p> "no closing quote ."#
        #expect(throws: RDFCanonize.NQuadsParser.ParseError.self) {
            _ = try RDFCanonize.NQuadsParser.parse(line)
        }
    }

    @Test("Datatype with missing IRI throws ParseError.malformedLine")
    func malformed_datatypeMissingIRI() {
        let line = #"<urn:s> <urn:p> "v"^^missing ."#
        #expect(throws: RDFCanonize.NQuadsParser.ParseError.self) {
            _ = try RDFCanonize.NQuadsParser.parse(line)
        }
    }

    @Test("Line starting with a digit throws ParseError.malformedLine")
    func malformed_bareTerm() {
        let line = "1 <urn:p> \"v\" ."
        #expect(throws: RDFCanonize.NQuadsParser.ParseError.self) {
            _ = try RDFCanonize.NQuadsParser.parse(line)
        }
    }

    @Test("Quad with only two terms throws ParseError.malformedLine")
    func malformed_tooFewTerms() {
        let line = "<urn:s> <urn:p> ."
        #expect(throws: RDFCanonize.NQuadsParser.ParseError.self) {
            _ = try RDFCanonize.NQuadsParser.parse(line)
        }
    }

    @Test("Quad with five terms throws ParseError.malformedLine")
    func malformed_tooManyTerms() {
        let line = #"<urn:s> <urn:p> "v" <urn:g> <urn:extra> ."#
        #expect(throws: RDFCanonize.NQuadsParser.ParseError.self) {
            _ = try RDFCanonize.NQuadsParser.parse(line)
        }
    }
}
