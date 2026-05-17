import Foundation
import OSLog

/// Orchestrates actions sequentially in priority order. Run once.
///
/// Evaluates all registered actions' `shouldRun()` concurrently, sorts eligible
/// by priority, then executes one at a time. Prevents stacking.
///
/// ```swift
/// let orchestrator = SequenceOrchestrator()
/// orchestrator.register(TermsAction())
/// orchestrator.register(OnboardingAction())
/// await orchestrator.evaluate()
/// ```
@Observable
@MainActor
open class SequenceOrchestrator {

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "forge.orchestrator", category: "sequence")

    /// Whether the orchestrator is currently evaluating or executing actions.
    public private(set) var isProcessing = false

    /// The ID of the currently executing action, or `nil` if idle.
    public private(set) var currentActionId: ActionID?

    /// Number of eligible actions found during the last evaluation.
    public private(set) var eligibleCount = 0

    /// Number of actions completed so far in the current evaluation.
    public private(set) var completedCount = 0

    @ObservationIgnored
    private var actions: [any SequenceAction] = []

    // MARK: - Init

    public init() {}

    // MARK: - Implementation

    /// Registers an action. Call before `evaluate()`.
    /// Duplicates (same ID) are skipped.
    public func register(_ action: any SequenceAction) {
        guard !actions.contains(where: { $0.id == action.id }) else {
            logger.warning("Duplicate action ID '\(action.id)' — skipping registration")
            return
        }
        actions.append(action)
        logger.debug("Registered: \(action.id) (priority: \(String(describing: action.priority)))")
    }

    /// Registers multiple actions at once.
    public func register(_ actions: [any SequenceAction]) {
        for action in actions { register(action) }
    }

    /// Removes all registered actions.
    public func removeAll() {
        actions.removeAll()
    }

    /// Evaluates all registered actions and executes eligible ones in priority order.
    ///
    /// Concurrent calls are ignored while processing.
    /// - Returns: The IDs of actions that were executed.
    @discardableResult
    public func evaluate() async -> [ActionID] {
        guard !isProcessing else {
            logger.debug("Already running — skipping evaluation")
            return []
        }

        isProcessing = true
        completedCount = 0
        var executedIds: [ActionID] = []

        logger.info("Evaluating \(self.actions.count) registered actions")

        let eligible = await evaluateConditions()

        eligibleCount = eligible.count
        logger.info("\(eligible.count) actions eligible for execution")

        for action in eligible {
            currentActionId = action.id
            logger.info("Executing: \(action.id)")

            await action.execute()

            executedIds.append(action.id)
            completedCount += 1
            logger.info("Completed: \(action.id) (\(self.completedCount)/\(self.eligibleCount))")
        }

        currentActionId = nil
        isProcessing = false

        logger.info("Sequence complete — executed \(executedIds.count) actions")

        return executedIds
    }

    // MARK: - Private

    private func evaluateConditions() async -> [any SequenceAction] {
        let snapshot = actions

        let results = await withTaskGroup(
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
            .filter { results.contains($0.id) }
            .sorted { $0.priority < $1.priority }
    }
}
