#!/usr/bin/env bash
#
# install.sh — Installs acme.sh and prepares IR-TLS Toolkit.
#
# Usage: ./install.sh [email]
#
set -euo pipefail

EMAIL="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;32m[ir-tls]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ir-tls][warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ir-tls][error]\033[0m %s\n' "$*" >&2; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "دستور مورد نیاز یافت نشد: $1 — لطفاً آن را نصب کنید."
    exit 1
  fi
}

log "بررسی پیش‌نیازها..."
require_cmd curl

if [ -d "$HOME/.acme.sh" ]; then
  log "acme.sh از قبل در \$HOME/.acme.sh نصب است؛ از نصب مجدد صرف‌نظر می‌شود."
else
  log "در حال نصب acme.sh ..."
  if [ -n "$EMAIL" ]; then
    curl https://get.acme.sh | sh -s email="$EMAIL"
  else
    warn "ایمیلی داده نشده؛ بعداً می‌توانید با 'acme.sh --register-account -m you@example.com' ثبت کنید."
    curl https://get.acme.sh | sh
  fi
fi

# shellcheck disable=SC1090
ACME_SH="$HOME/.acme.sh/acme.sh"
if [ ! -x "$ACME_SH" ]; then
  err "نصب acme.sh موفق نبود؛ مسیر $ACME_SH یافت نشد."
  exit 1
fi

chmod +x "$SCRIPT_DIR"/scripts/*.sh

log "نصب کامل شد."
log "مرحلهٔ بعد: فایل config/example.env را کپی و تکمیل کنید، سپس scripts/issue-cert.sh را اجرا کنید."
log "راهنمای کامل: README.md"
