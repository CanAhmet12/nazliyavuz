# NazlıYavuz Platformu

Terence Eğitim için hazırlanan tam kapsamlı platform:

- **Backend (Laravel 11):** Rezervasyon, bildirim otomasyonu, finans raporları, yedekleme, A/B testleri
- **Admin Panel (Next.js 16):** Rezervasyon yönetimi, finans dashboard’ları, bildirim şablonları ve deney yönetimi
- **Mobil Uygulama (Flutter):** Öğretmen/öğrenci deneyimi, video görüşme, anlık mesajlaşma

## Hızlı Başlangıç

```bash
# backend
cd backend
composer install
cp .env.example .env   # varsayılan .env mevcut değilse kendi değerlerinizi oluşturun
php artisan key:generate
php artisan migrate --seed
php artisan serve

# admin panel
cd ../admin-panel
npm install --legacy-peer-deps
cp .env.example .env.local  # yoksa README’deki değişkenleri kullanın
npm run dev
```

## Ortam Değişkenleri (Özet)

Backend için kritik değişkenler:

```env
QUEUE_CONNECTION=database
QUEUE_FAILED_DRIVER=database-uuids

# Bildirim kanalları
MAIL_MAILER=smtp
MAIL_HOST=
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=no-reply@nazliyavuz.com
MAIL_FROM_NAME="NazlıYavuz Platformu"

FCM_SERVER_KEY=
FCM_SENDER_ID=

SMS_PROVIDER=twilio    # mock | twilio
SMS_TWILIO_ACCOUNT_SID=
SMS_TWILIO_AUTH_TOKEN=
SMS_TWILIO_FROM=

SLACK_BOT_USER_OAUTH_TOKEN=
SLACK_BOT_USER_DEFAULT_CHANNEL=#nazliyavuz-alerts
```

Tam liste ve açıklamalar için `SETUP_GUIDE.md`’deki **8. Queue & Scheduler Kurulumu** bölümüne bakabilirsiniz.

## Dokümantasyon

API dokümanları otomatik olarak üretilebilir:

```bash
cd backend
php artisan app:generate-api-docs --format=json --output=storage/api-docs
```

Komut aşağıdaki dosyaları günceller:

- `backend/storage/api-docs/api-docs.json` – OpenAPI 3.0 şeması
- `backend/docs/API_ENDPOINTS.md` – endpoint özeti
- `backend/docs/API_GUIDE.md` – entegrasyon rehberi
- `backend/docs/postman-collection.json` – Postman koleksiyonu

Genel kurulum ve üretim notları:

- `SETUP_GUIDE.md` – Flutter + backend kurulum rehberi
- `docs/PRODUCTION_CHECKLIST.md` – Production deploy kontrol listesi

## Testler

- **Backend:** `php artisan test`
- **Admin Panel E2E:** `npm run test:e2e`

Bildirim kuyruğu ve scheduler için:

```bash
php artisan notifications:dispatch-scheduled --limit=5 --verbose
php artisan queue:work --queue=notifications,default
```

## Yararlı Kaynaklar

- `SETUP_GUIDE.md` – Flutter + backend kurulum rehberi
- `backend/docs/API_GUIDE.md` – REST entegrasyon örnekleri
- `docs/API_ENDPOINTS.md` – Bildirim & yönetim endpoint listesi

