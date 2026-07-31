# Hermes Agent Homelab

A self-hosted, always-on AI agent running on a headless Linux box, reachable from any
device over Telegram, surviving reboots with no manual intervention, and reachable
privately over Tailscale — with a deliberate trust boundary around what it's allowed
to execute.

Built as a hands-on exercise in agent hosting: systemd user services, boot durability
without root, credential handling, messaging-gateway auth, and reasoning about the
blast radius of an autonomous process that has shell access.

## What's actually in here

| Path | What it is |
|---|---|
| `docs/SETUP.md` | Architecture, config layout, memory/skills model, security posture, maintenance commands |
| `docs/MIGRATION.md` | The Windows → Linux migration: decisions, what went wrong, and why |
| `scripts/backup-hermes.sh` | Snapshots the agent's entire state (config, memory, skills, cron) to a dated archive |
| `scripts/hermes-health.sh` | One-shot health check: service state, boot durability, disk/RAM, listeners |

Start with `docs/SETUP.md` — it explains the whole system before any of the details.

## The stack

- **Hermes Agent** (Nous Research, MIT) — the agent runtime; ~70 bundled skills, persistent
  memory, cron scheduler, 20+ messaging platform adapters
- **Nous Portal** — model access via OAuth device-code flow (no API keys on disk);
  currently `anthropic/claude-fable-5`
- **systemd user service + linger** — boot-time start without running as root
- **Telegram Bot API** — the interface; outbound polling only, no inbound ports
- **Tailscale** — private mesh for SSH and any future dashboard exposure

## Host

- Ryzen 9 7900X / RX 7900 XT (20GB) / 29GB RAM / 1.8TB
- Ubuntu 26.04 LTS, headless
- Hostname `odd`; sole tenant since the previous GPU-inference homelab was decommissioned
  (preserved at [odysseus-gpu-homelab](https://github.com/bbeck17/odysseus-gpu-homelab))

## Why this exists

Most "run an AI agent" writeups stop at "it replied to me once." The interesting part is
everything after: making it start itself after a power cut with nobody logged in, keeping
its credentials off disk where possible and unreadable where not, restricting who can
command it, and being honest about the fact that an agent with a shell and a web browser
is a prompt-injection target running as your user.

Personal project. Not affiliated with Nous Research.
