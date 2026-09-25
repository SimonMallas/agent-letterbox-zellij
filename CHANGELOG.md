# Changelog

## [0.5.0] — 2026-09-25 (zellij edition)

- Add read-only `letterbox query`: strict-v1 envelope cards by default and
  explicit `--compat-v2` JSON with diagnostics and scoped completeness.
- Query requires Python 3.9+ (standard library only), with an explicit refusal
  when unavailable. Registration and bounded doorbell behavior is unchanged.
- New send and reply envelopes include UTC `sent`. A send's id and header share
  one clock snapshot; stable parent-derived reply ids retain their lineage while
  `sent` records each reply's own publication time. Identical retries preserve it.
- Add `send --supersedes <id>` as a syntax-validated reference, without ownership
  lookup. This option and explicit `--re`/`--thread` refuse malformed or overlong
  values rather than sanitising them. Existing letters are unchanged.
- Refuse injected/multiline header values: session labels are bounded, deadlines
  and publication times are calendar-valid UTC, and generated/derived ids and
  inherited reply linkage are validated before publication. Invalid session
  labels are refused before a reply can create a lifecycle lock. Queries never
  silently repair malformed older envelopes.
- Bound normalized new-send slugs with room for the recipient's longest reply
  suffix, reporting the actual per-send maximum on refusal. Writer/reference
  and both query id limits use the 243-byte temporary-filename budget, retaining
  support for long v0.4.0 ids that could already be replied to. Add maximum-slug
  ACK/RESULT and actual v0.4.0-writer synthetic-fixture compatibility controls.
- Add synthetic query tests to `make ci`, with Python 3.9 and 3.13 on the Ubuntu
  and macOS workflow matrix. Matrix configuration is not a claim of a passed run.
- Distinguish symlinked root components from non-directory components. Add
  separate mutation witnesses for no-follow opens, symlink recognition, and
  pre/post-open leaf type guards.
- No archive traversal or archive verb. Transport behavior is unchanged; header
  validation is not a claim of authenticated metadata, exhaustive writer race
  hardening, or hardware crash durability.
  See [query contracts and limitations](docs/query.md).

## [0.4.0] — 2026-09-17

### Changed

Release 2 doorbell contract. The ring now reports exactly one
`doorbell-outcome v=1` line per attempt — `submitted`,
`pasted_not_submitted`, or `no_live_surface` with a named reason — owned by
the helper wrapper, never by adapter prose. The typed doorbell line may
name the durable letter's sender.

- The wrapper is the sole outcome owner: the adapter's stdout is a private
  pipe; exactly one valid contract line on exit 0 forwards, anything else
  reports `unconfirmed` (`unparseable` is the consumer's verdict, never an
  emitter token).
- Two-step bounded inject (`write-chars`, then byte 13), each step bounded
  and classified: `send_failed`, `pasted_not_submitted enter_failed`,
  post-inject `unconfirmed`; only a proven pre-injection timeout is
  `helper_timeout` (the one retryable class).
- Runner-owned timeout sentinel: a child exiting 124 on its own is
  remapped and can never be misread as a timeout. Verified-runner check:
  missing python3 or zellij is `adapter_unavailable` (non-retryable), and
  without the bounder the wrapper fails closed — the adapter is never run
  unbounded.
- Ruled exit-status precedence: `submitted`/`pasted` claims after a
  nonzero exit downgrade to `unconfirmed`; a valid `no_live_surface` line
  keeps its named reason.
- Ruling-5 sender clause resolved from the durable letter (never
  `LETTERBOX_AGENT`), omitted when invalid — never `from -`.
  `doorbell-parse` accepts v02/v03/v04; a malformed ` from ` clause
  rejects the line. Legacy 3-arg adapter argv unchanged.
- Bounds budget documented in SPEC: 1s step budget, 4×step+5s wrapper
  backstop (9s at default), strictly inside the caller's 10s deadline.
- `nudge` now passes a real slug to the doorbell adapter (previously an
  empty argument silently prevented the ring).
- This edition carries no `conformance/` snapshot yet; the canonical
  fixture home is the cmux edition (`conformance/doorbell-outcome-v1/`),
  and vendoring here is a later explicit step.

## [0.3.3] — 2026-09-16

Maintenance cut of public main since 0.3.2. Outbox inbound exclusion is
already on this tree and is not reimplemented. Timestamp helpers already
had a GNU date fallback and are unchanged.

### Fixed

- `file_mtime` accepts a probe only when the complete captured stdout is a
  canonical decimal epoch (optional minus; no leading zeros). Nonzero exit
  discards stdout. GNU `-c` then BSD `-f`.
- `send` and `reply` refuse an empty or whitespace-only body. Non-blank
  bodies keep their surrounding whitespace.
- Frontmatter is trusted only with an opening `---` and its closing `---`.
  Further `---` lines belong to the body. Unterminated letters are skipped
  in check/token/read/file/reply with compact ids (no raw path or slug).
- `message_body` keeps `---` lines after the envelope close, so an identical
  ACK retry with a fenced body matches the stored letter. A different body
  still collides. Raw body lines keep CRLF; only fence comparisons strip CR.

### Added

- README links the shared guide.

## [0.3.2] — 2026-08-16

### Fixed

- **The documented doorbell example did not match what the adapter emits.** README, SPEC and
  the Zellij docs showed:

  a short form ending in `check your inbox`, with no type, path or token. The adapter has
  never emitted that shape. It emits:

  ```text
  📬 letterbox doorbell: unacked <type> in <letterbox>/<agent>/inbox/ — please check
  📬 letterbox doorbell: unacked <type> in <letterbox>/<agent>/inbox/ — please check · <8-lowercase-hex>
  ```

  **Impact:** an agent that built its permitted-line rule from the documented example would
  have matched nothing and silently ignored every live doorbell — with no error to diagnose.
  If you configured doorbell acceptance from the docs before 0.3.2, re-check it against the
  two shapes above and match by prefix, never by exact equality.

### Added

- **A docs/code drift gate** (`tests/test_doorbell_docs_drift.sh`, run by `make test`). It
  executes the adapter against a mocked platform CLI, captures the line actually emitted, and
  asserts every documented doorbell line in every tracked file conforms to it. Failures name
  the file and line. A companion mutation harness proves the gate catches planted drift in
  README, SPEC, SKILL and `docs/`, and that it still passes on a clean tree.

  This is the durable fix. The wrong example was a symptom; nothing previously bound the
  documentation to the code.

- **An agent entry point in the README**, naming `skills/agent-letterbox/SKILL.md` as the
  operating manual. The acceptance rule lived only in the skill, and nothing pointed to it.

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
