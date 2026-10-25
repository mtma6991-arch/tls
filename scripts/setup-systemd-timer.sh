#!/usr/bin/env bash
#
# setup-systemd-timer.sh — Installs a systemd service+timer that runs
# renew-cert.sh twice a day (acme.sh itself only actually renews when a
# cert is within its renewal window, so frequent runs are harmless).
#
# Usage: sudo ./setup-systemd-timer.sh <path-to-env-file>
#
set -euo pipefail

log()  { printf '\033[1;32m[ir-tls]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ir-tls][error]\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
  err "این اسکریپت باید با sudo/root اجرا شود."
  exit 1
fi

ENV_FILE="${1:-}"
if [ -z "$ENV_FILE" ] || [ ! -f "$ENV_FILE" ]; then
  err "استفاده: sudo $0 config/my-domain.env"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE_ABS="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"
REAL_USER="${SUDO_USER:-$(whoami)}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

SERVICE_PATH="/etc/systemd/system/ir-tls-renew.service"
TIMER_PATH="/etc/systemd/system/ir-tls-renew.timer"

log "ایجاد $SERVICE_PATH ..."
cat > "$SERVICE_PATH" <<SERVICE
[Unit]
Description=IR-TLS Toolkit — certificate renewal
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$REAL_USER
Environment=HOME=$REAL_HOME
ExecStart=$SCRIPT_DIR/renew-cert.sh $ENV_FILE_ABS
SERVICE

log "ایجاد $TIMER_PATH ..."
cat > "$TIMER_PATH" <<TIMER
[Unit]
Description=Run ir-tls-renew.service twice daily

[Timer]
OnCalendar=*-*-* 03,15:00:00
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now ir-tls-renew.timer

log "تایمر فعال شد. وضعیت:"
systemctl status ir-tls-renew.timer --no-pager || true
log "برای مشاهدهٔ زمان اجرای بعدی: systemctl list-timers ir-tls-renew.timer"
