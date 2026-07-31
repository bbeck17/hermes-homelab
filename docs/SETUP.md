# Setup & Architecture

Hermes Agent v0.19.1 on `odd` (headless Ubuntu 26.04). Installed 2026-07-31.

## Mental model

Hermes is one long-running process with persistent state on disk. Everything about its
behaviour — identity, memory, capabilities, schedule — is plain files under a single
home directory. There is no server/client split: a second install on another machine
would be a second, unrelated agent with its own memory.

That single fact drove every architectural decision here.

## Install

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
hermes setup --portal     # OAuth; on a headless box this falls back to device-code
```

Per-user install under `~/.hermes` — **no root required, and none should be granted.**
The agent gets shell access; giving it root would make every later security decision moot.

Device-code login matters on a headless host: `--portal` wants to open a browser, and
falls back to printing a URL + code to paste into a browser on another machine. One
OAuth covers both the model and the Tool Gateway (web search, image/video gen, TTS,
STT, browser automation).

## File layout (`~/.hermes/`)

| Path | Role |
|---|---|
| `config.yaml` | All settings — model, terminal backend, agent options |
| `.env` | API keys + Telegram bot token. Plaintext. Mode 600. Never committed |
| `auth.json` | Portal OAuth state |
| `SOUL.md` | Durable identity/persona; first thing in the system prompt |
| `memories/USER.md` | Distilled model of the operator, injected every session |
| `memories/MEMORY.md` | Accumulated working knowledge |
| `state.db` | SQLite; every session transcript, FTS5-searchable |
| `skills/` | Markdown runbooks = capabilities (~70 bundled) |
| `cron/jobs.json` | Scheduled tasks |
| `hermes-agent/` | Source checkout — mutate only via `hermes update` |

Backing up the agent's entire mind is copying this directory. Migrating hosts is moving it.

## Boot durability (the part worth understanding)

The gateway is installed as a **systemd user service**, not a system service:

```bash
hermes setup gateway          # installs ~/.config/systemd/user/hermes-gateway.service
loginctl enable-linger "$USER"   # the load-bearing line
```

By default a user service only runs while that user has a session — on a headless box
that means it wouldn't start until someone SSH'd in, and would die on logout. `linger`
tells systemd to start the user manager at boot and keep it running regardless of login.

Result: boot-time durability *without* a root-owned daemon. The alternative
(`sudo hermes gateway install --system`) works but runs an agent with shell access at
higher privilege for no additional capability.

**Verified, not assumed:**

```
uptime -s                → 2026-07-31 11:43:55
ActiveEnterTimestamp     → 2026-07-31 11:46:03
first SSH login          → 2026-07-31 11:47:26
```

Service was up 84 seconds before anyone logged in. Confirmed by messaging the bot from
a phone without touching SSH.

The gateway also ticks the cron scheduler every 60s — so scheduled automations depend on
it running. Gateway down = no automations, silently.

## Memory model

Three layers, deliberately different lifetimes:

- **USER.md** — distilled facts about the operator. Injected into every system prompt.
  Small on purpose.
- **MEMORY.md** — accumulated knowledge. The agent periodically nudges itself to persist
  things worth keeping; can also be told directly.
- **state.db** — full transcripts, searched on demand via the agent's `session_search`
  tool for detail that didn't survive distillation.

Distill for the common case, search for the long tail. All plaintext — no credentials
should ever be committed to agent memory.

## Skills

A skill is a markdown runbook loaded on demand — procedural memory. Three ways they change:

1. **Created** from experience (`/learn <dir|url|this chat>`, or "save that as a skill")
2. **Improved** in place when corrected during use
3. **Curated** by a background pass (~7d after install) that consolidates and archives
   *agent-created* skills only; nothing hard-deleted. `hermes curator run --dry-run`

Open standard (agentskills.io), so they're portable markdown.

**Threat note:** a skill is trusted instruction text injected into the agent's context.
Installing a third-party skill is equivalent to running an unreviewed script. Read first.

## Gateway auth model

- Telegram bot created via @BotFather; token stored in `.env` (a credential — rotate with
  `/revoke` if exposed, and never screenshot it)
- **Allowlist by numeric user ID.** Unknown users who DM the bot get a pairing code, not
  an agent. `GATEWAY_ALLOW_ALL_USERS=true` on a bot with shell access would be indefensible
- Home channel set to the same DM — cron output and notifications land there
- **Only one gateway may poll a given bot.** Telegram's `getUpdates` allows a single
  consumer; two gateways on one token fight and messages land unpredictably. This is why
  migration required stopping the old gateway *before* starting the new one

No inbound ports. Telegram is outbound polling, so the host's only listeners are SSH,
Tailscale, and systemd-resolve.

## Security posture

| Control | State |
|---|---|
| Install privilege | Per-user, no root |
| Service privilege | User service; not a root daemon |
| Terminal backend | `local` — commands run as the login user with real FS + tailnet access |
| Dangerous-command gate | `/approvals smart` (persistent) |
| Cron prompt scanning | Injection/exfil patterns blocked at create time |
| Inbound exposure | None |
| Credentials at rest | `.env` plaintext, mode 600; Portal uses OAuth tokens not API keys |

**The live trust boundary, stated plainly:** the terminal backend is `local`, and the
agent has web search and browser automation. Content it fetches is untrusted input that
may contain instructions — so the realistic risk isn't "I ask it to do something reckless,"
it's prompt injection via a poisoned page or file, executing as my user, on a machine
that's a Tailscale node. The approval gate is a mitigation, not a boundary.

The actual boundary is a Docker terminal backend, planned before any untrusted-binary work:

```bash
hermes -p ctf                 # separate profile: own config, memory, skills
hermes -p ctf setup terminal  # → Docker
```

A second profile rather than switching the main one: the daily driver stays useful
(real filesystem access), and untrusted work runs contained. Isolation over detection.

## Cron

Gateway ticks every 60s and runs due jobs in **fresh sessions** — prompts must be
self-contained. Useful patterns:

- `[SILENT]` in the response suppresses delivery → watchdogs that only speak when
  something's wrong
- `no_agent=True` + a script → stdout delivered verbatim, zero tokens, no inference
- A pre-check script emitting `{"wakeAgent": false}` skips the LLM for that tick →
  poll cheaply, think only on change
- `context_from` chains jobs into pipelines
- Jobs snapshot provider/model at creation and **fail closed** if the global default
  changes, preventing silent spend
- `enabled_toolsets=["web","file"]` trims per-job tool schemas — cheaper and smaller
  attack surface

Cost: the interactive default (`claude-fable-5`, $8/$40 per Mtok) is wasteful unattended.
Pin `claude-haiku-4.5` ($0.80/$4) or cheaper on scheduled jobs.

## Maintenance

| Command | Purpose |
|---|---|
| `hermes doctor` | Health check. Judge by the "Found N issues" tally, not the ⚠ count |
| `hermes update` | Pull code + deps. **Never** run raw npm/git inside `hermes-agent/` |
| `hermes setup [model\|terminal\|gateway\|tools\|agent]` | Re-run wizard sections |
| `hermes gateway status\|start\|stop` | Service control |
| `journalctl --user -u hermes-gateway -f` | Live gateway logs |
| `hermes -p <name>` | Separate profile with its own state |
