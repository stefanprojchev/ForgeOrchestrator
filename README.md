# ForgeOrchestrator

Sequence, pipeline, and monitor orchestrators for iOS app flows for iOS.

## Requirements

- iOS 16+
- Swift 6.0+

## Installation

### Swift Package Manager

Add ForgeOrchestrator to your project via Xcode:

1. **File > Add Package Dependencies...**
2. Enter the repository URL
3. Select the version rule and add to your target

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stefanprojchev/ForgeOrchestrator.git", from: "1.0.0")
]
```

## Quick Start

```swift
import ForgeOrchestrator

let orchestrator = StartupOrchestrator()

orchestrator.register(ForceUpdateAction())
orchestrator.register(OnboardingAction())
orchestrator.register(WhatsNewAction())

let executed = await orchestrator.evaluate()
// Eligible actions run one at a time, in priority order
```

## StartupAction

Each action provides its priority, a condition, and an execution block:

```swift
protocol StartupAction: Sendable {
    var id: String { get }           // defaults to type name
    var priority: StartupPriority { get }
    func shouldRun() async -> Bool
    func execute() async
}
```

`execute()` must eventually return. Use `CompletionSignal` to suspend until the user dismisses a screen.

```swift
final class OnboardingAction: StartupAction {
    let priority = StartupPriority.high
    let signal = CompletionSignal()

    func shouldRun() async -> Bool {
        !UserDefaults.standard.bool(forKey: "onboardingComplete")
    }

    func execute() async {
        await MainActor.run { showOnboarding(signal: signal) }
        await signal.wait()
    }
}
```

## StartupPriority

| Priority | Use case | Example |
|----------|----------|---------|
| `.critical` | Blocks all app usage | Force update, maintenance mode, terms acceptance |
| `.high` | Core setup the user must complete | Onboarding, required permissions, migration |
| `.medium` | Important but skippable | What's new, optional permissions, review prompt |
| `.low` | Nice to have, non-intrusive | Tips, promotions, announcements |

Actions are sorted by priority (critical first). Within the same level, registration order is preserved.

## CompletionSignal

Bridges async orchestration with UI completion events. The action creates a signal, passes it to UI, and `await`s it. The UI calls `complete()` when the user is done.

```swift
let signal = CompletionSignal()

// In the action
await signal.wait()   // suspends until complete() is called

// In the UI (any thread)
signal.complete()     // resumes the waiting action
```

Thread-safe, idempotent. Multiple `complete()` calls are no-ops.

## StartupOrchestrator

`@Observable` for SwiftUI reactivity. Evaluates all registered actions concurrently, sorts eligible ones by priority, then executes sequentially to prevent multiple alerts/screens from stacking.

```swift
let orchestrator = StartupOrchestrator()

// Observable properties for UI
orchestrator.isProcessing   // currently evaluating/executing
orchestrator.currentActionId // ID of the running action
orchestrator.eligibleCount   // actions that passed shouldRun()
orchestrator.completedCount  // actions finished so far
```

Safe to call `evaluate()` multiple times — concurrent calls are ignored while processing. Returns the IDs of executed actions.

## Thread Safety

`StartupOrchestrator` is `@Observable` and `@MainActor`-isolated. `CompletionSignal` is `Sendable` — `wait()` and `complete()` are safe from any thread, backed by `LockedState`. `StartupAction` requires `Sendable` conformance.

## Forge Ecosystem

ForgeOrchestrator is part of the **Forge** family of Swift packages for iOS:

| Package | Description |
|---------|-------------|
| [ForgeCore](https://github.com/stefanprojchev/ForgeCore) | Thread-safe utilities — `LockedState` and `SendableFileManager` |
| [ForgeInject](https://github.com/stefanprojchev/ForgeInject) | Lightweight dependency injection with property wrapper |
| [ForgeObservers](https://github.com/stefanprojchev/ForgeObservers) | Reactive system observers (connectivity, lifecycle, keyboard, and more) |
| [ForgeStorage](https://github.com/stefanprojchev/ForgeStorage) | Type-safe persistence — key-value, file storage, and Keychain |
| [ForgeBackgroundTasks](https://github.com/stefanprojchev/ForgeBackgroundTasks) | BGTaskScheduler registration, scheduling, and dispatch |
| [ForgeLocation](https://github.com/stefanprojchev/ForgeLocation) | Location-based triggers — geofencing, significant changes, visits |
| [ForgePush](https://github.com/stefanprojchev/ForgePush) | Push notification management — permissions, tokens, silent and visible routing |
| **ForgeOrchestrator** | Sequence, pipeline, and monitor orchestrators for iOS app flows |

## License

MIT License. See [LICENSE](LICENSE) for details.
