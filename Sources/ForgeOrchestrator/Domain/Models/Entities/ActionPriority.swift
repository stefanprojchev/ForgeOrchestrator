import Foundation

/// Priority level for orchestrated actions.
///
/// Actions are evaluated and executed in priority order (critical first).
/// Within the same priority level, execution order follows registration order.
///
/// ## Priority guide
///
/// | Priority | Use case | Example |
/// |---|---|---|
/// | `.critical` | Blocks all app usage | Force update, maintenance mode, terms acceptance |
/// | `.high` | Core setup the user must complete | Onboarding, required permissions, migration |
/// | `.medium` | Important but skippable | What's new, optional permissions, review prompt |
/// | `.low` | Nice to have, non-intrusive | Tips, promotions, announcements |
public enum ActionPriority: Int, Comparable, Sendable {
    case critical = 0
    case high = 1
    case medium = 2
    case low = 3

    public static func < (lhs: ActionPriority, rhs: ActionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
