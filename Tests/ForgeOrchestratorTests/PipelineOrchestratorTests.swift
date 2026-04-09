import Testing
import Foundation
import ForgeOrchestrator

private enum PipelineTestID: String {
    case a, b, c
    case load, filter, banner
    case blocker
}

@Suite("PipelineOrchestrator")
struct PipelineOrchestratorTests {

    @Suite("Registration")
    struct Registration {

        @Test("Registers actions")
        @MainActor
        func registers() async {
            let pipeline = PipelineOrchestrator()
            pipeline.register(MockPipelineAction(id: .a, shouldRun: true, result: .completed))
            pipeline.register(MockPipelineAction(id: .b, shouldRun: true, result: .completed))

            let results = await pipeline.evaluate()
            #expect(results.count == 2)
        }

        @Test("Skips duplicate IDs")
        @MainActor
        func skipsDuplicates() async {
            let pipeline = PipelineOrchestrator()
            pipeline.register(MockPipelineAction(id: .a, shouldRun: true, result: .completed))
            pipeline.register(MockPipelineAction(id: .a, shouldRun: true, result: .completed))

            let results = await pipeline.evaluate()
            #expect(results.count == 1)
        }

        @Test("removeAll clears actions")
        @MainActor
        func removeAll() async {
            let pipeline = PipelineOrchestrator()
            pipeline.register(MockPipelineAction(id: .a, shouldRun: true, result: .completed))
            pipeline.removeAll()

            let results = await pipeline.evaluate()
            #expect(results.isEmpty)
        }
    }

    @Suite("Evaluation")
    struct Evaluation {

        @Test("Executes eligible actions only")
        @MainActor
        func eligibleOnly() async {
            let pipeline = PipelineOrchestrator()
            pipeline.register(MockPipelineAction(id: .a, shouldRun: true, result: .completed))
            pipeline.register(MockPipelineAction(id: .b, shouldRun: false, result: .completed))

            let results = await pipeline.evaluate()
            #expect(results.count == 1)
        }

        @Test("Returns results in priority order")
        @MainActor
        func priorityOrder() async {
            let pipeline = PipelineOrchestrator()
            pipeline.register(MockPipelineAction(id: .c, priority: .low, shouldRun: true, result: .completed))
            pipeline.register(MockPipelineAction(id: .a, priority: .critical, shouldRun: true, result: .skipped))
            pipeline.register(MockPipelineAction(id: .b, priority: .high, shouldRun: true, result: .failed("err")))

            let results = await pipeline.evaluate()
            #expect(results.count == 3)
            guard case .skipped = results[0] else { Issue.record("Expected skipped"); return }
            guard case .failed = results[1] else { Issue.record("Expected failed"); return }
            guard case .completed = results[2] else { Issue.record("Expected completed"); return }
        }

        @Test("Empty when no actions registered")
        @MainActor
        func empty() async {
            let pipeline = PipelineOrchestrator()
            let results = await pipeline.evaluate()
            #expect(results.isEmpty)
        }

        @Test("Tracks counts")
        @MainActor
        func tracksCounts() async {
            let pipeline = PipelineOrchestrator()
            pipeline.register(MockPipelineAction(id: .a, shouldRun: true, result: .completed))
            pipeline.register(MockPipelineAction(id: .b, shouldRun: true, result: .completed))
            pipeline.register(MockPipelineAction(id: .c, shouldRun: false, result: .completed))

            await pipeline.evaluate()

            #expect(pipeline.eligibleCount == 2)
            #expect(pipeline.completedCount == 2)
        }
    }

    @Suite("Context Sharing")
    struct ContextSharing {

        @Test("Actions share context within a pipeline run")
        @MainActor
        func sharedContext() async {
            let pipeline = PipelineOrchestrator()
            pipeline.register(ContextWriterAction(id: .load, key: "data", value: "hello"))
            pipeline.register(ContextReaderAction(id: .filter, key: "data", expectedValue: "hello"))

            let results = await pipeline.evaluate()
            guard case .completed = results[0] else { Issue.record("Writer failed"); return }
            guard case .completed = results[1] else { Issue.record("Reader failed — context not shared"); return }
        }

        @Test("Fresh context per evaluate call")
        @MainActor
        func freshContext() async {
            let pipeline = PipelineOrchestrator()
            pipeline.register(ContextWriterAction(id: .load, key: "data", value: "hello"))

            await pipeline.evaluate()

            pipeline.removeAll()
            pipeline.register(ContextReaderAction(id: .filter, key: "data", expectedValue: "hello"))

            let results = await pipeline.evaluate()
            guard case .failed = results[0] else { Issue.record("Expected failed — context should be fresh"); return }
        }
    }

    @Suite("CompletionSignal Integration")
    struct SignalIntegration {

        @Test("Action can await CompletionSignal")
        @MainActor
        func awaitsSignal() async {
            let signal = CompletionSignal()
            let pipeline = PipelineOrchestrator()
            pipeline.register(BlockingPipelineAction(id: .blocker, signal: signal))

            let task = Task { @MainActor in
                await pipeline.evaluate()
            }

            try? await Task.sleep(for: .milliseconds(50))
            #expect(pipeline.isProcessing == true)

            signal.complete()
            let results = await task.value

            #expect(results.count == 1)
            guard case .completed = results[0] else { Issue.record("Expected completed"); return }
            #expect(pipeline.isProcessing == false)
        }
    }
}

// MARK: - Test Helpers

private struct MockPipelineAction: PipelineAction {
    let id: ActionID
    let priority: ActionPriority
    let shouldRunValue: Bool
    let result: ActionResult

    init(id: PipelineTestID, priority: ActionPriority = .medium, shouldRun: Bool, result: ActionResult) {
        self.id = ActionID(id)
        self.priority = priority
        self.shouldRunValue = shouldRun
        self.result = result
    }

    func shouldRun() async -> Bool { shouldRunValue }
    func execute(context: PipelineContext) async -> ActionResult { result }
}

private struct ContextWriterAction: PipelineAction {
    let id: ActionID
    let priority: ActionPriority = .high
    let key: String
    let value: String

    init(id: PipelineTestID, key: String, value: String) {
        self.id = ActionID(id)
        self.key = key
        self.value = value
    }

    func shouldRun() async -> Bool { true }
    func execute(context: PipelineContext) async -> ActionResult {
        context.set(key, value)
        return .completed
    }
}

private struct ContextReaderAction: PipelineAction {
    let id: ActionID
    let priority: ActionPriority = .low
    let key: String
    let expectedValue: String

    init(id: PipelineTestID, key: String, expectedValue: String) {
        self.id = ActionID(id)
        self.key = key
        self.expectedValue = expectedValue
    }

    func shouldRun() async -> Bool { true }
    func execute(context: PipelineContext) async -> ActionResult {
        guard let value: String = context.get(key), value == expectedValue else {
            return .failed("Expected '\(expectedValue)' for key '\(key)'")
        }
        return .completed
    }
}

private struct BlockingPipelineAction: PipelineAction {
    let id: ActionID
    let priority: ActionPriority = .high
    let signal: CompletionSignal

    init(id: PipelineTestID, signal: CompletionSignal) {
        self.id = ActionID(id)
        self.signal = signal
    }

    func shouldRun() async -> Bool { true }
    func execute(context: PipelineContext) async -> ActionResult {
        await signal.wait()
        return .completed
    }
}
