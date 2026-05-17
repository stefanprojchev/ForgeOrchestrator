import Foundation

/// Action for `MonitorOrchestrator`. Re-evaluated periodically or on demand.
///
/// Same `execute()` signature as `SequenceAction`. The difference is in how the
/// orchestrator drives it — the monitor keeps re-evaluating, the sequence runs once.
public protocol MonitorAction: OrchestratedAction {
    /// Performs the action. Suspends until complete.
    func execute() async
}
