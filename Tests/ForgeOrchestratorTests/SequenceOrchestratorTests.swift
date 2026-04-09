import Testing
import Foundation
import ForgeOrchestrator

private enum TestID: String {
    case a, b, c
    case run, skip
    case critical, high, medium, low
    case first, second, third
    case blocker
}

@Suite("SequenceOrchestrator")
struct SequenceOrchestratorTests {

    @Suite("Registration")
    struct Registration {

        @Test("Registers actions")
        @MainActor
        func registers() async {
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(MockSequenceAction(id: .a, priority: .high, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .b, priority: .low, shouldRun: true))

            let ids = await orchestrator.evaluate()
            #expect(ids.count == 2)
        }

        @Test("Skips duplicate IDs")
        @MainActor
        func skipsDuplicates() async {
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(MockSequenceAction(id: .a, priority: .high, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .a, priority: .low, shouldRun: true))

            let ids = await orchestrator.evaluate()
            #expect(ids == [ActionID(TestID.a)])
        }

        @Test("removeAll clears actions")
        @MainActor
        func removeAll() async {
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(MockSequenceAction(id: .a, priority: .high, shouldRun: true))
            orchestrator.removeAll()

            let ids = await orchestrator.evaluate()
            #expect(ids.isEmpty)
        }
    }

    @Suite("Evaluation")
    struct Evaluation {

        @Test("Executes eligible actions only")
        @MainActor
        func eligibleOnly() async {
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(MockSequenceAction(id: .run, priority: .high, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .skip, priority: .high, shouldRun: false))

            let ids = await orchestrator.evaluate()
            #expect(ids == [ActionID(TestID.run)])
        }

        @Test("Returns empty when no actions registered")
        @MainActor
        func empty() async {
            let orchestrator = SequenceOrchestrator()
            let ids = await orchestrator.evaluate()
            #expect(ids.isEmpty)
        }

        @Test("Returns empty when all actions skip")
        @MainActor
        func allSkip() async {
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(MockSequenceAction(id: .a, priority: .high, shouldRun: false))
            orchestrator.register(MockSequenceAction(id: .b, priority: .low, shouldRun: false))

            let ids = await orchestrator.evaluate()
            #expect(ids.isEmpty)
        }
    }

    @Suite("Priority Ordering")
    struct PriorityOrdering {

        @Test("Executes in priority order (critical first)")
        @MainActor
        func priorityOrder() async {
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(MockSequenceAction(id: .low, priority: .low, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .critical, priority: .critical, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .medium, priority: .medium, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .high, priority: .high, shouldRun: true))

            let ids = await orchestrator.evaluate()
            #expect(ids == [
                ActionID(TestID.critical),
                ActionID(TestID.high),
                ActionID(TestID.medium),
                ActionID(TestID.low),
            ])
        }

        @Test("Preserves registration order within same priority")
        @MainActor
        func samePriorityOrder() async {
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(MockSequenceAction(id: .first, priority: .high, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .second, priority: .high, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .third, priority: .high, shouldRun: true))

            let ids = await orchestrator.evaluate()
            #expect(ids == [
                ActionID(TestID.first),
                ActionID(TestID.second),
                ActionID(TestID.third),
            ])
        }
    }

    @Suite("Re-entrancy")
    struct Reentrancy {

        @Test("Ignores concurrent evaluate calls")
        @MainActor
        func ignoresConcurrent() async {
            let signal = CompletionSignal()
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(BlockingSequenceAction(id: .blocker, signal: signal))

            let task = Task { @MainActor in
                await orchestrator.evaluate()
            }

            try? await Task.sleep(for: .milliseconds(50))

            let secondResult = await orchestrator.evaluate()
            #expect(secondResult.isEmpty)

            signal.complete()
            await task.value
        }
    }

    @Suite("Observable State")
    struct ObservableState {

        @Test("isProcessing is true during evaluation")
        @MainActor
        func isProcessingDuringEval() async {
            let signal = CompletionSignal()
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(BlockingSequenceAction(id: .blocker, signal: signal))

            #expect(orchestrator.isProcessing == false)

            let task = Task { @MainActor in
                await orchestrator.evaluate()
            }

            try? await Task.sleep(for: .milliseconds(50))
            #expect(orchestrator.isProcessing == true)

            signal.complete()
            await task.value

            #expect(orchestrator.isProcessing == false)
        }

        @Test("Tracks eligible and completed counts")
        @MainActor
        func tracksCounts() async {
            let orchestrator = SequenceOrchestrator()
            orchestrator.register(MockSequenceAction(id: .a, priority: .high, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .b, priority: .low, shouldRun: true))
            orchestrator.register(MockSequenceAction(id: .c, priority: .medium, shouldRun: false))

            await orchestrator.evaluate()

            #expect(orchestrator.eligibleCount == 2)
            #expect(orchestrator.completedCount == 2)
        }
    }
}

// MARK: - Test Helpers

private struct MockSequenceAction: SequenceAction {
    let id: ActionID
    let priority: ActionPriority
    let shouldRunValue: Bool

    init(id: TestID, priority: ActionPriority, shouldRun: Bool) {
        self.id = ActionID(id)
        self.priority = priority
        self.shouldRunValue = shouldRun
    }

    func shouldRun() async -> Bool { shouldRunValue }
    func execute() async {}
}

private struct BlockingSequenceAction: SequenceAction {
    let id: ActionID
    let priority: ActionPriority = .high
    let signal: CompletionSignal

    init(id: TestID, signal: CompletionSignal) {
        self.id = ActionID(id)
        self.signal = signal
    }

    func shouldRun() async -> Bool { true }
    func execute() async { await signal.wait() }
}
