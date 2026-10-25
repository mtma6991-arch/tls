# عیب‌یابی

## خطای «Verify error: ... Timeout» یا «Fetching ... Connection refused» هنگام صدور

این دقیقاً همان مشکل رایجی است که این ابزار برای حلش ساخته شده. مطمئن شوید
`DNS_PROVIDER` در فایل env روی یک پلاگین DNS واقعی تنظیم شده (نه خالی و نه `manual`
برای تمدید خودکار) — یعنی در حال استفاده از `--dns`، نه حالت وب‌سرور هستید.
اگر همچنان خطا می‌گیرید، `./scripts/check-connectivity.sh <domain>` را اجرا کنید.

## خطای «Account registration failed» یا «rateLimited»

معمولاً به‌خاطر محدودیت نرخ CA (مثلاً صدور بیش از حد مجاز در هفته برای یک دامنه) است.
اسکریپت `issue-cert.sh` به‌صورت خودکار سراغ CA بعدی در `CA_ORDER` می‌رود؛ اگر همهٔ آن‌ها
rate-limit شدند، چند ساعت صبر کنید یا گواهی staging برای تست بگیرید
(`acme.sh --staging ...`).

## گواهی صادر شد ولی روی سایت اعمال نشد

این ابزار فقط گواهی را **صادر** می‌کند؛ نصب آن روی nginx/apache/هر وب‌سرور دیگری یک
مرحلهٔ جداگانه است. از قابلیت `--install-cert` خود acme.sh استفاده کنید، مثلاً:

```bash
~/.acme.sh/acme.sh --install-cert -d example.ir --ecc \
  --key-file /etc/nginx/ssl/example.ir.key \
  --fullchain-file /etc/nginx/ssl/example.ir.fullchain.cer \
  --reloadcmd "systemctl reload nginx"
```

## تمدید خودکار کار نمی‌کند

- با systemd: `systemctl status ir-tls-renew.timer` و `journalctl -u ir-tls-renew.service`
- با cron: مطمئن شوید مسیر `renew-cert.sh` و فایل env در crontab درست و absolute هستند،
  و خروجی خطا را به یک فایل لاگ هدایت کرده‌اید تا قابل بررسی باشد.

## دامنهٔ من دولتی/عمومی نیست ولی باز هم همهٔ CAها رد می‌کنند

این حالت نادر است و معمولاً به یکی از این دلایل برمی‌گردد:
- WHOIS یا محتوای سایت به‌اشتباه به‌عنوان نهاد دولتی تشخیص داده شده.
- دامنه یا IP آن قبلاً در فهرست‌های امنیتی/spam قرار گرفته.

در این موارد باید مستقیماً با پشتیبانی همان CA (مثلاً انجمن Let's Encrypt) تماس
بگیرید؛ این ابزار نمی‌تواند و نباید چنین تصمیمی را دور بزند.
