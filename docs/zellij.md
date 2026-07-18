# Zellij adapter guide

Local-only automatic doorbells for Agent Letterbox using the Zellij CLI (0.44.x).

```text
letter written to inbox
→ adapters/zellij.sh finds a live registered pane (registry-first)
→ zellij action write-chars --pane-id … + action write --pane-id … 13  (when SUBMIT=1)
→ agent checks its durable inbox
```

## Lookup order

1. **Live registry** — `$LETTERBOX_DIR/zellij-agents.tsv`
   `agent`, `ZELLIJ_PANE_ID`, `ZELLIJ_SESSION_NAME`, timestamp
2. **Static patterns** — `$LETTERBOX_DIR/zellij-patterns.tsv`
   `agent`, `pane_id`, `session_name`

Pane ids accept numeric (`0`) or token form (`terminal_0`); the adapter normalizes to Zellij’s `--pane-id` form.

## Safety

- Doorbell text is generic; no task body.
- `LETTERBOX_ZELLIJ_SUBMIT=1` injects into a live agent TUI — dedicated panes only.
- Without SUBMIT, the adapter only reports that a live target was found (no inject).

## Scope

Local Zellij only. No SSH/remote transport, plugins marketplace, desktop apps, webhooks, cmux, tmux, or Herdr in this product.
