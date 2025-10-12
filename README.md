# Nazliyavuz Platform

Eğitim platformu - Öğretmen ve öğrenci buluşma noktası.

## 🚀 Proje Yapısı

```
nazliyavuz-platform/
├── backend/                 # Laravel API Backend
│   ├── app/
│   ├── database/
│   ├── routes/
│   └── ...
├── frontend/                # Flutter Mobile App
│   └── nazliyavuz_app/
│       ├── lib/
│       ├── android/
│       ├── ios/
│       └── ...
└── README.md
```

## 🛠️ Teknolojiler

### Backend
- **Laravel 12.30.1** - PHP Framework
- **MySQL** - Veritabanı
- **Redis** - Cache ve Session
- **Pusher** - Real-time Chat
- **Firebase** - Push Notifications

### Frontend
- **Flutter** - Cross-platform Mobile App
- **Dart** - Programming Language
- **BLoC** - State Management
- **Dio** - HTTP Client
- **Firebase** - Push Notifications

## 📱 Özellikler

### Öğretmen Özellikleri
- ✅ Profil oluşturma ve düzenleme
- ✅ Ders programı yönetimi
- ✅ Rezervasyon yönetimi
- ✅ Öğrenci ile chat
- ✅ Video görüşme
- ✅ Dosya paylaşımı
- ✅ Ödev yönetimi
- ✅ Değerlendirme sistemi

### Öğrenci Özellikleri
- ✅ Öğretmen arama ve filtreleme
- ✅ Rezervasyon oluşturma
- ✅ Öğretmen ile chat
- ✅ Video görüşme
- ✅ Dosya paylaşımı
- ✅ Ödev takibi
- ✅ Değerlendirme yapma

### Genel Özellikler
- ✅ Kullanıcı kayıt ve giriş
- ✅ Email doğrulama
- ✅ Push bildirimler
- ✅ Offline destek
- ✅ Çoklu dil desteği
- ✅ Dark/Light tema
- ✅ Erişilebilirlik desteği

## 🚀 Kurulum

### Backend Kurulumu

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve
```

### Frontend Kurulumu

```bash
cd frontend/nazliyavuz_app
flutter pub get
flutter run
```

## 🔧 Geliştirme

### Backend API Endpoints

- `POST /api/v1/auth/register` - Kullanıcı kaydı
- `POST /api/v1/auth/login` - Kullanıcı girişi
- `GET /api/v1/teachers` - Öğretmen listesi
- `POST /api/v1/reservations` - Rezervasyon oluşturma
- `GET /api/v1/chat/messages` - Mesaj listesi
- `POST /api/v1/chat/send` - Mesaj gönderme

### Frontend Screens

- **Auth**: Login, Register, Email Verification
- **Home**: Dashboard, Quick Actions
- **Teachers**: List, Search, Filter, Detail
- **Reservations**: List, Create, Manage
- **Chat**: Real-time messaging
- **Profile**: User settings, Preferences
- **Settings**: Theme, Language, Notifications

## 📊 Veritabanı

### Ana Tablolar
- `users` - Kullanıcı bilgileri
- `teachers` - Öğretmen profilleri
- `reservations` - Rezervasyonlar
- `conversations` - Chat konuşmaları
- `messages` - Mesajlar
- `categories` - Ders kategorileri
- `ratings` - Değerlendirmeler

## 🔐 Güvenlik

- JWT Token Authentication
- CORS Protection
- Input Validation
- SQL Injection Protection
- XSS Protection
- Rate Limiting

## 📱 Platform Desteği

- ✅ Android
- ✅ iOS
- ✅ Web (Gelecek)

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit yapın (`git commit -m 'Add amazing feature'`)
4. Push yapın (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun


## 👥 Ekip

- **Ahmet Can** - Full Stack Developer
- **Nazlı Yavuz** - Project Manager


**Nazliyavuz Platform** - Eğitimde yeni nesil çözümler 🎓
