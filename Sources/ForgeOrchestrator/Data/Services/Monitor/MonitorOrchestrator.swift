import Foundation
import OSLog

/// Monitors conditions continuously and executes actions when they become eligible.
///
/// Combines interval-based re-evaluation with manual `reevaluate()` calls.
/// Respects screen exclusion — skips evaluation when the current screen is excluded.
/// Re-evaluates `shouldRun()` on ALL actions every cycle (stateless).
///
/// ```swift
/// let monitor = MonitorOrchestrator(interval: 300)
/// monitor.register(TermsExpiredAction())
/// monitor.setExcludedScreens(["Checkout", "Payment"])
/// monitor.start()
/// ```
@Observable
@MainActor
open class MonitorOrchestrator {

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "forge.orchestrator", category: "monitor")
    private let interval: TimeInterval?

    /// Whether the monitor is currently executing actions.
    public private(set) var isProcessing = false

    /// The ID of the currently executing action, or `nil` if idle.
    public private(set) var currentActionId: ActionID?

    @ObservationIgnored
    private var actions: [any MonitorAction] = []

    @ObservationIgnored
    private var excludedScreens: Set<String> = []

    @ObservationIgnored
    private var currentScreen: String?

    @ObservationIgnored
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    /// - Parameter interval: Optional re-evaluation interval in seconds. `nil` disables automatic re-evaluation.
    public init(interval: TimeInterval? = nil) {
        self.interval = interval
    }

    // MARK: - Implementation

    /// Registers a monitor action. Duplicates (same ID) are skipped.
    public func register(_ action: any MonitorAction) {
        guard !actions.contains(where: { $0.id == action.id }) else {
            logger.warning("Duplicate action ID '\(action.id)' — skipping registration")
            return
        }
        actions.append(action)
        logger.debug("Registered: \(action.id)")
    }

    /// Registers multiple actions at once.
    public func register(_ actions: [any MonitorAction]) {
        for action in actions { register(action) }
    }

    /// Removes all registered actions.
    public func removeAll() {
        actions.removeAll()
    }

    /// Sets the screens where the monitor should not evaluate actions.
    public func setExcludedScreens(_ screens: Set<String>) {
        excludedScreens = screens
    }

    /// Updates the current screen identifier. The monitor checks this before evaluating.
    public func updateCurrentScreen(_ screen: String?) {
        currentScreen = screen
    }

    /// Starts the interval-based re-evaluation loop.
    public func start() {
        guard let interval else {
            logger.debug("No interval configured — start() is a no-op")
            return
        }

        stop()

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.reevaluate()
            }
        }

        logger.info("Monitor started (interval: \(interval)s)")
    }

    /// Stops the interval-based re-evaluation loop.
    public func stop() {
        timerTask?.cancel()
        timerTask = nil
        logger.info("Monitor stopped")
    }

    /// Manually triggers a re-evaluation cycle.
    ///
    /// Safe to call at any time — ignored if already processing or on an excluded screen.
    public func reevaluate() async {
        guard !isProcessing else {
            logger.debug("Already processing — skipping reevaluate")
            return
        }

        if let screen = currentScreen, excludedScreens.contains(screen) {
            logger.debug("Current screen '\(screen)' is excluded — skipping")
            return
        }

        isProcessing = true

        logger.info("Re-evaluating \(self.actions.count) monitor actions")

        let eligible = await evaluateConditions()

        guard !eligible.isEmpty else {
            isProcessing = false
            logger.debug("No eligible actions")
            return
        }

        logger.info("\(eligible.count) actions eligible")

        for action in eligible {
            currentActionId = action.id
            logger.info("Executing: \(action.id)")

            await action.execute()

            logger.info("Completed: \(action.id)")
        }

        currentActionId = nil
        isProcessing = false
    }

    // MARK: - Private

    private func evaluateConditions() async -> [any MonitorAction] {
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
