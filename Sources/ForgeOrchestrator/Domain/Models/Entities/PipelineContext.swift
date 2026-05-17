import ForgeCore
import Foundation

/// Typed shared state passed between actions in a pipeline run.
///
/// Thread-safe via `LockedState`. One context is created per `evaluate()` call.
///
/// ```swift
/// // In LoadPostsAction:
/// context.set("posts", posts)
///
/// // In FilterPostsAction:
/// let posts: [Post]? = context.get("posts")
/// ```
public final class PipelineContext: @unchecked Sendable {

    // MARK: - Dependencies

    private let state = LockedState<[String: Any]>([:])

    // MARK: - Init

    public init() {}

    // MARK: - Implementation

    /// Stores a value for the given key.
    public func set<T: Sendable>(_ key: String, _ value: T) {
        state.withLock { $0[key] = value }
    }

    /// Returns the value for the given key, or `nil` if not set or wrong type.
    public func get<T: Sendable>(_ key: String) -> T? {
        state.withLock { $0[key] as? T }
    }

    /// Removes the value for the given key.
    public func remove(_ key: String) {
        state.withLock { $0[key] = nil }
    }
}
