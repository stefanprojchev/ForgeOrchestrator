import Foundation

/// Base protocol for all orchestrated action types.
///
/// Defines identity, priority, and condition. Refined by `SequenceAction`,
/// `MonitorAction`, and `PipelineAction` which add their own `execute()`.
public protocol OrchestratedAction: Sendable {
    /// Unique identifier for this action. Used for logging and deduplication.
    var id: ActionID { get }

    /// The execution priority. Lower values run first.
    var priority: ActionPriority { get }

    /// Whether this action should run.
    func shouldRun() async -> Bool
}
