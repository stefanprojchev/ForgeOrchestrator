import ForgeCore
import Foundation

/// Bridges async orchestration with UI completion events.
///
/// The action creates a signal, passes it to UI, and `await`s it.
/// The UI calls `complete()` when the user is done. Thread-safe, idempotent.
///
/// Single-waiter only — calling `wait()` concurrently from multiple callers is not supported.
public final class CompletionSignal: @unchecked Sendable {

    // MARK: - Properties

    private struct State {
        var continuation: CheckedContinuation<Void, Never>?
        var isCompleted = false
    }

    private let state = LockedState(State())

    // MARK: - Initialization

    public init() {}

    // MARK: - Implementation

    /// Suspends until `complete()` is called. Returns immediately if already completed.
    ///
    /// Must only be called once. Calling from multiple concurrent callers is not supported.
    public func wait() async {
        if state.withLock({ $0.isCompleted }) { return }

        await withCheckedContinuation { cont in
            let shouldResumeImmediately = state.withLock {
                if $0.isCompleted { return true }
                precondition($0.continuation == nil, "CompletionSignal.wait() called concurrently — only one waiter is supported")
                $0.continuation = cont
                return false
            }

            if shouldResumeImmediately {
                cont.resume()
            }
        }
    }

    /// Signals completion. Safe to call from any thread. Multiple calls are no-ops.
    public func complete() {
        let cont: CheckedContinuation<Void, Never>? = state.withLock {
            guard !$0.isCompleted else { return nil }
            $0.isCompleted = true
            let c = $0.continuation
            $0.continuation = nil
            return c
        }
        cont?.resume()
    }
}
