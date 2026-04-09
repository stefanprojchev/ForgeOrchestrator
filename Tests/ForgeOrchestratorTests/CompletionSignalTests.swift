import Testing
import Foundation
import ForgeOrchestrator

@Suite("CompletionSignal")
struct CompletionSignalTests {

    // MARK: - Basic Flow

    @Suite("Basic Flow")
    struct BasicFlow {

        @Test("wait then complete resumes")
        func waitThenComplete() async {
            let signal = CompletionSignal()

            Task {
                try? await Task.sleep(for: .milliseconds(50))
                signal.complete()
            }

            await signal.wait()
        }

        @Test("complete then wait returns immediately")
        func completeThenWait() async {
            let signal = CompletionSignal()
            signal.complete()
            await signal.wait()
        }

        @Test("wait returns immediately if already completed")
        func doubleWaitAfterComplete() async {
            let signal = CompletionSignal()
            signal.complete()
            await signal.wait()
            await signal.wait()
        }
    }

    // MARK: - Idempotency

    @Suite("Idempotency")
    struct Idempotency {

        @Test("Multiple complete calls are safe")
        func multipleComplete() {
            let signal = CompletionSignal()
            signal.complete()
            signal.complete()
            signal.complete()
        }

        @Test("Complete after wait+complete is safe")
        func completeAfterResume() async {
            let signal = CompletionSignal()

            Task {
                try? await Task.sleep(for: .milliseconds(50))
                signal.complete()
            }

            await signal.wait()
            signal.complete()
        }
    }

    // MARK: - Thread Safety

    @Suite("Thread Safety")
    struct ThreadSafety {

        @Test("Concurrent complete calls do not crash")
        func concurrentComplete() async {
            let signal = CompletionSignal()

            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<100 {
                    group.addTask {
                        signal.complete()
                    }
                }
            }
        }

        @Test("Complete from background thread resumes waiter")
        func completeFromBackground() async {
            let signal = CompletionSignal()

            Task.detached {
                try? await Task.sleep(for: .milliseconds(50))
                signal.complete()
            }

            await signal.wait()
        }

        @Test("Stress: rapid wait/complete pairs never deadlock or leak")
        func rapidWaitCompletePairs() async {
            // Create many independent signals and race the waiter vs completer.
            // If the implementation has a race between setting up the continuation
            // and storing it, some waiters would hang forever.
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<200 {
                    let signal = CompletionSignal()
                    group.addTask {
                        // Completer races the waiter.
                        Task.detached {
                            signal.complete()
                        }
                        await signal.wait()
                    }
                }
            }
        }

        @Test("Wait after concurrent completer still returns immediately")
        func waitAfterConcurrentCompleter() async {
            let signal = CompletionSignal()

            // Fire many concurrent completes before the waiter subscribes.
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<50 {
                    group.addTask { signal.complete() }
                }
            }

            // Should return immediately without suspending.
            await signal.wait()
        }
    }
}
