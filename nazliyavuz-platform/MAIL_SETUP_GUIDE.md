# 📧 NAZLIYAVUZ PLATFORM - E-POSTA SİSTEMİ KURULUM REHBERİ

## 🚨 **E-POSTA DOĞRULAMA SORUNU ÇÖZÜMÜ**

### **Sorun:** Kayıt olduktan sonra e-posta doğrulama maili gelmiyor

### **Çözüm:** Profesyonel e-posta sistemi kurulumu

---

## 🔧 **ADIM 1: .env DOSYASI OLUŞTURMA**

```bash
# Backend dizinine gidin
cd nazliyavuz-platform/backend

# .env dosyasını oluşturun
cp .env.example .env

# Uygulama anahtarını oluşturun
php artisan key:generate
```

---

## 📧 **ADIM 2: MAİL SERVİSİ SEÇİMİ**

### **Seçenek 1: Gmail SMTP (Önerilen)**

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your_gmail@gmail.com
MAIL_PASSWORD=your_gmail_app_password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@nazliyavuz.com
MAIL_FROM_NAME="Nazliyavuz Platform"
```

**Gmail App Password Oluşturma:**
1. Gmail hesabınızda 2FA aktif olmalı
2. Google Account → Security → App passwords
3. "Mail" uygulaması için şifre oluşturun
4. Bu şifreyi `MAIL_PASSWORD` olarak kullanın

### **Seçenek 2: Mailgun**

```env
MAIL_MAILER=mailgun
MAILGUN_DOMAIN=mg.nazliyavuz.com
MAILGUN_SECRET=your_mailgun_secret
MAIL_FROM_ADDRESS=noreply@nazliyavuz.com
MAIL_FROM_NAME="Nazliyavuz Platform"
```

### **Seçenek 3: SendGrid**

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.sendgrid.net
MAIL_PORT=587
MAIL_USERNAME=apikey
MAIL_PASSWORD=your_sendgrid_api_key
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@nazliyavuz.com
MAIL_FROM_NAME="Nazliyavuz Platform"
```

---

## 🧪 **ADIM 3: MAİL SİSTEMİNİ TEST ETME**

### **Otomatik Test:**
```bash
# Mail kurulum script'ini çalıştırın
php setup-mail.php

# Mail test komutu
php artisan mail:test your_email@domain.com
```

### **Manuel Test:**
```bash
# Mail durumunu kontrol edin
curl http://localhost:8000/api/v1/auth/mail-status
```

---

## 🔍 **ADIM 4: SORUN GİDERME**

### **Mail Gönderilmiyor:**
1. `.env` dosyasında `MAIL_*` ayarlarını kontrol edin
2. Gmail App Password kullandığınızdan emin olun
3. Firewall ayarlarını kontrol edin
4. `php artisan config:cache` komutunu çalıştırın

### **Log Kontrolü:**
```bash
# Laravel loglarını kontrol edin
tail -f storage/logs/laravel.log | grep -i mail

# Mail gönderim hatalarını kontrol edin
tail -f storage/logs/laravel.log | grep -i "EMAIL_VERIFICATION_TOKEN_FALLBACK"
```

### **Fallback Token:**
Eğer mail gönderilemezse, token log'da görünecek:
```
EMAIL_VERIFICATION_TOKEN_FALLBACK
```

Bu token'ı manuel olarak kullanabilirsiniz:
```
http://localhost:8000/api/v1/auth/verify-email?token=TOKEN_BURAYA
```

---

## 🚀 **ADIM 5: PRODUCTION AYARLARI**

### **Production .env:**
```env
APP_ENV=production
APP_DEBUG=false
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=production_email@gmail.com
MAIL_PASSWORD=production_app_password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@nazliyavuz.com
MAIL_FROM_NAME="Nazliyavuz Platform"
```

### **SSL Sertifikası:**
Production'da SSL sertifikası gerekli:
```env
APP_URL=https://nazliyavuz.com
FRONTEND_URL=https://app.nazliyavuz.com
```

---

## 📱 **ADIM 6: FRONTEND ENTEGRASYONU**

### **Mail Durumu Kontrolü:**
```dart
// API Service'de mail durumunu kontrol edin
final mailStatus = await apiService.getMailStatus();
print('Mail configured: ${mailStatus['status']['configured']}');
```

### **Kayıt Sonrası Bildirim:**
```dart
// Kayıt sonrası mail durumunu göster
if (response['email_verification']['mail_sent']) {
  showSuccessMessage('E-posta doğrulama maili gönderildi');
} else {
  showWarningMessage('Mail gönderilemedi - lütfen mail ayarlarını kontrol edin');
}
```

---

## 🔧 **ADIM 7: DOCKER KURULUMU**

### **Docker Compose ile:**
```bash
# Tüm servisleri başlatın
docker-compose up -d

# Mail servisini test edin
docker-compose exec app php artisan mail:test your_email@domain.com
```

### **Environment Variables:**
```yaml
# docker-compose.yml
environment:
  - MAIL_MAILER=smtp
  - MAIL_HOST=smtp.gmail.com
  - MAIL_PORT=587
  - MAIL_USERNAME=${MAIL_USERNAME}
  - MAIL_PASSWORD=${MAIL_PASSWORD}
  - MAIL_ENCRYPTION=tls
```

---

## ✅ **KONTROL LİSTESİ**

- [ ] .env dosyası oluşturuldu
- [ ] Mail servisi seçildi (Gmail/Mailgun/SendGrid)
- [ ] Mail ayarları yapılandırıldı
- [ ] `php artisan key:generate` çalıştırıldı
- [ ] Mail test edildi
- [ ] Log'lar kontrol edildi
- [ ] Frontend entegrasyonu yapıldı
- [ ] Production ayarları yapıldı

---

## 🆘 **ACİL DURUM ÇÖZÜMÜ**

### **Mail Gönderilmiyor:**
1. Log'da fallback token'ı bulun
2. Token'ı manuel olarak kullanın
3. Mail ayarlarını düzeltin
4. Sistemi yeniden başlatın

### **Hızlı Test:**
```bash
# Mail durumunu kontrol edin
curl -X GET "http://localhost:8000/api/v1/auth/mail-status"

# Test mail gönderin
php artisan mail:test your_email@domain.com
```

---

## 📞 **DESTEK**

E-posta sistemi ile ilgili sorunlar için:
1. Log dosyalarını kontrol edin
2. Mail servis sağlayıcısının ayarlarını kontrol edin
3. Firewall ve güvenlik ayarlarını kontrol edin
4. API endpoint'lerini test edin

---

**🎯 Bu rehberi takip ederek e-posta doğrulama sistemini aktif hale getirebilirsiniz!**
