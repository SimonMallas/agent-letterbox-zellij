# Letter lifecycle (v0.3)

One page for the verbs that change a letter's state, plus operational views.

## Mental model

```text
[sender publishes letter]
        ↓
 recipient inbox (needs attention)
        ↓
   check (summary) → read <display-id> if body needed
        ↙              ↘
   TASK letter          NON-TASK letter
   requires_ack=true    requires_ack=false
        ↓                      ↓
 non-terminal ACK            file
 (stays in inbox)              ↓
 optional progress         processed/
        ↓
 terminal NACK / RESULT
        ↓
   processed/
```

Doorbell (optional) = wake-up only. Inbox file = source of truth.
Ring success never means the agent read or started a turn.

## Doorbell (additive v0.3)

v0.2 (still valid):
```text
📬 letterbox doorbell: unacked <type> in <letterbox>/<agent>/inbox/ — please check
```

v0.3 emit (token after `please check`):
```text
📬 letterbox doorbell: unacked <type> in <letterbox>/<agent>/inbox/ — please check · <8-hex>
```

- Token is opaque (letter id tail) — never slug/body/path/secret
- `letterbox nudge <id>` re-rings an existing open letter (no new mail)
- Exact full-line equality is a cutover hazard — match prefix + optional token

## Verbs

| Verb | When | Effect |
|---|---|---|
| `reply <id> ack` | Accept a task | Publish ack; write `.md.ack`; **leave letter in inbox** |
| `reply <id> nack` | Decline | Publish nack; move to `processed/` |
| `reply <id> result` | Finish | Publish result; move to `processed/` |
| `file <id\|path>` | Non-task | Move to `processed/`; PATH result/nack needs `--read` |
| `progress <id> <note>` | After ACK | Overwrite progress on `.ack`; shown on `check` with age |
| `read <id\|display-id\|token>` | Need body | Print exact inbox letter (own inbox only) |
| `nudge <id>` | Re-wake | Ring only; no new letter; open letters only |
| `check [--recent\|--thread]` | Glance | Summary only — no bodies |

## Short path

`request` letters may be sent without `--ack` (non-task style) and filed, or tasks may go straight to terminal `result`/`nack` without a prior ACK when the helper allows it. Prefer ACK for multi-turn work.

## Zellij submit-off truth

Without `LETTERBOX_ZELLIJ_SUBMIT=1`, durable mail still lands and **no** recipient terminal ring is injected. Unlike tmux status-line or Herdr toast, Zellij has no alternate visibility path when submit is off.

## Guard rails

- `file` refuses `requires_ack: true`
- PATH form of inbound `result`/`nack` requires `--read` (structural guard C)
- Legacy `done --reply` refuses stamped ACK work — use `reply … result|nack`
- No GOAL/DONE-WHEN in doorbell text
- No archive after ACK only
