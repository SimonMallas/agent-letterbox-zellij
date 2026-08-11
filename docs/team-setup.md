# Zellij team setup

This is the standard Agent Letterbox setup for a live **Zellij** agent team (local only).

**You control Zellij.** Create whatever tabs and panes fit the task. Letterbox never creates your product layout for you during normal use; it registers the pane you launch each agent in, then (optionally) rings that pane when mail arrives.

## Platform difference

**Without `LETTERBOX_ZELLIJ_SUBMIT=1`, durable letters are still written to the recipient inbox, but no recipient-side terminal nudge is injected.** The adapter only reports that a live target was found. Enable `--automatic-doorbells` only for dedicated agent panes if you want the knock.

## One-time setup

```bash
chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"

letterbox zellij setup --agents planner,reviewer,builder,researcher --automatic-doorbells
source ~/.agent-letterbox/env.sh
```

Creates `~/.agent-letterbox/` by default:

```text
inboxes and processed folders for every named agent
zellij-agents.tsv         # live pane + session self-registrations
zellij-patterns.tsv       # optional static pane/session fallback
env.sh                    # shared Letterbox/Zellij environment
AGENT-LETTERBOX.md        # startup/resume instruction snippet
```

Also links `~/.local/bin/letterbox` and `~/.agents/skills/agent-letterbox`.

`--automatic-doorbells` (alias `--submit`) enables `LETTERBOX_ZELLIJ_SUBMIT=1`. Omit it for durable-only delivery (no inject).

Use another shared location when needed:

```bash
letterbox zellij setup --agents planner,reviewer --dir /shared/letterbox --automatic-doorbells
source /shared/letterbox/env.sh
```

## Launch agents

In each agent’s Zellij pane, launch whatever coding-agent CLI you already run:

```bash
source ~/.agent-letterbox/env.sh
letterbox zellij run planner -- <your-agent-cli>
letterbox zellij run reviewer -- <your-agent-cli>
letterbox zellij run builder -- <your-agent-cli>
letterbox zellij run researcher -- <your-agent-cli>
```

Registration reads `ZELLIJ_PANE_ID` and `ZELLIJ_SESSION_NAME` from the live pane environment. Pane ids change after layout rebuilds — re-run `letterbox zellij run` or `letterbox zellij register <id>`. Do not reuse remembered pane ids.

### Manual registration

```bash
letterbox zellij register reviewer-secondary
letterbox zellij status
letterbox zellij unregister reviewer-secondary
```

### Registry format

`zellij-agents.tsv` columns:

```text
agent	pane_id	session_name	registered_at
```

Illustrative example:

```text
planner	0	agents	2026-07-18T12:00:00Z
```

The adapter targets `zellij -s <session_name> action write-chars --pane-id …` when submit is on. Pane ids accept numeric (`0`) or token form (`terminal_0`); the adapter normalizes to Zellij’s `--pane-id` form.

### Static fallback patterns

Optional `zellij-patterns.tsv`:

```text
# agent<TAB>pane_id<TAB>session_name
planner	0	agents
reviewer	1	agents
```

The adapter prefers the live registry, then falls back to this file. Static rows are a convenience only — never identity proof after rebuilds.

## Send a live handoff (two-step lifecycle)

```bash
source ~/.agent-letterbox/env.sh
export LETTERBOX_AGENT=planner

printf '%s\n' 'Review src/auth.ts and report correctness findings.' |
  letterbox send reviewer delegate auth-review --ack --now
```

Prefer `printf` (or a quoted heredoc `<<'EOF'`) for the body so the shell does not expand `$` or backticks.

Accept work (non-terminal — letter stays in inbox):

```bash
printf '%s\n' 'ACK: I am reviewing it now.' |
  LETTERBOX_AGENT=reviewer letterbox reply <message-id> ack auth-review --now
```

Finish work (terminal — letter moves to `processed/`):

```bash
printf '%s\n' 'RESULT: findings in body.' |
  LETTERBOX_AGENT=reviewer letterbox reply <message-id> result auth-review --now
```

Non-task letters:

```bash
LETTERBOX_AGENT=reviewer letterbox file <message-id>
```

See [lifecycle.md](lifecycle.md) for the full state machine.

## Safety

Automatic terminal input is intentionally opt-in. `LETTERBOX_ZELLIJ_SUBMIT=1` may submit text already waiting in a target pane buffer. Use dedicated agent panes only. The doorbell contains no task content.

## Validate

```bash
make test
```

Then send a harmless `--now` delegate between two live agents in separate panes. Verify the inbox letter always. Verify the pane doorbell only when submit is enabled. Verify ACK (letter still present with sidecar), RESULT, and archived original.
