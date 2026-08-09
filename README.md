# Hermes Agent Homelab (The Architect)

**Status**: Active. Running 24/7 on Ryzen 9 / RX 7900 XT.

A self-hosted, always-on AI agent (Hermes) running on a headless Linux box ("The Architect"), reachable from any device over Telegram, surviving reboots with no manual intervention, and reachable privately over Tailscale — with deliberate trust boundaries around what it's allowed to execute.

---

## What's in Here

| Path | Purpose |
|------|---------|
| `docs/SETUP.md` | Full architecture, systemd config, security posture, maintenance commands |
| `docs/MIGRATION.md` | Windows → Linux migration: decisions, pitfalls, lessons |
| `scripts/backup-hermes.sh` | Weekly snapshot: config, memory, skills, cron state (runs Sundays @ 12am) |
| `scripts/hermes-health.sh` | One-shot health check: service state, listeners, disk/RAM status |
| `README.md` | You are here |

**Start with `docs/SETUP.md`** — it explains the whole architecture before diving into details.

---

## The Stack

- **Hermes Agent** (Nous Research, MIT) — the agent runtime; 70+ bundled skills, persistent memory, cron scheduler, 20+ messaging platform adapters
- **Nous Portal** — model access via OAuth device-code flow (no API keys on disk); currently using `anthropic/claude-haiku-4.5`
- **systemd user service + linger** — boot-time auto-start without root
- **Telegram Bot API** — outbound polling only (no inbound ports exposed)
- **Tailscale** — private mesh for SSH; auth-gated access
- **Obsidian Sync** — cross-machine vault over autossh tunnel (Windows ↔ Linux)

---

## Hardware & Host

- **CPU**: AMD Ryzen 9 7900X
- **GPU**: AMD Radeon RX 7900 XT (20GB VRAM)
- **RAM**: 29GB
- **Storage**: 1.8TB
- **OS**: Ubuntu 26.04 LTS, headless
- **Hostname**: `odd`

---

## Running the Agent

**Start Hermes:**
```bash
systemctl --user start hermes
```

**View logs:**
```bash
journalctl --user -u hermes -f
```

**Health check:**
```bash
./scripts/hermes-health.sh
```

**Backup state (manual):**
```bash
./scripts/backup-hermes.sh
```

**Restart after a crash:**
```bash
systemctl --user restart hermes
```

---

## Key Features

✅ **Boot durability** — Starts automatically on power-up, no human intervention  
✅ **Credential security** — OAuth device-code flow (no API keys on disk)  
✅ **Multi-platform messaging** — Telegram, Discord, Slack, etc.  
✅ **Persistent memory** — Learns your preferences, remembers conversation context  
✅ **Skill system** — 70+ reusable task procedures (GitHub PRs, email, meetings, etc.)  
✅ **Cron scheduler** — Run jobs on schedule (backups, monitoring, etc.)  
✅ **Cross-machine sync** — Obsidian vault syncs to Windows laptop via autossh tunnel  

---

## Maintenance Schedule

| Task | Frequency | Command |
|------|-----------|---------|
| Backup state | Weekly (Sun 12am) | `./scripts/backup-hermes.sh` (automated) |
| Health check | Monthly | `./scripts/hermes-health.sh` |
| Skill updates | On-demand | Pull from `bbeck17/ops` repo, restart Hermes |
| OS updates | Quarterly | `sudo apt update && sudo apt upgrade` |

---

## Troubleshooting

**Agent not responding on Telegram?**
1. Check service status: `systemctl --user status hermes`
2. View recent logs: `journalctl --user -u hermes -n 50`
3. Restart: `systemctl --user restart hermes`
4. If persistent, check internet connectivity and Telegram token

**Obsidian vault not syncing?**
1. Check autossh tunnel: `ps aux | grep autossh`
2. Verify SSH key permissions: `ls -l ~/.ssh/id_rsa` (should be 600)
3. Test SSH manually: `ssh -i ~/.ssh/id_rsa user@windows-pc`

**High memory/CPU usage?**
1. Check what's running: `top` or `htop`
2. Review recent cron jobs: `systemctl --user status hermes`
3. Clear old logs: `journalctl --user --vacuum=30d`

---

## Why This Exists

Most "run an AI agent" guides stop at "it replied to me once." The hard part is after:
- Making it start itself after power loss with nobody logged in
- Keeping credentials off disk where possible
- Restricting who can command it
- Being honest that an agent with shell access + web browser = prompt-injection risk

This repo documents all of that for future reference and reproducibility.

---

## Files & Directories Overview

```
hermes-homelab/
├── README.md                    # This file
├── .gitignore                   # Exclude OS junk, secrets, logs
├── docs/
│   ├── SETUP.md                # Full architecture & config
│   └── MIGRATION.md            # Windows→Linux migration notes
└── scripts/
    ├── backup-hermes.sh        # Weekly state snapshot
    └── hermes-health.sh        # Health check one-shot
```

---

## Contact & Updates

**Owner**: Braxton Beck (braxton@idlewrk.com)  
**Repo**: https://github.com/bbeck17/hermes-homelab (private)  
**Last updated**: 2026-08-09  
**Next review**: 2026-09-09

For infrastructure changes, operational decisions, or skill improvements, see `bbeck17/ops`.
