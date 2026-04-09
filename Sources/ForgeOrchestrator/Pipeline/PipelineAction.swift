import Foundation

/// Action for `PipelineOrchestrator`. Sequential with results and shared context.
///
/// Each action receives a `PipelineContext` for inter-action data passing
/// and returns an `ActionResult` indicating what happened.
public protocol PipelineAction: OrchestratedAction {
    /// Performs the action with shared context and returns a result.
    func execute(context: PipelineContext) async -> ActionResult
}
