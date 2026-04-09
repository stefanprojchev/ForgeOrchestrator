import Testing
import Foundation
import ForgeOrchestrator

@Suite("PipelineContext")
struct PipelineContextTests {

    @Test("Set and get a value")
    func setAndGet() {
        let context = PipelineContext()
        context.set("count", 42)
        let value: Int? = context.get("count")
        #expect(value == 42)
    }

    @Test("Get returns nil for missing key")
    func getMissing() {
        let context = PipelineContext()
        let value: Int? = context.get("missing")
        #expect(value == nil)
    }

    @Test("Get returns nil for wrong type")
    func getWrongType() {
        let context = PipelineContext()
        context.set("count", 42)
        let value: String? = context.get("count")
        #expect(value == nil)
    }

    @Test("Remove deletes value")
    func remove() {
        let context = PipelineContext()
        context.set("count", 42)
        context.remove("count")
        let value: Int? = context.get("count")
        #expect(value == nil)
    }

    @Test("Overwrite replaces value")
    func overwrite() {
        let context = PipelineContext()
        context.set("name", "Alice")
        context.set("name", "Bob")
        let value: String? = context.get("name")
        #expect(value == "Bob")
    }

    @Test("Supports different types")
    func differentTypes() {
        let context = PipelineContext()
        context.set("count", 42)
        context.set("name", "Alice")
        context.set("flag", true)
        context.set("data", [1, 2, 3])

        #expect(context.get("count") == 42 as Int?)
        #expect(context.get("name") == "Alice" as String?)
        #expect(context.get("flag") == true as Bool?)
        #expect(context.get("data") == [1, 2, 3] as [Int]?)
    }

    @Test("Thread-safe concurrent access")
    func threadSafety() async {
        let context = PipelineContext()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    context.set("key-\(i)", i)
                }
            }
        }

        for i in 0..<100 {
            let value: Int? = context.get("key-\(i)")
            #expect(value == i)
        }
    }
}
