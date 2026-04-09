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

    // MARK: - Properties

    public let rawValue: String

    // MARK: - Initialization

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init<E: RawRepresentable>(_ value: E) where E.RawValue == String {
        self.rawValue = value.rawValue
    }

    // MARK: - CustomStringConvertible

    public var description: String { rawValue }
}
