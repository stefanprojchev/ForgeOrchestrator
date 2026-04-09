import Testing
import ForgeOrchestrator

@Suite("ActionID")
struct ActionIDTests {

    @Test("Creates from string")
    func fromString() {
        let id = ActionID("terms")
        #expect(id.rawValue == "terms")
    }

    @Test("Creates from RawRepresentable enum")
    func fromEnum() {
        enum TestID: String { case terms, onboarding }
        let id = ActionID(TestID.terms)
        #expect(id.rawValue == "terms")
    }

    @Test("Equal when same rawValue")
    func equality() {
        let a = ActionID("terms")
        let b = ActionID("terms")
        #expect(a == b)
    }

    @Test("Not equal when different rawValue")
    func inequality() {
        let a = ActionID("terms")
        let b = ActionID("onboarding")
        #expect(a != b)
    }

    @Test("Enum and string with same value are equal")
    func enumEqualsString() {
        enum TestID: String { case terms }
        let a = ActionID(TestID.terms)
        let b = ActionID("terms")
        #expect(a == b)
    }

    @Test("Hashable — works as dictionary key")
    func hashable() {
        let id = ActionID("test")
        var dict: [ActionID: Int] = [:]
        dict[id] = 42
        #expect(dict[id] == 42)
    }

    @Test("CustomStringConvertible")
    func description() {
        let id = ActionID("terms")
        #expect(id.description == "terms")
    }
}
