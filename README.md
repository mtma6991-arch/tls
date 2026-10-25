# IR-TLS Toolkit

ابزاری سبک و متن‌باز برای **صدور و تمدید خودکار گواهی TLS/SSL** برای دامنه‌های ایرانی (از جمله `.ir`)، با تمرکز بر حل رایج‌ترین دلیل شکست صدور گواهی برای این دامنه‌ها: **ناپایداری اعتبارسنجی HTTP-01** به‌خاطر مسیر شبکهٔ بین‌المللی.

---

## ⚠️ این پروژه دقیقاً چه چیزی را حل می‌کند

وقتی صدور گواهی TLS برای یک دامنهٔ ایرانی شکست می‌خورد، معمولاً یکی از دو دلیل کاملاً متفاوت در کار است:

### ۱) محدودیت فنی/شبکه‌ای (این پروژه آن را حل می‌کند ✅)

اکثر مراجع صدور گواهی (CA) از جمله Let's Encrypt، به‌صورت پیش‌فرض برای دامنه‌های **غیردولتی** ایرانی گواهی صادر می‌کنند؛ تحریم‌ها شامل کل TLD دامنهٔ `.ir` نمی‌شود. مشکلی که اغلب کاربران ایرانی با آن مواجه می‌شوند این است:

- از سال ۲۰۲۰ به بعد، CAهای بزرگ ملزم شده‌اند اعتبارسنجی دامنه (Domain Validation) را از **چند نقطهٔ جغرافیایی مختلف** در دنیا انجام دهند (Multi-Perspective Validation).
- در روش رایج `HTTP-01`، سرورهای اعتبارسنجی CA باید مستقیماً از همهٔ آن نقاط به IP سرور شما وصل شوند.
- به‌دلیل کیفیت/مسیر لینک‌های بین‌المللی ایران، فیلترینگ میانی، یا افت کیفیت peering، این اتصال اغلب از یک یا چند نقطه شکست می‌خورد و **کل فرآیند صدور fail می‌شود**، حتی اگر دامنه کاملاً مجاز باشد.

**راه‌حل:** این ابزار به‌صورت پیش‌فرض از روش `DNS-01` استفاده می‌کند. در این روش CA فقط یک رکورد TXT را از طریق سیستم DNS جهانی (که بسیار پایدارتر و توزیع‌شده‌تر از یک اتصال مستقیم TCP است) بررسی می‌کند — نیازی به اتصال مستقیم به سرور شما نیست. این یک تغییر ساده است که در عمل اکثر مشکلات صدور/تمدید گواهی برای دامنه‌های ایرانی را برطرف می‌کند.

بیشتر در [`docs/FAQ.md`](docs/FAQ.md).

---

## ویژگی‌ها

- ✅ اعتبارسنجی پیش‌فرض با `DNS-01` (مقاوم در برابر مشکلات شبکهٔ بین‌المللی)
- ✅ پشتیبانی از چند CA با قابلیت fallback خودکار (Let's Encrypt → ZeroSSL → Buypass)
- ✅ اسکریپت تشخیص شبکه (`check-connectivity.sh`) که پیش از صدور، وضعیت اتصال به هر CA را می‌سنجد
- ✅ تمدید خودکار با `systemd timer` یا `cron`
- ✅ پشتیبانی از ده‌ها ارائه‌دهندهٔ DNS از طریق `acme.sh` (Cloudflare، Route53، Google Cloud DNS و…) + حالت دستی برای بقیه
- ✅ بدون وابستگی سنگین — مبتنی بر [acme.sh](https://github.com/acmesh-official/acme.sh) (bash خالص)

---

## نصب سریع

```bash
git clone https://github.com/mtma6991-arch/tls.git
cd tls
./install.sh
```

`install.sh` موارد زیر را انجام می‌دهد:
1. بررسی وابستگی‌ها (`curl`, `cron` یا `systemd`)
2. نصب `acme.sh` در `$HOME/.acme.sh`
3. ثبت حساب نزد CA پیش‌فرض (Let's Encrypt)

---

## استفاده

### ۱) تنظیم پیکربندی

```bash
cp config/example.env config/my-domain.env
nano config/my-domain.env
```

مقادیر لازم:

```ini
DOMAIN="example.ir"
EMAIL="you@example.com"
DNS_PROVIDER="dns_cf"        # نام پلاگین acme.sh برای DNS شما؛ لیست کامل: docs/DNS-PROVIDERS.md
CA_SERVER="letsencrypt"      # letsencrypt | zerossl | buypass

# کلیدهای API مخصوص ارائه‌دهندهٔ DNS شما (نمونه برای Cloudflare):
CF_Token="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
CF_Account_ID="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### ۲) بررسی وضعیت شبکه (اختیاری ولی توصیه‌شده)

```bash
./scripts/check-connectivity.sh example.ir
```

این اسکریپت گزارش می‌دهد که آیا دسترسی به سرورهای هر CA برقرار است و کدام روش اعتبارسنجی احتمال موفقیت بیشتری دارد.

### ۳) صدور گواهی

```bash
./scripts/issue-cert.sh config/my-domain.env
```

### ۴) تمدید خودکار

```bash
sudo ./scripts/setup-systemd-timer.sh config/my-domain.env
```

یا به‌صورت دستی با cron:

```cron
0 3 * * * /path/to/tls/scripts/renew-cert.sh /path/to/tls/config/my-domain.env >> /var/log/ir-tls-renew.log 2>&1
```

گواهی‌های صادرشده (fullchain + private key) در مسیر زیر قرار می‌گیرند:

```
$HOME/.acme.sh/<domain>_ecc/
```

---

## ساختار پروژه

```
tls/
├── install.sh
├── scripts/
│   ├── issue-cert.sh
│   ├── renew-cert.sh
│   ├── check-connectivity.sh
│   └── setup-systemd-timer.sh
├── config/
│   └── example.env
├── systemd/
│   ├── ir-tls-renew.service
│   └── ir-tls-renew.timer
└── docs/
    ├── FAQ.md
    ├── DNS-PROVIDERS.md
    └── TROUBLESHOOTING.md
```

---

## منابع و رفرنس‌ها

- Let's Encrypt — Certificates for US sanctioned countries (Community Forum)
- Let's Encrypt — Issuance criteria for `.ir` domains (Community Forum)
- Let's Encrypt Subscriber Agreement (بند مربوط به تحریم‌ها)
- CA/Browser Forum — Multi-Perspective Issuance Corroboration (الزام اعتبارسنجی چندنقطه‌ای)

---

## مجوز

MIT — فایل [`LICENSE`](LICENSE) را ببینید.
