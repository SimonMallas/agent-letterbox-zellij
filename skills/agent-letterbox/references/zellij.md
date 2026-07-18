# Zellij doorbell

Automatic live doorbells use `adapters/zellij.sh`.

Lookup order:

1. Live registry (`LETTERBOX_ZELLIJ_REGISTRY`) from `letterbox zellij run` / `register`
   Records `agent`, `ZELLIJ_PANE_ID`, and `ZELLIJ_SESSION_NAME`.
2. Static patterns (`LETTERBOX_ZELLIJ_PATTERNS`)

Delivery (when `LETTERBOX_ZELLIJ_SUBMIT=1`):

```bash
zellij -s <session> action write-chars --pane-id <pane> '<generic doorbell>'
zellij -s <session> action write --pane-id <pane> 13
```

Requires a running local Zellij session. Scope is local-only (no SSH/remote, plugins marketplace, desktop, webhooks, tmux, or cmux).
