# Changelog

## [Unreleased] — zellij bootstrap

- `letterbox zellij setup|run|register|unregister|status`
- `adapters/zellij.sh` registry-first doorbell via Zellij CLI `action write-chars --pane-id` + `action write --pane-id 13`
- Registry records agent, `ZELLIJ_PANE_ID`, `ZELLIJ_SESSION_NAME`
- Beginner README for local Zellij teams
- Removed tmux/cmux runtime and docs from this product tree
- Live test: `tests/test_zellij_bootstrap.sh`
