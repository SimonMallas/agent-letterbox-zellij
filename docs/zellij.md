# Zellij adapter guide

Local-only automatic doorbells for Agent Letterbox using the Zellij CLI (0.44.x).

```text
letter written to inbox
→ adapters/zellij.sh finds a live registered pane (registry-first)
→ IF LETTERBOX_ZELLIJ_SUBMIT=1:
     zellij action write-chars --pane-id … + action write --pane-id … 13
   ELSE:
     report live target only — no terminal inject
→ agent checks its durable inbox (must still check when submit is off)
```

The terminal gets a ring only when submit is on; the inbox always keeps the message. Doorbell delivery is best-effort. The letter on disk is the record.

## Platform difference (critical)

**Without `LETTERBOX_ZELLIJ_SUBMIT=1`, a durable letter is delivered but no recipient-side terminal nudge occurs.** Unlike some sibling adapters that still surface a status-line or toast when inject is off, the Zellij adapter only prints that a live target was found. Operators and agents must rely on inbox scans unless they deliberately enable submit on dedicated panes.

## Lookup order

1. **Live registry** — `$LETTERBOX_DIR/zellij-agents.tsv`  
   Columns: `agent`, `ZELLIJ_PANE_ID`, `ZELLIJ_SESSION_NAME`, timestamp  
   Override path with `LETTERBOX_ZELLIJ_REGISTRY`.  
   A pane is used only if it is still live in the recorded session.

2. **Static patterns** — `$LETTERBOX_DIR/zellij-patterns.tsv`  
   Columns: `agent`, `pane_id`, `session_name`  
   Override path with `LETTERBOX_ZELLIJ_PATTERNS`.  
   Fallback only — not identity proof after rebuilds.

Pane ids accept numeric (`0`) or token form (`terminal_0`); the adapter normalizes to Zellij’s `--pane-id` form. Registration refuses to silently assign the same live pane+session pair to two agent identities.

## Enable automatic agent input

To inject the standardized doorbell and Enter into the live pane:

```bash
export LETTERBOX_ZELLIJ_SUBMIT=1
```

Setup flag `--automatic-doorbells` (alias `--submit`) turns this on in the generated environment.

Injection uses (Zellij 0.44.x):

```bash
zellij -s <session> action write-chars --pane-id <id> '<doorbell>'
zellij -s <session> action write --pane-id <id> 13
```

Without submit, the adapter exits successfully after locating a live target and printing a non-inject message — it does **not** type into the pane.

## Safety

- Doorbell text is generic; no task body, paths, or secrets.
- `LETTERBOX_ZELLIJ_SUBMIT=1` injects into a live agent TUI — dedicated panes only.
- Doorbell success means a wake-up was submitted to a verified live target — not that the agent read or handled the letter.
- If a safe live target cannot be verified, Letterbox prefers silent durable delivery over risky pane injection.

## Maintenance and recovery

### After pane rebuild, session restart, or host reboot

1. Confirm local Zellij is available:

   ```bash
   zellij --version
   zellij list-sessions
   ```

2. **Re-register every live agent from inside its own pane.** Do not reuse remembered pane ids from a previous layout without verifying liveness.

   ```bash
   letterbox zellij register <agent-id>
   letterbox zellij status
   ```

3. Each agent should scan its inbox (including any `[ACCEPTED]` WIP marked by `.md.ack` sidecars):

   ```bash
   letterbox check
   ```

4. Smoke check:

   - Send a `priority: now` `info` letter to a live agent in another pane.
   - Confirm the letter appears in that agent's inbox.
   - With submit on: confirm the doorbell reaches the intended pane only.
   - With submit off: confirm no inject occurred and the letter is still present.
   - Have the recipient `letterbox file` the info letter.
   - Optionally run one disposable `delegate --ack` → `reply ack` → `reply result` cycle.

### Accepted WIP after interruption

An `[ACCEPTED]` task letter is still open work. Finish with `reply … result` or decline with `reply … nack`. Do not `file` it, and do not hand-delete the `.md.ack` sidecar.

## Scope

Local Zellij only. No SSH/remote transport, plugins marketplace dependency, desktop apps, webhooks, cmux, tmux, or Herdr adapters in this product tree.

## Validate

```bash
make test
```

Live bootstrap tests require `zellij` on PATH with 0.44.x action syntax.
