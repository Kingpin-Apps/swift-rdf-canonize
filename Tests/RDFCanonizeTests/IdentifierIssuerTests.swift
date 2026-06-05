import Testing
@testable import RDFCanonize

/// `IdentifierIssuer` is a value-typed struct used by the n-degree
/// permutation search — a copy is taken before each tentative
/// permutation, then discarded if the permutation isn't optimal.
/// These tests pin the value-type semantics that property depends on.
@Suite("IdentifierIssuer value semantics")
struct IdentifierIssuerTests {

    @Test("Mutation on a copy doesn't affect the original")
    func valueSemantics_copyDoesNotShareState() {
        var original = RDFCanonize.IdentifierIssuer(prefix: "b")
        _ = original.getId("_:input0")
        var copy = original
        _ = copy.getId("_:input1")
        // The copy issued two labels; the original still has issued only
        // one. If the underlying storage were reference-typed the
        // original would see `_:input1` too.
        #expect(original.issuedOrder == ["_:input0"])
        #expect(copy.issuedOrder == ["_:input0", "_:input1"])
    }

    @Test("Successive distinct inputs yield monotonically-numbered labels")
    func monotonicIssue_acrossDistinctInputs() {
        var issuer = RDFCanonize.IdentifierIssuer(prefix: "c14n")
        let labels = ["_:a", "_:b", "_:c"].map { issuer.getId($0) }
        #expect(labels == ["_:c14n0", "_:c14n1", "_:c14n2"])
    }

    @Test("Same input twice returns the same issued label")
    func idempotentIssue_sameInputReturnsSameId() {
        var issuer = RDFCanonize.IdentifierIssuer(prefix: "c14n")
        let first = issuer.getId("_:x")
        let second = issuer.getId("_:x")
        #expect(first == second)
        #expect(issuer.issuedOrder == ["_:x"])
    }

    @Test("hasId() reflects existing assignments")
    func hasId_tracksIssuedInputs() {
        var issuer = RDFCanonize.IdentifierIssuer(prefix: "b")
        #expect(!issuer.hasId("_:y"))
        _ = issuer.getId("_:y")
        #expect(issuer.hasId("_:y"))
        #expect(!issuer.hasId("_:z"))
    }
}
