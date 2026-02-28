# Codex Auth JSON Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move Codex API-mode authentication from launch-time `OPENAI_API_KEY` environment injection to a backed-up and restored `~/.codex/auth.json` flow.

**Architecture:** Keep the existing temporary `config.toml` merge for Codex proxy launches, add a dedicated auth-file transaction for `~/.codex/auth.json`, and restore the previous auth state during the next original-mode Codex launch. Codex proxy launches will stop passing `OPENAI_API_KEY` via environment variables, so the temporary config renderer must also stop emitting `env_key`.

**Tech Stack:** Swift, XCTest, Foundation file APIs

---

### Task 1: Add durable Codex auth-file state handling

**Files:**
- Create: `Sources/AgentLaunchCore/Config/CodexAuthTransaction.swift`
- Modify: `Sources/AgentLaunchCore/Providers/AgentProviderBase.swift`
- Modify: `Sources/AgentLaunchCore/Providers/AgentProviderCodex.swift`
- Test: `Tests/AgentLaunchCoreTests/Config/CodexAuthTransactionTests.swift`

**Step 1: Write the failing tests**

Add tests covering:
- writing API-mode `auth.json` while recording prior content
- restoring prior content when the file existed
- deleting `auth.json` when it was originally absent
- idempotent restore with no backup present

**Step 2: Run test to verify it fails**

Run: `swift test --filter CodexAuthTransactionTests`
Expected: FAIL because the auth transaction type and provider paths do not exist.

**Step 3: Write minimal implementation**

Implement a small transaction type that:
- stores a backup artifact adjacent to `auth.json`
- records `absent` vs `content`
- writes API-mode JSON with the real key
- restores and clears the backup artifact

Expose auth/backup paths from the Codex provider.

**Step 4: Run test to verify it passes**

Run: `swift test --filter CodexAuthTransactionTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentLaunchCore/Config/CodexAuthTransaction.swift Sources/AgentLaunchCore/Providers/AgentProviderBase.swift Sources/AgentLaunchCore/Providers/AgentProviderCodex.swift Tests/AgentLaunchCoreTests/Config/CodexAuthTransactionTests.swift
git commit -m "feat: back up codex auth file for proxy launch"
```

### Task 2: Remove Codex API-key env injection and apply auth transaction in proxy launch

**Files:**
- Modify: `Sources/AgentLaunchCore/Config/AgentConfigRenderer.swift`
- Modify: `Sources/AgentLaunchCore/Launch/AgentLaunchCoordinator.swift`
- Test: `Tests/AgentLaunchCoreTests/Config/AgentConfigRendererTests.swift`
- Test: `Tests/AgentLaunchCoreTests/Launch/AgentLaunchCoordinatorTests.swift`

**Step 1: Write the failing tests**

Update tests to assert:
- temporary config no longer contains `env_key`
- proxy launch no longer passes `OPENAI_API_KEY` in `launchApplication(...environmentVariables:)`
- proxy launch still writes auth state before launching

**Step 2: Run test to verify it fails**

Run: `swift test --filter AgentConfigRendererTests && swift test --filter AgentLaunchCoordinatorTests`
Expected: FAIL because the old renderer still emits `env_key` and the coordinator still injects the API key environment variable.

**Step 3: Write minimal implementation**

- Remove `env_key` generation from the renderer.
- Extend the coordinator initializer to accept the auth transaction.
- In Codex proxy launch, write `auth.json` before invoking the app launcher.
- Launch Codex with an empty environment dictionary.

**Step 4: Run test to verify it passes**

Run: `swift test --filter AgentConfigRendererTests && swift test --filter AgentLaunchCoordinatorTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentLaunchCore/Config/AgentConfigRenderer.swift Sources/AgentLaunchCore/Launch/AgentLaunchCoordinator.swift Tests/AgentLaunchCoreTests/Config/AgentConfigRendererTests.swift Tests/AgentLaunchCoreTests/Launch/AgentLaunchCoordinatorTests.swift
git commit -m "refactor: source codex api key from auth json"
```

### Task 3: Restore backed-up auth state in original-mode Codex launch

**Files:**
- Modify: `Sources/AgentLaunchCore/ViewModel/MenuBarViewModel.swift`
- Test: `Tests/AgentLaunchCoreTests/ViewModel/DefaultMenuBarLaunchRouterTests.swift`

**Step 1: Write the failing tests**

Add original-mode router tests covering:
- existing auth file gets restored before launch
- originally absent auth file is deleted before launch

**Step 2: Run test to verify it fails**

Run: `swift test --filter DefaultMenuBarLaunchRouterTests`
Expected: FAIL because original-mode launch does not yet restore auth state.

**Step 3: Write minimal implementation**

Inject or create the auth transaction in the default router and call restore before launching Codex original mode.

**Step 4: Run test to verify it passes**

Run: `swift test --filter DefaultMenuBarLaunchRouterTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentLaunchCore/ViewModel/MenuBarViewModel.swift Tests/AgentLaunchCoreTests/ViewModel/DefaultMenuBarLaunchRouterTests.swift
git commit -m "feat: restore codex auth file in original mode"
```

### Task 4: Run focused regression verification

**Files:**
- Modify: `README.md`

**Step 1: Update docs**

Adjust the Codex launch flow documentation so it describes the temporary `config.toml` change plus `auth.json` backup/restore semantics.

**Step 2: Run focused tests**

Run: `swift test --filter CodexAuthTransactionTests`
Expected: PASS

Run: `swift test --filter AgentConfigRendererTests`
Expected: PASS

Run: `swift test --filter AgentLaunchCoordinatorTests`
Expected: PASS

Run: `swift test --filter DefaultMenuBarLaunchRouterTests`
Expected: PASS

**Step 3: Run broader package verification**

Run: `swift test`
Expected: PASS

**Step 4: Commit**

```bash
git add README.md docs/plans/2026-02-28-codex-auth-json-design.md docs/plans/2026-02-28-codex-auth-json.md
git commit -m "docs: describe codex auth json launch flow"
```
