# LaunchInspectionPayload Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the single launch-log string inspection flow with a structured payload so the startup inspection window always shows `config.toml` content and injected environment variables separately.

**Architecture:** Add a `LaunchInspectionPayload` model returned by launch-routing APIs and stored by `MenuBarViewModel`. Update the preview window controller to render two explicit sections from that payload and use a dedicated environment formatter for masking and display. Keep launch behavior unchanged.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest

---

### Task 1: Add the inspection payload model and environment formatter

**Files:**
- Create: `Sources/AgentLaunchCore/Models/LaunchInspectionPayload.swift`
- Create: `Sources/AgentLaunchCore/Launch/LaunchEnvironmentSnapshotFormatter.swift`
- Test: `Tests/AgentLaunchCoreTests/Launch/LaunchEnvironmentSnapshotFormatterTests.swift`

**Step 1: Write the failing test**

Create formatter tests for:

- sorted output
- `API_KEY` masking
- `TOKEN` masking
- empty environment output

**Step 2: Run test to verify it fails**

Run: `swift test --filter LaunchEnvironmentSnapshotFormatterTests`

Expected: FAIL because the formatter file and type do not exist.

**Step 3: Write minimal implementation**

- add `LaunchInspectionPayload`
- add formatter with key sorting and masking

**Step 4: Run test to verify it passes**

Run: `swift test --filter LaunchEnvironmentSnapshotFormatterTests`

Expected: PASS

### Task 2: Return payloads from launch-routing APIs

**Files:**
- Modify: `Sources/AgentLaunchCore/ViewModel/MenuBarViewModel.swift`
- Modify: `Sources/AgentLaunchCore/Launch/AgentLaunchCoordinator.swift`
- Modify: `Sources/AgentLaunchCore/Launch/ClaudeLaunchEnvironment.swift`
- Test: `Tests/AgentLaunchCoreTests/ViewModel/MenuBarViewModelTests.swift`
- Test: `Tests/AgentLaunchCoreTests/ViewModel/DefaultMenuBarLaunchRouterTests.swift`

**Step 1: Write the failing test**

Add tests asserting:

- original Codex launch returns payload with config text and empty env
- Codex proxy launch returns payload with merged config text
- Claude proxy launch returns payload with injected env

**Step 2: Run test to verify it fails**

Run: `swift test --filter MenuBarViewModelTests --filter DefaultMenuBarLaunchRouterTests`

Expected: FAIL because router APIs still return strings.

**Step 3: Write minimal implementation**

- change routing protocol methods to return `LaunchInspectionPayload`
- update router and coordinator implementations
- keep Claude CLI environment data available for the preview window

**Step 4: Run test to verify it passes**

Run: `swift test --filter MenuBarViewModelTests --filter DefaultMenuBarLaunchRouterTests`

Expected: PASS

### Task 3: Replace view-model inspection state with payload storage

**Files:**
- Modify: `Sources/AgentLaunchCore/ViewModel/MenuBarViewModel.swift`
- Test: `Tests/AgentLaunchCoreTests/ViewModel/MenuBarViewModelTests.swift`

**Step 1: Write the failing test**

Update or add tests for:

- `lastLaunchInspectionPayload`
- `canInspect...` gating using payload presence
- backward-compatible accessors if kept temporarily

**Step 2: Run test to verify it fails**

Run: `swift test --filter MenuBarViewModelTests`

Expected: FAIL until the view-model stores payloads.

**Step 3: Write minimal implementation**

- replace `lastLaunchLogText` as the primary state
- populate payload after successful launch
- update inspect availability checks

**Step 4: Run test to verify it passes**

Run: `swift test --filter MenuBarViewModelTests`

Expected: PASS

### Task 4: Update the inspect window to render two sections from the payload

**Files:**
- Modify: `Sources/AIAgentLaunch/UI/LaunchConfigPreviewWindowController.swift`
- Modify: `Sources/AIAgentLaunch/UI/MenuBarContentView.swift`
- Test: `Tests/AgentLaunchCoreTests/UI/LaunchConfigPreviewWindowControllerSourceTests.swift`
- Test: `Tests/AgentLaunchCoreTests/UI/MenuBarContentViewSourceLayoutTests.swift`

**Step 1: Write the failing test**

Add source assertions for:

- preview window accepts `LaunchInspectionPayload`
- `config.toml` section title
- `启动环境变量` section title
- inspect action passes payload instead of raw text

**Step 2: Run test to verify it fails**

Run: `swift test --filter LaunchConfigPreviewWindowControllerSourceTests --filter MenuBarContentViewSourceLayoutTests`

Expected: FAIL because the UI still uses `launchLogText`.

**Step 3: Write minimal implementation**

- change the preview window controller signature
- render both sections with empty states
- keep Claude CLI controls working

**Step 4: Run test to verify it passes**

Run: `swift test --filter LaunchConfigPreviewWindowControllerSourceTests --filter MenuBarContentViewSourceLayoutTests`

Expected: PASS

### Task 5: Run full targeted verification

**Files:**
- No source changes expected

**Step 1: Run focused verification**

Run:

```bash
swift test --filter LaunchEnvironmentSnapshotFormatterTests
swift test --filter MenuBarViewModelTests
swift test --filter DefaultMenuBarLaunchRouterTests
swift test --filter LaunchConfigPreviewWindowControllerSourceTests
swift test --filter MenuBarContentViewSourceLayoutTests
```

Expected: PASS

**Step 2: Run broader package verification**

Run: `swift test`

Expected: PASS
