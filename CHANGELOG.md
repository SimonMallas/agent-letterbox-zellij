# Changelog

## [0.3.1] — 2026-08-16

- Correct v0.3 release metadata and roadmap wording.
- Complete public v0.3 lifecycle, privacy, resolver, and release-gate parity.

## [0.3.0] — 2026-08-16

Public-safe Agent Letterbox core upgrade (Zellij product).

### Added
- Additive doorbell token: complete v0.2 line as byte-prefix, then ` · <8-hex>` after `please check` (never slug/body)
- `letterbox nudge <id|display-id|token>` re-rings an open letter without creating mail
- `letterbox read <id|display-id|token>` — exact durable letter; own-inbox only
- `letterbox progress <id|display-id|token> <note>` — ACK sidecar progress; default `check` shows note + age
- Operational `letterbox check`: live/stale counts, last-activity age, summary cards (no bodies); `--recent`; `--thread <id>` read-only fan-out
- `letterbox doorbell-line` / `doorbell-parse` helpers
- Structural file guard C: PATH form of inbound result/nack requires `--read`; id/token/display_id may file directly
- Observable ring honesty: submit-off remains durable-only with **no** terminal ring; outcomes never mean read/turn_started

### Compatibility
- v0.2 lifecycle verbs preserved (`send` / `reply` / `file` / ACK sidecar)
- Token-less v0.2 doorbell lines still accepted by `doorbell-parse`
- Zellij registry + `LETTERBOX_ZELLIJ_SUBMIT` semantics unchanged (submit-off = no ring)

### Excluded (not in this product)
- Private messaging bridges, host service-manager units, or single-agent intake adapters
- Auto-register, machine seen/read receipts, dispatcher



All notable changes to Agent Letterbox for Zellij are documented here.

## [0.2.0] — 2026-08-11

Public v0.2 establishes a durable task lifecycle for local Zellij teams and documents the resulting state machine.

### Fixed

- `reply <id> ack` marks a task as accepted work in progress and leaves it in the inbox; only `nack` and `result` close it.
- The doorbell now rings after the letter's local state has settled, not before (when submit is enabled).
- `check` excludes `.ack` sidecars from the letter count and warns about an orphan sidecar.
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
- `send` rejects freeform `ack`, `nack`, and `result`; use `reply` for ownership responses so the helper derives their link and retry identity.
- `delegate` now requires `--ack`.
- Documentation examples use neutral role identities (`planner`, `reviewer`, `builder`, `researcher`).

### Compatibility

- Additive message-format change: ownership replies carry an optional `thread` field. Existing letters remain valid; older readers ignore unknown frontmatter keys.
- Existing scripts that send freeform `ack`, `nack`, or `result` must switch to `letterbox reply <id> <ack|nack|result> <slug>`.
- Existing delegate sends must include `--ack`.
- All agents in a team must run the same v0.2 helper version.

## [0.1.0] — 2026-07-18

### Added

- Durable Letterbox CLI with atomic publish, reply-first handling, locks, and completion checks.
- Local Zellij bootstrap (`setup` / `run` / `register` / `status`).
- Registry-first adapter using Zellij `action write-chars --pane-id` + Enter (byte 13) when submit is enabled.
- Core tests and beginner documentation.
