#!/usr/bin/env bash
#
# check-connectivity.sh — Diagnoses whether this server can reliably reach
# major CAs' ACME endpoints, and whether DNS-01 is advisable over HTTP-01.
#
# Usage: ./check-connectivity.sh <domain>
#
set -uo pipefail

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "استفاده: $0 <domain>"
  exit 1
fi

log()  { printf '\033[1;36m[check]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✔ %s\033[0m\n' "$*"; }
bad()  { printf '\033[1;31m  ✘ %s\033[0m\n' "$*"; }

declare -A ENDPOINTS=(
  ["Let's Encrypt (ACME directory)"]="https://acme-v02.api.letsencrypt.org/directory"
  ["ZeroSSL (ACME directory)"]="https://acme.zerossl.com/v2/DV90/directory"
  ["Buypass (ACME directory)"]="https://api.buypass.com/acme/directory"
)

log "بررسی ۱: تفکیک DNS برای $DOMAIN"
if host_ip=$(getent ahosts "$DOMAIN" 2>/dev/null | awk '{print $1}' | head -n1); then
  if [ -n "$host_ip" ]; then
    ok "دامنه به IP زیر resolve می‌شود: $host_ip"
  else
    bad "دامنه resolve نشد — ابتدا رکورد A/AAAA را بررسی کنید."
  fi
else
  bad "امکان resolve دامنه وجود نداشت (دستور getent/host در دسترس نیست یا DNS مشکل دارد)."
fi

echo
log "بررسی ۲: دسترسی خروجی این سرور به ACME directory هر CA (HTTPS, outbound)"
REACHABLE_COUNT=0
for name in "${!ENDPOINTS[@]}"; do
  url="${ENDPOINTS[$name]}"
  if curl -sS --max-time 8 -o /dev/null -w '' "$url"; then
    ok "$name قابل دسترسی است ($url)"
    REACHABLE_COUNT=$((REACHABLE_COUNT + 1))
  else
    bad "$name قابل دسترسی نیست از این سرور ($url)"
  fi
done

echo
log "بررسی ۳: آیا پورت ۸۰ از بیرون به این سرور باز است؟ (پیش‌نیاز HTTP-01)"
echo "  این بررسی نیازمند دسترسی خارجی واقعی است و از داخل همین سرور قابل تست دقیق نیست."
echo "  توصیه: از ابزار آنلاین مثل https://canyouseeme.org یا یک سرور خارج از ایران برای تست واقعی پورت ۸۰/۴۴۳ استفاده کنید."

echo
log "نتیجه‌گیری:"
if [ "$REACHABLE_COUNT" -ge 1 ]; then
  echo "  این سرور حداقل به یکی از CAها دسترسی خروجی دارد — اما این به معنای موفقیت HTTP-01 نیست،"
  echo "  چون HTTP-01 نیازمند اتصال ورودیِ چندنقطه‌ای از سمت CA به شماست (نه برعکس)."
  echo "  توصیه: همواره از روش DNS-01 (پیش‌فرض این ابزار) استفاده کنید؛ این روش وابسته به"
  echo "  اتصال ورودی مستقیم به سرور شما نیست و بسیار پایدارتر است."
else
  echo "  حتی اتصال خروجی این سرور به CAها هم ناپایدار به نظر می‌رسد."
  echo "  اگر از طریق یک VPN/Proxy خروجی پایدار یا یک سرور DNS با API (مثل Cloudflare)"
  echo "  استفاده می‌کنید، مشکل باید برطرف شود — چون صدور DNS-01 صرفاً به API ارائه‌دهندهٔ"
  echo "  DNS شما وصل می‌شود، نه مستقیماً به اینترنت باز."
fi
