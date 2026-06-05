import Testing
@testable import RDFCanonize

@Test("Namespace exists")
func namespaceExists() {
    _ = RDFCanonize.self
}
