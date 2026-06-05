import Testing
@testable import RDFCanonize

@Suite("RDFCanonize round-trip")
struct RDFCanonizeTests {
    @Test("Empty input → empty output")
    func empty() throws {
        let out = try RDFCanonize.canonicalize(nquads: "")
        #expect(out == "")
    }

    @Test("No blank nodes → quads sort lexicographically")
    func noBlankNodes() throws {
        let input = """
        <http://example.org/b> <http://example.org/p> "v2" .
        <http://example.org/a> <http://example.org/p> "v1" .
        """
        let out = try RDFCanonize.canonicalize(nquads: input)
        let expected = """
        <http://example.org/a> <http://example.org/p> "v1" .
        <http://example.org/b> <http://example.org/p> "v2" .

        """
        #expect(out == expected)
    }

    @Test("Single blank node gets _:c14n0")
    func singleBlankNode() throws {
        let input = """
        _:foo <http://example.org/p> "value" .
        """
        let out = try RDFCanonize.canonicalize(nquads: input)
        let expected = """
        _:c14n0 <http://example.org/p> "value" .

        """
        #expect(out == expected)
    }

    @Test("Multiple distinct blank nodes get distinct canonical labels")
    func multipleBlankNodes() throws {
        let input = """
        _:foo <http://example.org/name> "Alice" .
        _:bar <http://example.org/name> "Bob" .
        """
        let out = try RDFCanonize.canonicalize(nquads: input)
        // Both should map to _:c14n0 / _:c14n1; the assignment order is
        // hash-driven so we just check structure.
        #expect(out.contains("_:c14n0"))
        #expect(out.contains("_:c14n1"))
        #expect(out.contains("\"Alice\""))
        #expect(out.contains("\"Bob\""))
    }

    @Test("Same input → same output (determinism)")
    func deterministic() throws {
        let input = """
        _:b1 <http://example.org/p> _:b2 .
        _:b2 <http://example.org/q> "leaf" .
        """
        let first = try RDFCanonize.canonicalize(nquads: input)
        let second = try RDFCanonize.canonicalize(nquads: input)
        #expect(first == second)
    }
}
