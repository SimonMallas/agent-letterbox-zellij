# Changelog

All notable changes to Agent Letterbox for Zellij are documented here.

## [0.2.0] — 2026-08-11

Public v0.2 is a **correctness** release, not a feature release. It fixes lifecycle bugs in the helper and documents the resulting state machine for local Zellij teams.

### Fixed

- `reply <id> ack` no longer archives the letter. Acknowledging a task marks it as accepted work in progress and leaves it in the inbox; only `nack` and `result` close it. Previously an acknowledgement filed the letter away, so accepted work disappeared from the inbox tracking it.
- The doorbell now rings after the letter's local state has settled, not before (when submit is enabled).
- `check` no longer counts `.ack` sidecars as unread mail, and warns about an orphan sidecar instead of silently counting it.
- Message parsing tolerates CRLF line endings.
- A failed reply link is recovered deterministically rather than aborting.

### Added

- `.md.ack` sidecar marking a letter as accepted and in progress.
- `letterbox file <id>` to dispose of a letter that requires no acknowledgement.
- Lifecycle locking so concurrent replies to the same letter converge on one terminal state.
- Derived `thread` field on ownership replies.
- `docs/lifecycle.md` and expanded SPEC/README lifecycle wording.
- Explicit documentation that **without `LETTERBOX_ZELLIJ_SUBMIT=1` the durable letter is delivered but no recipient-side terminal nudge occurs**.
- `letterbox zellij setup` / `run` / `register` / `unregister` / `status`, live pane+session registry, static pane/session fallback, and beginner install path (folded from earlier unreleased history).

### Changed

- `SPEC.md` raised to v0.2 with an explicit letter state machine and task vs non-task rules.
- `done` refuses to close a letter that has been acknowledged; use `reply <id> result|nack`.
- `file` refuses letters that require acknowledgement.
- Documentation examples use neutral role identities (`planner`, `reviewer`, `builder`, `researcher`).

### Compatibility

- No message-format change. Existing letters remain valid.
- All agents in a team must run v0.2; mixed v0.1/v0.2 teams are not supported.
- Inboxes may show more letters after upgrading — see "Pre-release note" in the README.

## [0.1.0] — 2026-07-18

### Added

- Durable Letterbox CLI with atomic publish, reply-first handling, locks, and completion checks.
- Local Zellij bootstrap (`setup` / `run` / `register` / `status`).
- Registry-first adapter using Zellij `action write-chars --pane-id` + Enter (byte 13) when submit is enabled.
- Core tests and beginner documentation.
