#!/usr/bin/env bash
#
# issue-cert.sh — Issues a TLS certificate via DNS-01, trying multiple CAs.
#
# Usage: ./issue-cert.sh <path-to-env-file>
#
set -euo pipefail

log()  { printf '\033[1;32m[ir-tls]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ir-tls][warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ir-tls][error]\033[0m %s\n' "$*" >&2; }

ENV_FILE="${1:-}"
if [ -z "$ENV_FILE" ] || [ ! -f "$ENV_FILE" ]; then
  err "فایل پیکربندی پیدا نشد. استفاده: $0 config/my-domain.env"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

: "${DOMAIN:?متغیر DOMAIN در فایل env تعریف نشده}"
: "${EMAIL:?متغیر EMAIL در فایل env تعریف نشده}"
: "${DNS_PROVIDER:?متغیر DNS_PROVIDER در فایل env تعریف نشده}"

CA_ORDER="${CA_ORDER:-letsencrypt,zerossl,buypass}"
KEY_TYPE="${KEY_TYPE:-ec-256}"
ACME_SH="$HOME/.acme.sh/acme.sh"

if [ ! -x "$ACME_SH" ]; then
  err "acme.sh یافت نشد. ابتدا ./install.sh را اجرا کنید."
  exit 1
fi

DOMAIN_ARGS=(-d "$DOMAIN")
if [ -n "${EXTRA_DOMAINS:-}" ]; then
  IFS=',' read -ra EXTRAS <<< "$EXTRA_DOMAINS"
  for d in "${EXTRAS[@]}"; do
    DOMAIN_ARGS+=(-d "$d")
  done
fi

ca_server_flag() {
  case "$1" in
    letsencrypt) echo "letsencrypt" ;;
    zerossl)     echo "zerossl" ;;
    buypass)     echo "buypass" ;;
    *)           echo "" ;;
  esac
}

IFS=',' read -ra CAS <<< "$CA_ORDER"
SUCCESS=0

for ca in "${CAS[@]}"; do
  ca=$(echo "$ca" | xargs) # trim whitespace
  server=$(ca_server_flag "$ca")
  if [ -z "$server" ]; then
    warn "نام CA ناشناخته، رد شد: $ca"
    continue
  fi

  log "در حال تلاش برای صدور گواهی از طریق CA: $ca (DNS-01, provider=$DNS_PROVIDER) ..."

  if "$ACME_SH" --issue \
      --dns "$DNS_PROVIDER" \
      "${DOMAIN_ARGS[@]}" \
      --keylength "$KEY_TYPE" \
      --server "$server" \
      --accountemail "$EMAIL"; then
    log "✅ گواهی با موفقیت از طریق $ca صادر شد."
    SUCCESS=1
    break
  else
    warn "صدور گواهی از طریق $ca ناموفق بود؛ در صورت وجود، CA بعدی امتحان می‌شود."
  fi
done

if [ "$SUCCESS" -ne 1 ]; then
  err "صدور گواهی از هیچ‌یک از CAهای تعریف‌شده موفق نشد."
  err "اجرا کنید: ./scripts/check-connectivity.sh $DOMAIN  برای عیب‌یابی."
  err "همچنین docs/TROUBLESHOOTING.md را ببینید."
  exit 1
fi

log "محل فایل‌های گواهی:"
log "  $HOME/.acme.sh/${DOMAIN}_ecc/fullchain.cer"
log "  $HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key"
log "برای نصب خودکار روی nginx/apache از دستور --install-cert در acme.sh استفاده کنید (رجوع کنید به README)."
