#!/usr/bin/env bash
#
# install.sh — نصب‌کنندهٔ تعاملیِ IR-TLS Toolkit.
#
# این اسکریپت به‌تنهایی همهٔ کارها را انجام می‌دهد:
#   ۱) نصب acme.sh
#   ۲) پرسیدن دامنه/ایمیل/تنظیمات DNS از شما
#   ۳) ساخت خودکار فایل پیکربندی
#   ۴) صدور گواهی (با fallback بین چند CA)
#   ۵) تنظیم تمدید خودکار
#   ۶) نصب خودکار گواهی روی nginx/Apache (در صورت شناسایی)
#
# فقط کافی است اجرایش کنید: ./install.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;32m[ir-tls]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ir-tls][هشدار]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ir-tls][خطا]\033[0m %s\n' "$*" >&2; }

ask() {
  # ask "متن سوال" "مقدار پیش‌فرض(اختیاری)"
  local prompt="$1" default="${2:-}" reply
  if [ -n "$default" ]; then
    read -r -p "$prompt [$default]: " reply
    printf '%s' "${reply:-$default}"
  else
    read -r -p "$prompt: " reply
    printf '%s' "$reply"
  fi
}

if [ ! -t 0 ]; then
  err "این اسکریپت تعاملی است و باید مستقیماً در ترمینال اجرا شود (نه از طریق pipe)."
  exit 1
fi

echo
echo "=================================================="
echo "   IR-TLS Toolkit — نصب و راه‌اندازی خودکار TLS"
echo "=================================================="
echo "این اسکریپت چند سوال ساده می‌پرسد و بقیهٔ کار را خودش انجام می‌دهد."
echo

# ───────────────────────────────────────────────
# ۱) نصب acme.sh
# ───────────────────────────────────────────────
if ! command -v curl >/dev/null 2>&1; then
  err "دستور curl نصب نیست. ابتدا نصبش کنید، مثلاً: apt install -y curl"
  exit 1
fi

ACME_SH="$HOME/.acme.sh/acme.sh"
if [ -x "$ACME_SH" ]; then
  log "acme.sh از قبل نصب است؛ از نصب مجدد صرف‌نظر می‌شود."
else
  log "در حال نصب acme.sh ..."
  if ! curl -s https://get.acme.sh | sh -s; then
    err "نصب acme.sh ناموفق بود. اتصال اینترنت را بررسی کنید."
    exit 1
  fi
fi

if [ ! -x "$ACME_SH" ]; then
  err "نصب acme.sh کامل نشد؛ مسیر $ACME_SH یافت نشد."
  exit 1
fi

