#!/usr/bin/env bash
#
# renew-cert.sh — Cron/systemd-friendly renewal wrapper around acme.sh --cron.
#
# Usage: ./renew-cert.sh [path-to-env-file]
#
# The env file is optional for renewal (acme.sh already remembers each
# domain's settings), but if given, its DOMAIN is renewed explicitly;
# otherwise all due certificates are renewed.
#
set -euo pipefail

log()  { printf '\033[1;32m[ir-tls]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ir-tls][error]\033[0m %s\n' "$*" >&2; }

ACME_SH="$HOME/.acme.sh/acme.sh"
if [ ! -x "$ACME_SH" ]; then
  err "acme.sh یافت نشد. ابتدا ./install.sh را اجرا کنید."
  exit 1
fi

ENV_FILE="${1:-}"

if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a
  : "${DOMAIN:?متغیر DOMAIN در فایل env تعریف نشده}"
  log "تمدید گواهی برای $DOMAIN ..."
  "$ACME_SH" --renew -d "$DOMAIN" --ecc || {
    err "تمدید $DOMAIN ناموفق بود."
    exit 1
  }
else
  log "تمدید همهٔ گواهی‌هایی که سررسیدشان رسیده ..."
  "$ACME_SH" --cron --home "$HOME/.acme.sh" || {
    err "فرآیند تمدید خودکار با خطا مواجه شد."
    exit 1
  }
fi

log "تمدید با موفقیت انجام شد (یا هیچ گواهی نیازمند تمدید نبود)."
