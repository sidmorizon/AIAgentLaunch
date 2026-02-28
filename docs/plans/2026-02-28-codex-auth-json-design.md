# Codex Auth JSON Backup/Restore Design

**Context**

The Codex proxy launch flow currently relies on a temporary `~/.codex/config.toml` merge plus an injected `OPENAI_API_KEY` environment variable at application launch. The requested behavior changes that contract: API mode must write the active API key into `~/.codex/auth.json`, and original mode must restore the previously backed-up auth file.

**Goals**

- Keep the existing temporary `config.toml` override flow for API mode.
- Stop injecting `OPENAI_API_KEY` into the Codex process environment.
- Before API-mode launch, back up the original `~/.codex/auth.json` state.
- Write a new `~/.codex/auth.json` containing `auth_mode = api` and the real API key.
- On the next original-mode Codex launch, restore the prior `auth.json` content.
- If `auth.json` did not exist before proxy launch, original mode should remove it.

**Approaches Considered**

1. Extend the provider/coordinator flow so Codex launch state covers both `config.toml` and `auth.json`.
   - Pros: single responsibility for Codex launch state, consistent restore behavior, easier tests.
   - Cons: requires new transaction surface beyond the existing config transaction.

2. Keep `config.toml` in the existing transaction and handle `auth.json` ad hoc in the menu-bar router.
   - Pros: smaller immediate diff.
   - Cons: launch state becomes split across layers, making partial restore bugs more likely.

3. Always overwrite or delete `auth.json` without backup semantics.
   - Pros: minimal code.
   - Cons: violates the explicit requirement to restore the previous auth file.

**Chosen Design**

Use approach 1. Model `auth.json` as Codex launch state managed alongside the temporary `config.toml` change.

**Architecture**

- `AgentProviderCodex` will expose both the primary Codex config path and the auth file path, plus a backup path for the auth file state.
- A dedicated auth-file transaction type will manage these operations:
  - capture the original `auth.json` state (`absent` or `content`)
  - persist a backup marker/file that survives across launches
  - write the API-mode `auth.json`
  - restore the original state during original-mode launch
- `AgentLaunchCoordinator` will apply the temporary `config.toml`, write the API-mode auth file, and launch Codex with an empty environment override map.
- `DefaultMenuBarLaunchRouter.launchOriginalMode(agent: .codex)` will restore the backed-up auth state before launching original Codex.

**Data Flow**

API-mode Codex launch:
1. Build temporary `config.toml` content.
2. Merge/write temporary config using the existing config transaction.
3. Capture the original auth file state and write a durable backup artifact.
4. Write a fresh `auth.json` with:
   - `auth_mode: "api"`
   - `OPENAI_API_KEY: <real key>`
5. Launch Codex with no injected API-key environment variable.
6. Leave temporary config and auth state in place until the user later launches original mode.

Original-mode Codex launch:
1. Comment out `profile = ...` in `config.toml` if present, preserving the current behavior.
2. Restore `auth.json` from the durable backup artifact.
3. If the original auth file was absent, delete the current `auth.json`.
4. Remove the backup artifact after successful restore.
5. Launch Codex with no environment overrides.

**Error Handling**

- If API-mode launch fails after writing the auth file, keep the modified state in place to match the existing “leave temporary config until original launch” behavior.
- Restore should be idempotent. Missing backup artifacts should be treated as “nothing to restore”.
- File writes must create `~/.codex/` when needed.

**Config Rendering Changes**

The temporary Codex `config.toml` should no longer declare `env_key`, because proxy launch will no longer provide the key via environment variable. The API key source moves entirely to `auth.json`.

**Testing Strategy**

- Unit-test auth-file transaction behavior:
  - backup and restore existing auth content
  - restore absence by deleting the file
  - idempotent restore
- Update coordinator tests to verify Codex proxy launch no longer injects `OPENAI_API_KEY`.
- Update router tests to verify original-mode launch restores `auth.json`.
- Update config-renderer tests to verify `env_key` is absent from the generated temporary config.

**Out of Scope**

- Changes to Claude launch behavior.
- Migration of any other Codex state files.
- Automatic restoration on app exit; restore remains tied to the next original-mode launch.
