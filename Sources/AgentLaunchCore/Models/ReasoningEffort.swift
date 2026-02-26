/// OpenAI-style unified reasoning effort levels.
///
/// Future Claude mapping guidance:
/// - `none` -> disable thinking (no effort value)
/// - `minimal` -> `low`
/// - `low` -> `low`
/// - `medium` -> `medium`
/// - `high` -> `high`
/// - `xhigh` -> `max` (fallback to `high` if `max` is unavailable)
public enum ReasoningEffort: String, CaseIterable, Sendable {
    case none
    case minimal
    case low
    case medium
    case high
    case xhigh
}
