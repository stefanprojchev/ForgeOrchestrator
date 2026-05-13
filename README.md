# ForgeOrchestrator

Orchestrate iOS app flows — startup gates, data pipelines, and continuous monitors.

![Swift 6.3+](https://img.shields.io/badge/Swift-6.3+-orange.svg)
![iOS 18+](https://img.shields.io/badge/iOS-18+-blue.svg)
![macOS 15+](https://img.shields.io/badge/macOS-15+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)
[![Release](https://img.shields.io/github/v/release/stefanprojchev/ForgeOrchestrator)](https://github.com/stefanprojchev/ForgeOrchestrator/releases)

---

ForgeOrchestrator gives you three orchestrators for three common app-flow shapes. Each shares the same action model — identity, priority, `shouldRun()` gate — but runs them differently.

| Orchestrator | Runs | State sharing | Use case |
|---|---|---|---|
| **SequenceOrchestrator** | Once | None | App launch gates — onboarding, force-update, terms |
| **PipelineOrchestrator** | Once | `PipelineContext` | Data-loading flows — actions share typed results |
| **MonitorOrchestrator** | Interval or on-demand | None | Continuous checks — expired terms, periodic sync |

## Features

- **Three orchestrators** for three distinct flow shapes
- **Priority-ordered execution** — `.critical`, `.high`, `.medium`, `.low`
- **Concurrent gate evaluation** — `shouldRun()` runs in parallel across all actions
- **`@MainActor @Observable`** — bind `isProcessing`, `eligibleCount`, `currentActionId` directly to SwiftUI
- **`CompletionSignal`** for bridging async actions with UI completion callbacks
- **Screen exclusion** on `MonitorOrchestrator` — suppress interruption during critical flows

## Requirements

- **iOS** 18+
- **macOS** 15+
- **Swift** 6.3+ (Xcode 26 or later)

## Installation

### Xcode

1. **File → Add Package Dependencies…**
2. Paste `https://github.com/stefanprojchev/ForgeOrchestrator.git`
3. Set rule to **Up to Next Major** from `1.0.0`

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/stefanprojchev/ForgeOrchestrator.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["ForgeOrchestrator"]
    )
]
```

## Quick Start

### Sequence — app launch gates

```swift
import ForgeOrchestrator

struct OnboardingAction: SequenceAction {
    let id = ActionID("onboarding")
    let priority: ActionPriority = .high

    func shouldRun() async -> Bool {
        !UserDefaults.standard.bool(forKey: "onboarded")
    }

    func execute() async {
        let signal = CompletionSignal()
        OnboardingPresenter.show { signal.complete() }
        await signal.wait()
        UserDefaults.standard.set(true, forKey: "onboarded")
    }
}

// App launch
@main
struct App {
    @State private var orchestrator = SequenceOrchestrator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    orchestrator.register([
                        ForceUpdateAction(),
                        OnboardingAction(),
                        WhatsNewAction(),
                    ])
                    await orchestrator.evaluate()
                }
        }
    }
}
```

### Pipeline — actions share state

```swift
import ForgeOrchestrator

struct LoadPostsAction: PipelineAction {
    let id: ActionID = "load-posts"
    let priority: ActionPriority = .high

    func shouldRun() async -> Bool { true }

    func execute(context: PipelineContext) async -> ActionResult {
        let posts = try? await api.fetchPosts()
        context.set("posts", posts ?? [])
        return posts != nil ? .completed : .failed("fetch failed")
    }
}

struct FilterPostsAction: PipelineAction {
    let id: ActionID = "filter-posts"
    let priority: ActionPriority = .medium

    func shouldRun() async -> Bool { true }

    func execute(context: PipelineContext) async -> ActionResult {
        guard let posts: [Post] = context.get("posts") else {
            return .skipped
        }
        context.set("filtered", posts.filter(\.isPublished))
        return .completed
    }
}

let pipeline = PipelineOrchestrator()
pipeline.register([LoadPostsAction(), FilterPostsAction()])
let results = await pipeline.evaluate()
```

### Monitor — continuous checks

```swift
import ForgeOrchestrator

let monitor = MonitorOrchestrator(interval: 300)  // re-check every 5 minutes
monitor.register(TermsExpiredAction())
monitor.register(SessionTimeoutAction())

// Don't interrupt the user during critical flows
monitor.setExcludedScreens(["Checkout", "VideoCall"])

monitor.start()
```

## Observable progress UI

All three orchestrators are `@MainActor @Observable`. Bind them directly to SwiftUI:

```swift
struct StartupProgress: View {
    @Bindable var orchestrator: SequenceOrchestrator

    var body: some View {
        if orchestrator.isProcessing {
            ProgressView(
                value: Double(orchestrator.completedCount),
                total: Double(orchestrator.eligibleCount)
            )
            if let id = orchestrator.currentActionId {
                Text("Running: \(id.rawValue)")
            }
        }
    }
}
```

## The Forge Family

ForgeOrchestrator is part of the **Forge** family of Swift packages for iOS.

| Package | Description |
|---|---|
| [ForgeCore](https://github.com/stefanprojchev/ForgeCore) | Thread-safe primitives for iOS Swift packages. |
| [ForgeInject](https://github.com/stefanprojchev/ForgeInject) | Dependency injection with constructor and property wrapper support. |
| [ForgeObservers](https://github.com/stefanprojchev/ForgeObservers) | Reactive system observers — connectivity, lifecycle, keyboard, and more. |
| [ForgeStorage](https://github.com/stefanprojchev/ForgeStorage) | Type-safe key-value, file, and Keychain storage. |
| [ForgeDB](https://github.com/stefanprojchev/ForgeDB) | Type-safe repository pattern and GRDB-backed SQLite persistence. |
| **ForgeOrchestrator** | Orchestrate app flows — startup gates, data pipelines, and continuous monitors. |
| [ForgePush](https://github.com/stefanprojchev/ForgePush) | Push notification management — permissions, tokens, and routing. |
| [ForgeLocation](https://github.com/stefanprojchev/ForgeLocation) | Location triggers — geofencing, significant changes, and visits. |
| [ForgeBackgroundTasks](https://github.com/stefanprojchev/ForgeBackgroundTasks) | Background task scheduling and dispatch. |

## License

ForgeOrchestrator is released under the MIT License. See [LICENSE](LICENSE).
