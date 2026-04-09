import Foundation

/// The outcome of a pipeline action execution.
public enum ActionResult: Sendable {
    /// The action completed successfully.
    case completed
    /// The action was skipped (precondition not met during execution).
    case skipped
    /// The action failed with a reason.
    case failed(String)
}
