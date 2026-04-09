import Foundation

/// Action for `SequenceOrchestrator`. Runs once, sequentially, in priority order.
///
/// `execute()` must eventually return — if it suspends indefinitely, the queue blocks.
/// Use `CompletionSignal` to bridge async/UI (e.g., wait for user to accept terms).
public protocol SequenceAction: OrchestratedAction {
    /// Performs the action. Suspends until complete.
    func execute() async
}
