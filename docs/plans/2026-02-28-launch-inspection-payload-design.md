# LaunchInspectionPayload Design

## Goal

Replace the current single-string "launch log" inspection model with a structured payload so the Agent startup inspection window can always show:

- `config.toml` content when relevant
- the injected launch environment variables with sensitive values masked

## Current Problem

The current inspection flow stores one `lastLaunchLogText` string in `MenuBarViewModel` and passes that into `LaunchConfigPreviewWindowController`.

- For Codex, that string is configuration text.
- For Claude proxy launches, that string is a masked environment snapshot.

That makes the inspect window ambiguous and prevents it from showing both pieces of information at once.

## Proposed Model

Introduce `LaunchInspectionPayload` as the single source of truth for inspection UI.

Proposed fields:

```swift
public struct LaunchInspectionPayload: Equatable, Sendable {
    public let agent: AgentTarget
    public let codexConfigTOMLText: String?
    public let launchEnvironmentVariables: [String: String]
    public let claudeCLIEnvironmentVariables: [String: String]?
}
```

Notes:

- `codexConfigTOMLText` is optional because some launches do not use a config file.
- `launchEnvironmentVariables` contains only the variables injected or overridden for app launch, not the full inherited process environment.
- `claudeCLIEnvironmentVariables` stays separate so the existing Claude CLI command-copy UI can continue to work without coupling it to the generic inspect rendering rules.

## Launch Behavior Mapping

### Codex original mode

- `codexConfigTOMLText`: current Codex config after profile line adjustment / auth restore flow
- `launchEnvironmentVariables`: empty
- `claudeCLIEnvironmentVariables`: `nil`

### Codex proxy mode

- `codexConfigTOMLText`: merged temporary Codex config
- `launchEnvironmentVariables`: empty for the actual app launch call in current implementation
- `claudeCLIEnvironmentVariables`: `nil`

This preserves the current Codex launch behavior. The inspection UI still shows both sections; the environment section renders an empty-state message.

### Claude original mode

- `codexConfigTOMLText`: `nil`
- `launchEnvironmentVariables`: empty
- `claudeCLIEnvironmentVariables`: `nil`

### Claude proxy mode

- `codexConfigTOMLText`: `nil`
- `launchEnvironmentVariables`: the injected proxy environment
- `claudeCLIEnvironmentVariables`: same proxy environment

## UI Changes

Update the "Agent 启动日志" window to accept `LaunchInspectionPayload` instead of a raw text string.

The window will render two fixed sections:

1. `config.toml`
2. `启动环境变量`

Rendering rules:

- both sections use monospaced selectable text
- both sections render even when empty
- empty `config.toml` shows: `This launch did not modify config.toml.`
- empty environment variables show: `No injected environment variables.`

The Claude CLI controls remain below these sections and continue to use the Claude-specific environment payload.

## Masking and Formatting

Environment variable masking should happen outside the SwiftUI view body.

Introduce a small formatter that:

- sorts keys alphabetically
- renders `KEY = "value"` lines
- masks sensitive values

Masking rules:

- redact values for keys containing `API_KEY`
- redact values for keys containing `TOKEN`
- preserve existing short-value fallback behavior

## Data Flow

1. Launch button calls `MenuBarViewModel.launchSelectedAgent(_:)`
2. View model calls the router
3. Router returns a `LaunchInspectionPayload`
4. View model stores `lastLaunchInspectionPayload`
5. Inspect button passes payload to `LaunchConfigPreviewWindowController`
6. Preview window renders config and environment sections from the payload

## Compatibility

This is an internal refactor with localized UI updates.

- No change to app launch mechanics
- No change to Codex proxy config file generation
- No change to Claude environment injection behavior

## Testing

Add or update tests for:

- `MenuBarViewModel` storing payloads for original and proxy launches
- preview window source assertions for two rendered sections
- environment formatting and masking behavior
- inspect button wiring passing the payload instead of raw text

## Non-Goals

- showing the full inherited process environment
- changing Codex launch from config-file-driven startup to env-driven startup
- changing the Claude CLI copy interaction model
