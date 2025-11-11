# Production Deployment Checklist

Bu kontrol listesi, NazlıYavuz Platformu (Laravel backend + Next.js admin panel + Flutter istemciler) için production ortamına çıkmadan önce tamamlanması gereken adımları özetler.

---

## 1. Ortam Değişkenleri

`.env` dosyasında aşağıdaki anahtarların tanımlandığından emin olun:

### Uygulama ve Kuyruk

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://app.nazliyavuz.com

QUEUE_CONNECTION=database
QUEUE_FAILED_DRIVER=database-uuids
DB_QUEUE_CONNECTION=mysql           # veya kullandığınız bağlantı
DB_QUEUE_TABLE=jobs
DB_QUEUE=default
DB_QUEUE_RETRY_AFTER=120
```

### E-posta / Push / SMS / Slack

```
MAIL_MAILER=smtp
MAIL_HOST=...
MAIL_PORT=587
MAIL_USERNAME=...
MAIL_PASSWORD=...
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=no-reply@nazliyavuz.com
MAIL_FROM_NAME="NazlıYavuz Platformu"

FCM_SERVER_KEY=...
FCM_SENDER_ID=...

SMS_PROVIDER=twilio               # mock | twilio
SMS_TWILIO_ACCOUNT_SID=...
SMS_TWILIO_AUTH_TOKEN=...
SMS_TWILIO_FROM=...

SLACK_BOT_USER_OAUTH_TOKEN=...
SLACK_BOT_USER_DEFAULT_CHANNEL=#nazliyavuz-alerts
```

### Yedekleme & Finans

```
BACKUP_STORAGE_DISK=s3            # local, s3 vb.
BACKUP_RETENTION_DAYS=30
BACKUP_DATABASE_ENABLED=true
BACKUP_DATABASE_CRON="0 3 * * *"

PLATFORM_CURRENCY=TRY
TEACHER_PAYOUT_SHARE=0.7
```

> Admin panelinden `.env` güncellemeleri yapabilmek için `EnvironmentService::$allowedKeys` listesinde bulunan anahtarların doldurulması gerekir.

---

## 2. Veri Tabanı ve Seeder’lar

```bash
php artisan migrate --force
php artisan db:seed --force --class=RealisticDataSeeder   # gerekiyorsa
php artisan cache:clear
php artisan config:cache
php artisan route:cache
```

> Önemli: `storage`, `bootstrap/cache` klasörlerinin web kullanıcısı tarafından yazılabilir olduğundan emin olun.

---

## 3. Kuyruk ve Scheduler Servisleri

### Supervisor (önerilen)

`/etc/supervisor/conf.d/laravel-worker.conf`:

```ini
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/platform/backend/artisan queue:work --queue=notifications,default --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/log/supervisor/worker.log

[program:laravel-scheduler]
command=php /var/www/platform/backend/artisan schedule:work
autostart=true
autorestart=true
user=www-data
stdout_logfile=/var/log/supervisor/scheduler.log
stderr_logfile=/var/log/supervisor/scheduler.err.log
```

Supervisor’u yeniden yükleyin:

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start laravel-worker:*
sudo supervisorctl start laravel-scheduler
```

### Cron Alternatifi

Supervisor kullanmıyorsanız şu cron girdilerini ekleyin:

```
* * * * * php /var/www/platform/backend/artisan schedule:run >> /dev/null 2>&1
* * * * * php /var/www/platform/backend/artisan queue:work --queue=notifications,default --sleep=3 --tries=3 --max-time=3600 >> /var/log/queue-worker.log 2>&1
```

> Production’da `QUEUE_CONNECTION=sync` kullanılması bildirim kuyruğunu durdurur; `.env` değerini deploydan önce kontrol edin.

---

## 4. Bildirim Kanallarını Test Et

1. **FCM Token kayıt testi**
   ```bash
   curl -X POST https://api.nazliyavuz.com/api/v1/notifications/register-token \
     -H "Authorization: Bearer <JWT>" \
     -H "Content-Type: application/json" \
     -d '{"token":"demo-token","platform":"android"}'
   ```
2. **Bildirim kuyruğunu manuel çalıştırma**
   ```bash
   php artisan notifications:dispatch-scheduled --limit=5 --verbose
   ```
3. **SMTP doğrulaması**
   ```bash
   php artisan tinker
   >>> Mail::raw('Production smoke test', fn($m) => $m->to('ops@nazliyavuz.com'));
   ```
4. **SMS testi (Twilio)**
   ```bash
   php artisan notifications:dispatch-scheduled --limit=1 --channel=sms
   ```
5. **Slack webhook uyarıları**
   Admin panelindeki “Entegrasyon Durumu” kartında hata görünüyorsa `SLACK_BOT_USER_OAUTH_TOKEN` değerlerini kontrol edin.

Loglar: `storage/logs/laravel.log` içinde `notifications:` kayıtlarını takip edin.

---

## 5. Yedekleme Otomasyonu

- `App\Console\Kernel` günlük cron ifadelerini `.env` değerlerine göre planlar (`backup:database`, `backup:filesystem`, `backup:full`).
- Aşağıdaki komutu manuel çalıştırarak cron’un doğru çalıştığını doğrulayın:

```bash
php artisan backup:database
php artisan backup:list
```

> Admin paneli > **Yedek Yönetimi** sayfasındaki “Yedekleme Otomasyonu” kartı son çalışma zamanlarını raporlar.

---

## 6. Admin Paneli (Next.js)

```bash
cd admin-panel
npm install --legacy-peer-deps
cp .env.example .env.local           # yoksa README’deki değerler
npm run build
npm run start
```

- `NEXT_PUBLIC_API_BASE_URL` production API adresini göstermelidir.
- Playwright e2e testi (opsiyonel): `npm run test:e2e`

---

## 7. Flutter Uygulaması

`SETUP_GUIDE.md` içindeki adımları izleyin:

```bash
cd frontend/nazliyavuz_app
flutter clean
flutter pub get
flutter build apk --release
flutter build ios --release
```

Gerekli Firebase ve Sign-In yapılandırmaları `SETUP_GUIDE.md` bölüm 3-5’te anlatılmıştır.

---

## 8. İzleme ve Bakım

- Laravel log rotasyonu: `/var/log/supervisor/*`, `storage/logs/laravel.log`
- Kuyruk hataları: `php artisan queue:failed`, `php artisan queue:retry all`
- Sistem raporu: `php artisan app:generate-system-report` (Admin panelinden tetiklenebilir)
- Deploy sonrası: `php artisan queue:restart`, `php artisan optimize:clear`

---

✅ Bu adımlar tamamlandığında platform bildirim kuyruğu, scheduler, yedekleme otomasyonu ve kimlik bilgileriyle production ortamında çalışmaya hazır olacaktır. Her deploy sonrası bu listeyi yeniden gözden geçirin.***