chmod +x "$SCRIPT_DIR"/scripts/*.sh 2>/dev/null || true

# ───────────────────────────────────────────────
# ۲) پرسیدن اطلاعات از کاربر
# ───────────────────────────────────────────────
echo
DOMAIN=$(ask "دامنهٔ شما (مثلاً example.ir)")
while [ -z "$DOMAIN" ]; do
  warn "دامنه نمی‌تواند خالی باشد."
  DOMAIN=$(ask "دامنهٔ شما (مثلاً example.ir)")
done

EXTRA_DOMAINS=$(ask "زیردامنه‌های اضافه، با کاما جدا کنید (یا Enter برای رد شدن)" "")

EMAIL=$(ask "ایمیل شما (برای اطلاع از انقضای گواهی)")
while [ -z "$EMAIL" ]; do
  warn "ایمیل نمی‌تواند خالی باشد."
  EMAIL=$(ask "ایمیل شما")
done

echo
echo "DNS دامنهٔ شما را چه کسی مدیریت می‌کند؟"
echo "  1) Cloudflare   (پیشنهادی — رایگان و کاملاً خودکار)"
echo "  2) ارائه‌دهندهٔ دیگری که از قبل می‌شناسم (AWS, Google Cloud, DigitalOcean, ...)"
echo "  3) نمی‌دانم / API ندارم — حالت دستی (یک رکورد TXT را خودتان اضافه می‌کنید)"
DNS_CHOICE=$(ask "عدد گزینه" "1")

DNS_PROVIDER=""
CF_Token=""
CF_Account_ID=""
EXTRA_ENV_LINES=""

case "$DNS_CHOICE" in
  2)
    echo
    echo "فهرست کامل کدها: docs/DNS-PROVIDERS.md (مثال: dns_aws برای Route53، dns_gcloud برای Google Cloud DNS)"
    DNS_PROVIDER=$(ask "کد DNS provider در acme.sh")
    while [ -z "$DNS_PROVIDER" ]; do
      warn "این مقدار نمی‌تواند خالی باشد."
      DNS_PROVIDER=$(ask "کد DNS provider در acme.sh")
    done
    echo "متغیرهای API لازم این ارائه‌دهنده را به‌صورت KEY=VALUE وارد کنید (هر خط یکی)."
    echo "وقتی تمام شد، یک خط خالی بزنید و Enter کنید:"
    while IFS= read -r line; do
      [ -z "$line" ] && break
      EXTRA_ENV_LINES="${EXTRA_ENV_LINES}${line}
"
    done
    ;;
  3)
    DNS_PROVIDER="manual"
    warn "در حالت دستی، تمدید خودکار ممکن نیست؛ برای صدور اولیه یا تست مناسب است."
    warn "توصیه می‌شود در آینده NS دامنه را به Cloudflare منتقل کنید (رایگان) تا تمدید کاملاً خودکار شود."
    ;;
  *)
    DNS_PROVIDER="dns_cf"
    echo
    echo "راهنما: پنل Cloudflare → My Profile → API Tokens → Create Token"
    echo "  قالب «Edit zone DNS» را انتخاب و دسترسی را به همین دامنه محدود کنید."
    CF_Token=$(ask "CF_Token (توکن API کلودفلر)")
    while [ -z "$CF_Token" ]; do
      warn "این مقدار نمی‌تواند خالی باشد."
      CF_Token=$(ask "CF_Token (توکن API کلودفلر)")
    done
    CF_Account_ID=$(ask "CF_Account_ID (اختیاری؛ Enter برای رد شدن)" "")
    ;;
esac

# ───────────────────────────────────────────────
# ۳) ساخت فایل پیکربندی
# ───────────────────────────────────────────────
SAFE_NAME=$(printf '%s' "$DOMAIN" | tr -c 'A-Za-z0-9.' '-')
mkdir -p "$SCRIPT_DIR/config"
ENV_FILE="$SCRIPT_DIR/config/${SAFE_NAME}.env"

{
  echo "DOMAIN=\"$DOMAIN\""
  echo "EXTRA_DOMAINS=\"$EXTRA_DOMAINS\""
  echo "EMAIL=\"$EMAIL\""
  echo "DNS_PROVIDER=\"$DNS_PROVIDER\""
  echo "CA_ORDER=\"letsencrypt,zerossl,buypass\""
  echo "KEY_TYPE=\"ec-256\""
  [ -n "$CF_Token" ]      && echo "CF_Token=\"$CF_Token\""
  [ -n "$CF_Account_ID" ] && echo "CF_Account_ID=\"$CF_Account_ID\""
  [ -n "$EXTRA_ENV_LINES" ] && printf '%s' "$EXTRA_ENV_LINES"
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"

echo
log "فایل پیکربندی ساخته شد: config/$(basename "$ENV_FILE")"

# ───────────────────────────────────────────────
# ۴) صدور گواهی
# ───────────────────────────────────────────────
echo
log "در حال صدور گواهی برای $DOMAIN ..."
ISSUED=0
if "$SCRIPT_DIR/scripts/issue-cert.sh" "$ENV_FILE"; then
  ISSUED=1
  log "✅ گواهی با موفقیت صادر شد."
else
  err "صدور گواهی ناموفق بود."
  err "عیب‌یابی: ./scripts/check-connectivity.sh $DOMAIN"
  err "راهنمای کامل: docs/TROUBLESHOOTING.md"
fi

# ───────────────────────────────────────────────
# ۵) تمدید خودکار
# ───────────────────────────────────────────────
if [ "$ISSUED" -eq 1 ] && [ "$DNS_PROVIDER" != "manual" ]; then
  echo
  SETUP_RENEW=$(ask "تمدید خودکار تنظیم شود؟ (y/n)" "y")
  if [ "$SETUP_RENEW" = "y" ] || [ "$SETUP_RENEW" = "Y" ]; then
    if command -v systemctl >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
      if "$SCRIPT_DIR/scripts/setup-systemd-timer.sh" "$ENV_FILE"; then
        log "تمدید خودکار با systemd timer فعال شد."
      else
        warn "راه‌اندازی systemd timer ناموفق بود؛ در ادامه تلاش برای cron ..."
        command -v crontab >/dev/null 2>&1 && {
          CRON_LINE="0 3 * * * $SCRIPT_DIR/scripts/renew-cert.sh $ENV_FILE >> $SCRIPT_DIR/renew.log 2>&1"
          ( crontab -l 2>/dev/null | grep -vF "$SCRIPT_DIR/scripts/renew-cert.sh $ENV_FILE" ; echo "$CRON_LINE" ) | crontab -
          log "تمدید خودکار با cron فعال شد (هر روز ساعت ۳ بامداد)."
        }
      fi
    elif command -v crontab >/dev/null 2>&1; then
      CRON_LINE="0 3 * * * $SCRIPT_DIR/scripts/renew-cert.sh $ENV_FILE >> $SCRIPT_DIR/renew.log 2>&1"
      ( crontab -l 2>/dev/null | grep -vF "$SCRIPT_DIR/scripts/renew-cert.sh $ENV_FILE" ; echo "$CRON_LINE" ) | crontab -
      log "تمدید خودکار با cron فعال شد (هر روز ساعت ۳ بامداد)."
    else
      warn "نه systemd و نه cron در دسترس است؛ renew-cert.sh را باید خودتان زمان‌بندی کنید."
    fi
  fi
fi

# ───────────────────────────────────────────────
# ۶) نصب خودکار روی وب‌سرور (nginx / Apache)
# ───────────────────────────────────────────────
if [ "$ISSUED" -eq 1 ]; then
  echo
  if command -v nginx >/dev/null 2>&1; then
    SETUP_WEB=$(ask "وب‌سرور Nginx شناسایی شد. گواهی به‌صورت خودکار برایش نصب شود؟ (y/n)" "y")
    if [ "$SETUP_WEB" = "y" ] || [ "$SETUP_WEB" = "Y" ]; then
      CERT_DIR="/etc/nginx/ssl/$DOMAIN"
      (mkdir -p "$CERT_DIR" 2>/dev/null) || sudo mkdir -p "$CERT_DIR"
      if "$ACME_SH" --install-cert -d "$DOMAIN" --ecc \
          --key-file "$CERT_DIR/key.pem" \
          --fullchain-file "$CERT_DIR/fullchain.pem" \
          --reloadcmd "systemctl reload nginx"; then
        log "فایل‌های گواهی در $CERT_DIR قرار گرفتند و reload خودکار nginx فعال شد."
        echo
        echo "این دو خط را در server block مربوط به $DOMAIN در فایل nginx خود اضافه کنید:"
        echo "    ssl_certificate     $CERT_DIR/fullchain.pem;"
        echo "    ssl_certificate_key $CERT_DIR/key.pem;"
        echo "سپس: sudo nginx -t && sudo systemctl reload nginx"
      else
        warn "نصب خودکار روی nginx ناموفق بود؛ فایل‌های گواهی در \$HOME/.acme.sh/${DOMAIN}_ecc/ باقی ماندند."
      fi
    fi
  elif command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
    if command -v apache2 >/dev/null 2>&1; then RELOAD_CMD="systemctl reload apache2"; else RELOAD_CMD="systemctl reload httpd"; fi
    SETUP_WEB=$(ask "وب‌سرور Apache شناسایی شد. گواهی به‌صورت خودکار برایش نصب شود؟ (y/n)" "y")
    if [ "$SETUP_WEB" = "y" ] || [ "$SETUP_WEB" = "Y" ]; then
      CERT_DIR="/etc/ssl/ir-tls/$DOMAIN"
      (mkdir -p "$CERT_DIR" 2>/dev/null) || sudo mkdir -p "$CERT_DIR"
      if "$ACME_SH" --install-cert -d "$DOMAIN" --ecc \
          --key-file "$CERT_DIR/key.pem" \
          --fullchain-file "$CERT_DIR/fullchain.pem" \
          --reloadcmd "$RELOAD_CMD"; then
        log "فایل‌های گواهی در $CERT_DIR قرار گرفتند و reload خودکار Apache فعال شد."
        echo
        echo "این دو خط را در VirtualHost پورت 443 مربوط به $DOMAIN اضافه کنید:"
        echo "    SSLCertificateFile    $CERT_DIR/fullchain.pem"
        echo "    SSLCertificateKeyFile $CERT_DIR/key.pem"
        echo "سپس: sudo apachectl configtest && sudo $RELOAD_CMD"
      else
        warn "نصب خودکار روی Apache ناموفق بود؛ فایل‌های گواهی در \$HOME/.acme.sh/${DOMAIN}_ecc/ باقی ماندند."
      fi
    fi
  else
    log "وب‌سروری (nginx/Apache) شناسایی نشد. فایل‌های گواهی اینجا هستند:"
    log "  $HOME/.acme.sh/${DOMAIN}_ecc/fullchain.cer"
    log "  $HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key"
  fi
fi

echo
echo "=================================================="
if [ "$ISSUED" -eq 1 ]; then
  log "تمام شد 🎉"
else
  warn "نصب تمام شد ولی صدور گواهی نیاز به بررسی دارد (بالا را ببینید)."
fi
log "پیکربندی شما ذخیره شد در: config/$(basename "$ENV_FILE")"
log "صدور/تمدید دستیِ بعدی: ./scripts/issue-cert.sh config/$(basename "$ENV_FILE")"
echo "=================================================="
