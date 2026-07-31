#!/usr/bin/env bash
# One-shot health check for the Hermes host. Read-only; safe to run anytime.
# Answers: is it running, did it survive the last boot on its own, is anything
# unexpected listening, and is the box healthy.
set -uo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
ok(){ printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

echo "== Gateway =="
if systemctl --user is-active --quiet hermes-gateway; then
  ok "hermes-gateway active"
else
  bad "hermes-gateway NOT active  (start: hermes gateway start)"
fi

systemctl --user is-enabled --quiet hermes-gateway \
  && ok "enabled at boot" || bad "not enabled (hermes setup gateway)"

# Linger is what makes the user service start without a login. Without it the
# agent only comes back when someone SSHes in — the exact failure this host exists
# to avoid, and it fails silently.
loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q 'Linger=yes' \
  && ok "linger enabled (survives logout / starts at boot)" \
  || bad "LINGER OFF — gateway will not start until you log in"

echo
echo "== Boot durability =="
BOOT=$(uptime -s)
STARTED=$(systemctl --user show hermes-gateway -p ActiveEnterTimestamp --value)
echo "  boot:    $BOOT"
echo "  service: ${STARTED:-<not running>}"

echo
echo "== Scheduled jobs =="
command -v hermes >/dev/null && hermes cron list 2>/dev/null | head -20 || echo "  (hermes not on PATH)"

echo
echo "== Listeners (expect only ssh / tailscale / systemd-resolve) =="
ss -tulpn 2>/dev/null | awk 'NR==1 || /LISTEN/' | head -20

echo
echo "== Resources =="
free -h | head -2
df -h / | tail -1
echo
echo "== Backups =="
ls -1t "$HOME/backups/hermes"/hermes-*.tar.gz 2>/dev/null | head -3 || echo "  none yet — run scripts/backup-hermes.sh"
