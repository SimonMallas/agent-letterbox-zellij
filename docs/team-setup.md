# Zellij team setup

This is the standard Agent Letterbox setup for a live **Zellij** agent team (local only).

**You control Zellij.** Create whatever tabs and panes fit the task. Letterbox never creates your product layout for you during normal use; it registers the pane you launch each agent in, then rings that pane when mail arrives.

## One-time setup

```bash
chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"

letterbox zellij setup --agents pi,claude,grok,hermes --automatic-doorbells
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

`--automatic-doorbells` enables `LETTERBOX_ZELLIJ_SUBMIT=1`.

## Launch agents

In each agent’s Zellij pane:

```bash
source ~/.agent-letterbox/env.sh
letterbox zellij run pi -- pi
```

Registration reads `ZELLIJ_PANE_ID` and `ZELLIJ_SESSION_NAME` from the live pane environment.

## Registry format

`zellij-agents.tsv` columns:

```text
agent	pane_id	session_name	registered_at
```

Example:

```text
pi	0	agents	2026-07-18T12:00:00Z
```

The adapter targets `zellij -s <session_name> action write-chars --pane-id …`.

## Validate

```bash
make test
```
