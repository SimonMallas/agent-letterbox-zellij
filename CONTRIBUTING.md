# Contributing to Agent Letterbox for Zellij

## Scope (v0.1 local)

**Supported**

- Durable Markdown letters, reply-first handling, atomic publication, advisory locks
- Automatic opt-in Zellij doorbells to live registered panes
- Local Zellij sessions only

**Not in scope**

- cmux, tmux product trees, desktop agents, webhooks, remote/SSH transport packaging, marketplace plugins, servers beyond local Zellij

## Development

```bash
chmod +x bin/letterbox adapters/*.sh tests/*.sh
make test
```

Expect each script to print an explicit **PASS** (or SKIP when Zellij is unavailable).

## Guidelines

- Keep the CLI dependency-free (Bash + standard Unix tools + Zellij)
- Do not reintroduce cmux, tmux, or Herdr adapters into this product tree
