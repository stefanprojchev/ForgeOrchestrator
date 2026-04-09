import Foundation
import OSLog

/// Orchestrates actions sequentially with results and shared context.
///
/// Each action receives a `PipelineContext` for inter-action data passing
/// and returns an `ActionResult`. One context is created per `evaluate()` call.
///
/// ```swift
/// let pipeline = PipelineOrchestrator()
/// pipeline.register(LoadPostsAction())
/// pipeline.register(FilterPostsAction())
/// pipeline.register(ShowBannerAction())
/// let results = await pipeline.evaluate()
/// ```
@Observable
@MainActor
open class PipelineOrchestrator {

    // MARK: - Properties

    private let logger = Logger(subsystem: "forge.orchestrator", category: "pipeline")

    /// Whether the pipeline is currently executing.
    public private(set) var isProcessing = false

    /// The ID of the currently executing action, or `nil` if idle.
    public private(set) var currentActionId: ActionID?

    /// Number of eligible actions found during the last evaluation.
    public private(set) var eligibleCount = 0

    /// Number of actions completed so far in the current evaluation.
    public private(set) var completedCount = 0

    /// Results from the last evaluation, in execution order.
    public private(set) var results: [ActionResult] = []

    @ObservationIgnored
    private var actions: [any PipelineAction] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Implementation

    /// Registers a pipeline action. Duplicates (same ID) are skipped.
    public func register(_ action: any PipelineAction) {
        guard !actions.contains(where: { $0.id == action.id }) else {
            logger.warning("Duplicate action ID '\(action.id)' — skipping registration")
            return
        }
        actions.append(action)
        logger.debug("Registered: \(action.id) (priority: \(String(describing: action.priority)))")
    }

    /// Registers multiple actions at once.
    public func register(_ actions: [any PipelineAction]) {
        for action in actions { register(action) }
    }

    /// Removes all registered actions.
    public func removeAll() {
        actions.removeAll()
    }

    /// Evaluates all registered actions and executes eligible ones in priority order.
    ///
    /// Creates a fresh `PipelineContext` per call. Concurrent calls are ignored while processing.
    /// - Returns: The results of executed actions, in execution order.
    @discardableResult
    public func evaluate() async -> [ActionResult] {
        guard !isProcessing else {
            logger.debug("Already running — skipping evaluation")
            return []
        }

        isProcessing = true
        completedCount = 0
        results = []

        let context = PipelineContext()

        logger.info("Evaluating \(self.actions.count) registered pipeline actions")

        let eligible = await evaluateConditions()

        eligibleCount = eligible.count
        logger.info("\(eligible.count) actions eligible for execution")

        for action in eligible {
            currentActionId = action.id
            logger.info("Executing: \(action.id)")

            let result = await action.execute(context: context)

            results.append(result)
            completedCount += 1
            logger.info("Completed: \(action.id) (\(self.completedCount)/\(self.eligibleCount)) — \(String(describing: result))")
        }

        currentActionId = nil
        isProcessing = false

        logger.info("Pipeline complete — executed \(self.results.count) actions")

        return results
    }

    // MARK: - Private

    private func evaluateConditions() async -> [any PipelineAction] {
        let snapshot = actions

        let eligible = await withTaskGroup(
            of: (ActionID, Bool).self,
            returning: Set<ActionID>.self
        ) { group in
            for action in snapshot {
                group.addTask {
                    let should = await action.shouldRun()
                    return (action.id, should)
                }
            }

            var eligible = Set<ActionID>()
            for await (id, shouldRun) in group {
                if shouldRun {
                    eligible.insert(id)
                } else {
                    logger.debug("Skipping: \(id)")
                }
            }
            return eligible
        }

        return snapshot
            .filter { eligible.contains($0.id) }
            .sorted { $0.priority < $1.priority }
    }
}
