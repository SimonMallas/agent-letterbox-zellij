# Agent Letterbox for Zellij

## Ring the bell. Create the team. Keep the record.

![Eight coding agents handing work to each other over Agent Letterbox — panes ring as letters land](assets/hero/letterbox-team.gif)

*Shown: the cmux edition mid-storm — same letters, same protocol. This edition rings Zellij panes.*

**Agent Letterbox for Zellij turns separate coding-agent terminals into a live team inside [Zellij](https://zellij.dev).**


## v0.3 at a glance

Durable letters remain the record. v0.3 adds addressable doorbells (` · <8-hex>` after `please check`), `nudge`, summary `check` + `read`, optional ACK `progress`, and read-only `check --thread`. Without `LETTERBOX_ZELLIJ_SUBMIT=1`, mail lands with **no** terminal ring.

## What it is

Agent Letterbox is not a model, a new terminal, or a second agent harness. It is the coordination layer that lets the agents you already run hand work to one another without making you the human message relay.

A task lands as a durable letter in a teammate's inbox. Optionally, when submit is enabled, the doorbell rings in the live pane:

```text
📬 letterbox doorbell: unacked <type> in <letterbox>/<agent>/inbox/ — please check
📬 letterbox doorbell: unacked <type> in <letterbox>/<agent>/inbox/ — please check · <8-lowercase-hex>
```

The agent wakes, picks up the real task from disk, replies, and keeps the work flowing. The terminal gets a ring; the inbox keeps the message.

> **Agent mail that waits safely—and a bell brings it alive.**

### Platform difference (read this)

**Without `LETTERBOX_ZELLIJ_SUBMIT=1`, a durable letter is still delivered to the recipient's inbox, but no recipient-side terminal ring occurs.** The adapter only reports that a live target was found. Agents must still check their inbox at startup, after tasks, and at checkpoints. Enable `--automatic-doorbells` (or export `LETTERBOX_ZELLIJ_SUBMIT=1`) only on dedicated agent panes if you want the terminal to receive a ring.

## The Agent Letterbox family

One product per terminal — the same letters, the same protocol, and the same core test suite, plus the tests each terminal needs. Pick the one matching the terminal you already run:

- **[cmux](https://github.com/SimonMallas/agent-letterbox-cmux)** — primary entry point
- [tmux](https://github.com/SimonMallas/agent-letterbox-tmux)
- [Herdr](https://github.com/SimonMallas/agent-letterbox-herdr)
- [Zellij](https://github.com/SimonMallas/agent-letterbox-zellij) — terminal ring requires `LETTERBOX_ZELLIJ_SUBMIT=1`

You are reading the **Zellij** edition.

## Why it exists

Without coordination, a multi-agent workflow means juggling panes, copying task text, remembering who owns what, and hoping an agent eventually sees a message.

Directly injecting the full task into another terminal is fast, but the terminal becomes the only message record. Agent Letterbox keeps the fast part—the optional live doorbell—while putting the actual work in a durable, inspectable letter.

```text
full task    → durable inbox letter
live wake-up → short generic doorbell (only when SUBMIT=1)
reply        → sender inbox
archive      → recipient processed history
```

Read the full comparison in [Why Letterbox?](docs/why-letterbox.md).


## More memory than message

When one agent types into another's terminal, the message is spent the
moment it lands: the pane scrolls, the session compacts, and nothing
remains. Between agents there is no phone keeping a copy — an injected
handoff is the ONLY copy, and it dies with the scrollback.

A letter is different. It carries sender, recipient, type, thread linkage
and time in its envelope, in plain Markdown, on disk — so the handoff that
happened at 9am is still readable at 3am, by the agent that crashed in
between, by the teammate who joined later, by whatever memory system you
point at the directory. Coordination that leaves records behind is a team
that can remember what it did.

What that buys, mechanically:

- **A crashed or compacted agent recovers its context from its own
  inbox** — restore is reading, not reconstruction.
- **"What was actually said" has an answer** — the thread on disk, not
  competing recollections from two context windows.
- **Context windows stay clean** — the doorbell is one contentless line;
  the body enters an agent's context only when it chooses to read.
- **Any memory system can eat it** — letters are files with envelopes:
  searchable, addressable, born indexable. We are deliberately only the
  storage half; the librarian can be anyone's.

## How a task moves

Public v0.3 is a **correctness** release: acknowledgements no longer file work away.

```text
send task (requires_ack=true)
  → recipient: reply ack     # accepted WIP; letter stays in inbox (.md.ack)
  → recipient: does the work
  → recipient: reply result  # terminal; letter moves to processed/
```

Non-task letters (`info` / `status` / received replies) are filed with no invented response:

```bash
letterbox file <id>
```

See [SPEC.md](SPEC.md) and [docs/lifecycle.md](docs/lifecycle.md).

## What this opens up

- **Durable coordination** — letters survive offline, restart, and missed knocks.
- **Optional near-instant wake-up** — with submit enabled, a live Zellij agent can be nudged without human copy/paste.
- **Real handoffs** — implementation, review, research, QA, and fixes move as explicit owned work.
- **Clear responsibility** — task letters require ACK/NACK/RESULT; ACK means in progress, not done.
- **Evidence over claims** — inbox, reply, sidecar, and processed files show what happened even when an agent conversation is gone.
- **Less human relay work** — you direct the team instead of pasting the same request between terminals.

## What you need

- Bash, Git, and **Zellij 0.44+** (`zellij --version`)
- A running local Zellij session
- Agents you already run in terminals (any coding-agent CLI you already use)

No servers beyond Zellij’s local multiplexer. No SSH/remote transport, plugins marketplace, desktop apps, webhooks, cmux, tmux, or Herdr in this product tree.

## Install

### Or: add the skill straight to your agent

```bash
npx skills add SimonMallas/agent-letterbox-zellij
```

### Option A — Recommended: copy/paste installer

```bash
curl -fsSL https://raw.githubusercontent.com/SimonMallas/agent-letterbox-zellij/main/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
letterbox zellij setup --agents planner,reviewer,builder,researcher --automatic-doorbells
source "$HOME/.agent-letterbox/env.sh"
```

### Option B — Manual Git install

```bash
git clone https://github.com/SimonMallas/agent-letterbox-zellij.git \
  ~/src/agent-letterbox-zellij
cd ~/src/agent-letterbox-zellij
chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"
letterbox zellij setup --agents planner,reviewer,builder,researcher --automatic-doorbells
source "$HOME/.agent-letterbox/env.sh"
```

Omit `--automatic-doorbells` if you want durable mail only (no pane inject). Check:

```bash
letterbox --version
zellij --version
echo "$LETTERBOX_DIR"
```

## Launch agents (you choose the panes)

Open Zellij and arrange agents however the task requires. In **each agent pane**:

```bash
source "$HOME/.agent-letterbox/env.sh"

letterbox zellij run planner -- <your-agent-cli>
# other panes:
letterbox zellij run reviewer -- <your-agent-cli>
letterbox zellij run builder -- <your-agent-cli>
letterbox zellij run researcher -- <your-agent-cli>
```

`zellij run` registers the current `ZELLIJ_PANE_ID` **and** `ZELLIJ_SESSION_NAME` for live targeting, then starts the command.

If a pane was rebuilt:

```bash
letterbox zellij register planner
letterbox zellij status
```

## Send a live handoff (ack, then result)

```bash
source "$HOME/.agent-letterbox/env.sh"
export LETTERBOX_AGENT=planner

printf '%s\n' 'Review src/auth.ts and report correctness findings.' |
  letterbox send reviewer delegate auth-review --ack --now
```

Prefer `printf … | letterbox …` for bodies. Avoid unquoted heredocs when the text may contain `$` or backticks.

1. Letter lands in the reviewer’s inbox (always, if publish succeeds)
2. **If** `LETTERBOX_ZELLIJ_SUBMIT=1`: doorbell is injected into the reviewer’s registered pane (`write-chars` + Enter byte 13). **If not:** no terminal nudge — the letter still waits in the inbox
3. The reviewer accepts (non-terminal):

```bash
printf '%s\n' 'ACK: reviewing auth.ts now.' |
  LETTERBOX_AGENT=reviewer letterbox reply <message-id-or-inbox-path> ack auth-review --now
```

4. The letter stays in inbox with an `.md.ack` sidecar (`letterbox check` shows `[ACCEPTED]`)
5. When finished, close it:

```bash
printf '%s\n' 'RESULT: no critical issues; two nits in findings.md.' |
  LETTERBOX_AGENT=reviewer letterbox reply <message-id-or-inbox-path> result auth-review --now
```

Only `nack` or final `result` moves the original letter to `processed/`.

## Using a pre-release checkout

If you installed an earlier checkout from `main`, reinstall from the current branch and use the lifecycle commands above. v0.3 keeps the optional additive `thread` field on ownership replies; existing letters remain valid. Early scripts that send `ack`, `nack`, or `result` directly must use `letterbox reply` instead, and delegates must include `--ack`. All agents in one team should run the same v0.3 helper.

## Test

```bash
make test
```

Requires `zellij` on PATH (0.44.x syntax is the authority for this product).

## Tested with

The letter protocol is identical across the Agent Letterbox family; only the doorbell adapter differs per terminal. Six agent CLIs — **Claude Code, Gemini CLI, OpenAI Codex, OpenCode, Cursor Agent, and GitHub Copilot CLI** — have completed the full live cycle (durable letter, doorbell ring, `ACK`, then `RESULT`) against the [cmux edition](https://github.com/SimonMallas/agent-letterbox-cmux#tested-with), which carries the version matrix and field notes. Teaching your agent works the same way here: a short teach file in the working directory and a pane it can be rung in.

## Learn more

**If you are an agent, start here:** [skills/agent-letterbox/SKILL.md](skills/agent-letterbox/SKILL.md) — the operating manual. It carries the doorbell acceptance rule you need to recognise a knock, the reply lifecycle, and the safety boundaries. The list below is background.

- [docs/lifecycle.md](docs/lifecycle.md) — task vs non-task, ACK/NACK/RESULT, `file`
- [docs/why-letterbox.md](docs/why-letterbox.md) — why durable letters plus generic doorbells beat direct task injection
- [docs/team-setup.md](docs/team-setup.md) — full Zellij team bootstrap
- [docs/zellij.md](docs/zellij.md) — adapter details, registry/session, SUBMIT behaviour, recovery
- [SPEC.md](SPEC.md) — normative protocol (v0.3)
- [SECURITY.md](SECURITY.md) — threat model
- [ROADMAP.md](ROADMAP.md) — scope and deferred items
- [CHANGELOG.md](CHANGELOG.md) — user-visible changes

## License

[MIT](LICENSE)
