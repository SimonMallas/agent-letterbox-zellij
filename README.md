# Agent Letterbox for Zellij

## Ring the agent. Keep the message. Work as a team.

**Agent Letterbox for Zellij turns separate coding-agent terminals into a live team inside [Zellij](https://zellij.dev).**

A message is saved safely on disk. When the recipient is live, Zellij receives one short instruction in its pane:

```text
📬 letterbox doorbell: unacked delegate in <letterbox>/<agent>/inbox/ — please check
```

The agent checks the durable message, replies, and hands work onward.

> **The doorbell makes it a team.**

## What you need

- Bash, Git, and **Zellij 0.44+** (`zellij --version`)
- A running local Zellij session
- Agents you already run in terminals (Claude Code, Pi, Grok, Hermes, …)

No servers beyond Zellij’s local multiplexer. No SSH/remote transport, plugins marketplace, desktop apps, webhooks, cmux, or tmux.

## Install (copy / paste)

```bash
git clone https://github.com/SimonMallas/agent-letterbox-zellij.git \
  ~/Developer/agent-letterbox-zellij
cd ~/Developer/agent-letterbox-zellij

chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"

# One-time team bootstrap (creates ~/.agent-letterbox and links the CLI)
letterbox zellij setup --agents pi,claude,grok,hermes --automatic-doorbells
source "$HOME/.agent-letterbox/env.sh"
```

Check:

```bash
letterbox --version
zellij --version
echo "$LETTERBOX_DIR"
```

## Launch agents (you choose the panes)

Open Zellij and arrange agents however the task requires. In **each agent pane**:

```bash
source "$HOME/.agent-letterbox/env.sh"

letterbox zellij run pi -- pi
# other panes:
letterbox zellij run claude -- claude
letterbox zellij run grok -- grok
letterbox zellij run hermes -- hermes
```

`zellij run` registers the current `ZELLIJ_PANE_ID` **and** `ZELLIJ_SESSION_NAME` for live doorbells, then starts the command.

If a pane was rebuilt:

```bash
letterbox zellij register pi
letterbox zellij status
```

## Send a live handoff

```bash
source "$HOME/.agent-letterbox/env.sh"
export LETTERBOX_AGENT=pi

printf '%s\n' 'Review src/auth.ts and report correctness findings.' |
  letterbox send claude delegate auth-review --ack --now
```

1. Letter lands in Claude’s inbox
2. Doorbell is injected into Claude’s registered Zellij pane (`write-chars` + `write 13`)
3. Claude ACKs / works / replies with `letterbox reply`
4. Original letter is archived

> `LETTERBOX_ZELLIJ_SUBMIT=1` (set by `--automatic-doorbells`) injects into a live pane. Use dedicated agent panes only.

## Test

```bash
make test
```

Requires `zellij` on PATH (0.44.x syntax is the authority for this product).

## Learn more

- [docs/team-setup.md](docs/team-setup.md) — full Zellij team bootstrap
- [docs/zellij.md](docs/zellij.md) — adapter details and safety
- [SPEC.md](SPEC.md) — message format and reply-first semantics
- [SECURITY.md](SECURITY.md) — threat model

## License

[MIT](LICENSE)
