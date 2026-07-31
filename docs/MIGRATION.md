# Migration: Windows desktop → headless Linux host

Two days, 2026-07-30 → 07-31. Hermes was first stood up on a Windows 11 daily driver,
then moved to a dedicated headless box. This is what drove the move and what went wrong.

## Why move at all

The Windows install worked. It also had a structural problem: the gateway was registered
as a **Scheduled Task triggered at user login**. That means:

- The desktop had to be powered on *and logged in* for the agent to be reachable
- Sleep killed it
- Scheduled automations silently stopped whenever either was true

An always-on agent on a machine that sleeps is a contradiction. The fix wasn't
configuration, it was hosting.

## Why not one install per machine

The obvious-looking option — install on each machine — is wrong for this tool. Memory,
skills, and session history are files bound to a single home directory. Two installs
means two agents that diverge permanently: each learns things the other never knows.

Instead: **one agent, many surfaces.** The messaging gateway exposes it to Telegram, so
the desktop, the laptop, and a phone all talk to the same brain with the same memory.
No sync, no merge conflicts, because there's only ever one copy.

The cost is a single point of failure — the host must be up. That's precisely why the
host became a dedicated always-on box rather than a laptop.

## Choosing the host

The target already ran a GPU inference homelab (llama.cpp + a 30B model, plus supporting
containers). First instinct was to wipe the machine. That was reconsidered: the OS,
GPU drivers, Tailscale membership, and systemd tooling on it were all *assets* for
hosting an agent. Wiping to install a per-user Python app would have destroyed
infrastructure to make room for something that needed none of it.

What actually got removed was the previous workload's **services**, not the machine —
after verifying its documentation and code were pushed to GitHub. Freed ~22GB disk and
~20GB RAM. The OS, drivers, and network identity stayed.

## Migration sequence

1. **Stop the old gateway first.** Telegram allows one `getUpdates` consumer per bot;
   two gateways on one token conflict. Non-obvious and easy to trip over.
2. Fresh install on the new host + `hermes setup --portal` (device-code OAuth over SSH).
3. **Rebuild identity rather than copy it.** Copying the whole home directory would have
   dragged Windows paths in `config.yaml` and a venv built for the wrong OS. With only a
   day of accumulated memory, re-answering the agent's profile prompt was cleaner than
   migrating state. *This calculus changes fast* — at three months of memory, a real
   migration of `memories/` and `state.db` would be worth the path fixups.
4. Gateway as a user service + linger; verify against boot timestamps.
5. Decommission the source install: stop service, uninstall the Scheduled Task, delete
   the tree, strip PATH entries.

## What went wrong (and the lessons)

**Chasing `npm audit` to zero.** `hermes doctor` reported 2 build-tooling advisories.
Attempting to clear them turned into a rabbit hole: the fixes required either a breaking
eslint major bump or a *downgrade* of a runtime dependency below what the app declares,
and the vendor's own lockfile had a peer-dependency conflict (`eslint-plugin-react@7.22.0`
pinned against `eslint ^9`) that made `npm audit fix` fail outright with ERESOLVE.

Worse, running a bare `npm install` at the repo root — instead of the vendor's own
`hermes update`, which deliberately scopes its installs and skips the Electron desktop
workspace — pulled in Electron and node-pty and inflated the audit count from 15 to 28.

*Lesson:* a vendor-managed repo's dependency tree is the vendor's artifact. Mutate it only
through the vendor's entrypoints, judge health by the vendor's own scorecard, and route
genuinely upstream findings upstream. Vulnerability management is triage, not
scanner-zero — "assessed unreachable, remediation blocked on vendor, tracked" is a
finished piece of work.

**Elevated installers leave admin-owned files in your profile.** The Windows gateway
install required UAC, and created files owned by SYSTEM inside `%LOCALAPPDATA%`. Normal-user
deletion then failed *partially* — the recursive delete aborted on the first denied
directory, leaving ~750 files behind while reporting little. Cleanup needed an elevated
shell. Another argument for avoiding elevation wherever a tool doesn't require it.

**Killing a process by its path instead of its purpose.** During cleanup, a delete failed
because `<install>/bin/uv.exe` was locked by two running processes. They were assumed to
be leftovers of the installer and killed — they were actually the machine's unrelated MCP
server, which had been launched through that binary. Cause: the installer had prepended
its `bin/` to PATH, so a *generic* Python launcher (`uv`) resolved to the doomed copy for
everything on the system. Killing them and deleting the binary took down working tooling
mid-session.

*Lesson:* an executable's path tells you where a process was launched from, not what it
is. Check the command line (`Get-Process -Id N | Select-Object CommandLine`, `ps -fp PID`)
before killing anything to release a lock. And treat PATH mutations as part of a tool's
blast radius — during uninstall, check whether other software started resolving shared
executables (python, node, uv, git) through the directory you're about to delete.

**Stale reverse-proxy rules outlive their backend.** After the old workload was removed,
`tailscale serve` still proxied two hostnames to now-dead localhost ports. Harmless, but
dead config that would have been baffling months later. Cleared with `tailscale serve reset`
— which, worth knowing, does not affect tailnet membership or SSH.

## Outcome

| Before | After |
|---|---|
| Windows 11 daily driver | Headless Ubuntu, dedicated |
| Scheduled Task, starts at login | systemd user service + linger, starts at boot |
| Dies on sleep/logout | Verified up 84s before first login post-reboot |
| Reachable while desktop awake | Reachable from any device via Telegram |
| Shares a machine with everything | Sole tenant, 28GB RAM free |

Total downtime for the agent: about an hour. Nothing was lost that mattered, because the
only state worth keeping — one day of distilled memory — was cheaper to regenerate by
conversation than to migrate.
