import Foundation

/// Type-safe identifier for orchestrated actions.
///
/// Encourages enum-based IDs while allowing string fallback:
/// ```swift
/// enum StartupID: String { case terms, onboarding }
/// let id = ActionID(.terms)       // from enum
/// let id = ActionID("custom")     // from string
/// ```
public struct ActionID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init<E: RawRepresentable>(_ value: E) where E.RawValue == String {
        self.rawValue = value.rawValue
    }

    public var description: String { rawValue }
}
