# Agent Letterbox for Zellij roadmap

## v0.2 scope (local)

Agent Letterbox for Zellij is a filesystem-first coordination system for live local Zellij terminal-agent teams.

Public v0.2 is a **correctness** release: task vs non-task lifecycle, non-terminal ACK with `.md.ack` sidecars, terminal NACK/RESULT, `file` for non-task disposal, publish-before-close ordering, and doorbell-after-local-state when submit is enabled.

**Supported:**

- Durable Markdown letters in per-agent inboxes.
- Task vs non-task handling (`requires_ack`).
- Non-terminal `ack` (accepted WIP + sidecar); terminal `nack` / `result`.
- `letterbox file` for non-task letters.
- Reply-first publication and recipient-owned archival.
- Atomic message publication, advisory locks, lifecycle locks, and filesystem completion proof.
- `letterbox zellij setup` / `run` / `register` bootstrap with live pane **and** session registry.
- Optional opt-in Zellij pane input doorbells (`LETTERBOX_ZELLIJ_SUBMIT=1` via `write-chars` + Enter byte 13).
- **Without submit: durable delivery only — no recipient-side terminal nudge.**
- Static pane/session pattern fallback after live registry.
- Local Zellij only (Zellij 0.44+ syntax).
- User-controlled Zellij layouts: tabs and panes.

**Not supported (deferred / non-goals):**

Carried forward:

- SSH/remote Zellij session packaging.
- Plugins marketplace distribution as a dependency.
- cmux/tmux/Herdr/desktop/webhook adapters in this tree (sibling products).
- Autonomous desktop-agent turns.
- Persistent watchers, relay/proxy services, or required background daemons.
- Multi-machine file transport or networked doorbells.
- A notification-toast path when submit is off (unlike some sibling adapters, Zellij reports live target only).

New explicit deferrals for v0.2:

- Automatic backlog drain tools that bulk-file inboxes.
- `check --deep` reconciliation of letters that older helpers wrongly archived after ACK.
- A frontmatter protocol-version field (v0.2 keeps the on-disk format unchanged).
- Built-in chat bridges.
- Session `resume-log` as a public CLI surface.
- A permanent postmaster role or central dispatcher.

## Next milestones

1. Dogfood with multi-agent Zellij layouts.
2. Soak the published artifact (curl + git install paths, one real ack→result cycle) with and without submit.
3. Keep lifecycle semantics aligned with sibling products without coupling releases.
