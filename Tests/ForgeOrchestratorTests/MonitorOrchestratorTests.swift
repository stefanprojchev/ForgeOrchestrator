import Testing
import Foundation
import ForgeOrchestrator

private enum MonitorTestID: String {
    case a, b, terms, update
}

@Suite("MonitorOrchestrator")
struct MonitorOrchestratorTests {

    @Suite("Manual Reevaluate")
    struct ManualReevaluate {

        @Test("reevaluate executes eligible actions")
        @MainActor
        func executesEligible() async {
            let counter = ExecutionCounter()
            let monitor = MonitorOrchestrator()
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))
            monitor.register(CountingMonitorAction(id: .b, shouldRun: false, counter: counter))

            await monitor.reevaluate()

            let count = await counter.count
            #expect(count == 1)
        }

        @Test("reevaluate re-evaluates shouldRun every call")
        @MainActor
        func reEvaluatesEveryCall() async {
            let counter = ExecutionCounter()
            let monitor = MonitorOrchestrator()
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))

            await monitor.reevaluate()
            await monitor.reevaluate()

            let count = await counter.count
            #expect(count == 2)
        }

        @Test("reevaluate ignored while processing")
        @MainActor
        func ignoredWhileProcessing() async {
            let signal = CompletionSignal()
            let monitor = MonitorOrchestrator()
            monitor.register(BlockingMonitorAction(id: .a, signal: signal))

            let task = Task { @MainActor in
                await monitor.reevaluate()
            }

            try? await Task.sleep(for: .milliseconds(50))
            #expect(monitor.isProcessing == true)

            await monitor.reevaluate()

            signal.complete()
            await task.value

            #expect(monitor.isProcessing == false)
        }
    }

    @Suite("Screen Exclusion")
    struct ScreenExclusion {

        @Test("Skips evaluation when on excluded screen")
        @MainActor
        func skipsExcluded() async {
            let counter = ExecutionCounter()
            let monitor = MonitorOrchestrator()
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))
            monitor.setExcludedScreens(["Checkout"])
            monitor.updateCurrentScreen("Checkout")

            await monitor.reevaluate()

            let count = await counter.count
            #expect(count == 0)
        }

        @Test("Evaluates when on non-excluded screen")
        @MainActor
        func evaluatesNonExcluded() async {
            let counter = ExecutionCounter()
            let monitor = MonitorOrchestrator()
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))
            monitor.setExcludedScreens(["Checkout"])
            monitor.updateCurrentScreen("Dashboard")

            await monitor.reevaluate()

            let count = await counter.count
            #expect(count == 1)
        }

        @Test("Evaluates when currentScreen is nil")
        @MainActor
        func evaluatesWhenNil() async {
            let counter = ExecutionCounter()
            let monitor = MonitorOrchestrator()
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))
            monitor.setExcludedScreens(["Checkout"])

            await monitor.reevaluate()

            let count = await counter.count
            #expect(count == 1)
        }
    }

    @Suite("Interval")
    struct Interval {

        @Test("start triggers periodic reevaluation")
        @MainActor
        func periodicReevaluation() async {
            let counter = ExecutionCounter()
            let monitor = MonitorOrchestrator(interval: 0.1)
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))

            monitor.start()
            try? await Task.sleep(for: .milliseconds(350))
            monitor.stop()

            let count = await counter.count
            #expect(count >= 2)
        }

        @Test("stop cancels the interval loop")
        @MainActor
        func stopCancels() async {
            let counter = ExecutionCounter()
            let monitor = MonitorOrchestrator(interval: 0.1)
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))

            monitor.start()
            try? await Task.sleep(for: .milliseconds(150))
            monitor.stop()

            let countAtStop = await counter.count
            try? await Task.sleep(for: .milliseconds(300))
            let countAfter = await counter.count

            #expect(countAtStop == countAfter)
        }
    }

    @Suite("Registration")
    struct Registration {

        @Test("Skips duplicate IDs")
        @MainActor
        func skipsDuplicates() async {
            let counter = ExecutionCounter()
            let monitor = MonitorOrchestrator()
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))

            await monitor.reevaluate()

            let count = await counter.count
            #expect(count == 1)
        }

        @Test("removeAll clears actions")
        @MainActor
        func removeAll() async {
            let counter = ExecutionCounter()
            let monitor = MonitorOrchestrator()
            monitor.register(CountingMonitorAction(id: .a, shouldRun: true, counter: counter))
            monitor.removeAll()

            await monitor.reevaluate()

            let count = await counter.count
            #expect(count == 0)
        }
    }
}

// MARK: - Test Helpers

private actor ExecutionCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

private struct CountingMonitorAction: MonitorAction {
    let id: ActionID
    let priority: ActionPriority = .medium
    let shouldRunValue: Bool
    let counter: ExecutionCounter

    init(id: MonitorTestID, shouldRun: Bool, counter: ExecutionCounter) {
        self.id = ActionID(id)
        self.shouldRunValue = shouldRun
        self.counter = counter
    }

    func shouldRun() async -> Bool { shouldRunValue }
    func execute() async { await counter.increment() }
}

private struct BlockingMonitorAction: MonitorAction {
    let id: ActionID
    let priority: ActionPriority = .high
    let signal: CompletionSignal

    init(id: MonitorTestID, signal: CompletionSignal) {
        self.id = ActionID(id)
        self.signal = signal
    }

    func shouldRun() async -> Bool { true }
    func execute() async { await signal.wait() }
}
