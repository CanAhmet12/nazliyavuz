# Nazliyavuz Platform 🎓

**Enterprise-level eğitim platformu** - öğretmenler ve öğrencileri buluşturan kapsamlı, profesyonel bir sistem.

## 🚀 Gelişmiş Özellikler

### 📱 Frontend (Flutter 3)
- ✅ **Gelişmiş Arama**: Filtreleme, sıralama, öneriler
- ✅ **Dosya Yükleme**: S3 entegrasyonu, presigned URL
- ✅ **Offline Desteği**: Cache sistemi, offline mod
- ✅ **Analytics Dashboard**: fl_chart ile görselleştirme
- ✅ **Push Notifications**: FCM entegrasyonu
- ✅ **PWA Desteği**: Progressive Web App

### 🔧 Backend (Laravel 11)
- ✅ **API Documentation**: Swagger/OpenAPI
- ✅ **Cache Sistemi**: Redis entegrasyonu
- ✅ **Queue System**: Background job processing
- ✅ **Email Notifications**: HTML templates
- ✅ **File Upload**: AWS S3 integration
- ✅ **Monitoring**: Performance tracking
- ✅ **Security**: Rate limiting, validation

### 🎯 Core Features
- ✅ **Kullanıcı Yönetimi**: Registration, verification, profiles
- ✅ **Öğretmen Sistemi**: Profile management, availability
- ✅ **Rezervasyon**: Full booking system with notifications
- ✅ **Rating System**: Comprehensive review system
- ✅ **Admin Panel**: Complete management dashboard
- ✅ **Search Engine**: Advanced filtering and analytics
- ✅ **Notification System**: Email + Push notifications

## 🛠️ Teknoloji Stack

### Backend Stack
- **Laravel 11** - Modern PHP framework
- **PostgreSQL** - Production-ready database
- **Redis** - Cache ve Queue management
- **JWT** - Secure authentication
- **Docker** - Containerization
- **Nginx** - Web server
- **Prometheus + Grafana** - Monitoring

### Frontend Stack
- **Flutter 3** - Cross-platform mobile app
- **BLoC** - State management
- **Material 3** - Modern UI design
- **Dio** - HTTP client
- **fl_chart** - Data visualization
- **SharedPreferences** - Local storage

### DevOps & Infrastructure
- **Docker Compose** - Multi-container orchestration
- **Nginx** - Reverse proxy & load balancer
- **SSL/TLS** - Secure connections
- **Monitoring** - Prometheus, Grafana
- **Backup** - Automated backup system

## 📊 Platform İstatistikleri

- **80+ API Endpoints** - Comprehensive REST API
- **6 Major Services** - Modular architecture
- **15+ Flutter Screens** - Complete mobile experience
- **16 Database Tables** - Optimized schema
- **Production Ready** - Enterprise-level quality

## 📦 Kurulum

### Gereksinimler
- Docker ve Docker Compose
- Flutter SDK (mobil uygulama için)

### Backend Kurulumu

1. **Docker ile çalıştırma:**
```bash
# Tüm servisleri başlat
docker-compose up -d

# Veritabanı migration'larını çalıştır
docker-compose exec backend php artisan migrate

# Test verilerini yükle
docker-compose exec backend php artisan db:seed
```

2. **Manuel kurulum:**
```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan db:seed
php artisan serve --port=8000
```

### Frontend Kurulumu

```bash
cd frontend/nazliyavuz_app
flutter pub get
flutter run
```

## 🔧 Konfigürasyon

### Backend Environment Variables
```env
APP_NAME="Nazliyavuz Platform"
APP_ENV=production
APP_DEBUG=false
APP_URL=http://localhost

DB_CONNECTION=pgsql
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=nazliyavuz_db
DB_USERNAME=nazliyavuz_user
DB_PASSWORD=nazliyavuz_password

REDIS_HOST=localhost
REDIS_PORT=6379

JWT_SECRET=your_jwt_secret_here
```

### Frontend API Configuration
```dart
// lib/services/api_service.dart
static const String baseUrl = 'http://localhost:8000/api/v1';
```

## 📱 API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Kullanıcı kaydı
- `POST /api/v1/auth/login` - Giriş
- `POST /api/v1/auth/logout` - Çıkış
- `POST /api/v1/auth/refresh` - Token yenileme

### Teachers
- `GET /api/v1/teachers` - Öğretmen listesi
- `GET /api/v1/teachers/{id}` - Öğretmen detayı
- `POST /api/v1/teacher/profile` - Profil oluşturma
- `PUT /api/v1/teacher/profile` - Profil güncelleme

### Reservations
- `GET /api/v1/student/reservations` - Öğrenci rezervasyonları
- `GET /api/v1/teacher/reservations` - Öğretmen rezervasyonları
- `POST /api/v1/reservations` - Rezervasyon oluşturma
- `PUT /api/v1/reservations/{id}/status` - Durum güncelleme

### Categories
- `GET /api/v1/categories` - Kategori listesi
- `GET /api/v1/categories/{slug}` - Kategori detayı

### Notifications
- `GET /api/v1/notifications` - Bildirimler
- `PUT /api/v1/notifications/{id}/read` - Okundu işaretle

## 🧪 Test Verileri

### Admin Kullanıcı
- **Email:** admin@nazliyavuz.com
- **Password:** password

### Örnek Öğretmenler
- **Dr. Zeynep Aktaş** (Piyano) - zeynep@example.com
- **Prof. Dr. Can Özkan** (Matematik) - can@example.com
- **Ece Yıldız** (Yoga) - ece@example.com
- **Emre Şahin** (Programlama) - emre@example.com
- **Selin Korkmaz** (İngilizce) - selin@example.com
- **Murat Güneş** (Gitar) - murat@example.com

### Örnek Öğrenciler
- **Ahmet Yılmaz** - ahmet@example.com
- **Ayşe Demir** - ayse@example.com
- **Mehmet Kaya** - mehmet@example.com
- **Fatma Özkan** - fatma@example.com

**Tüm test kullanıcıları için şifre:** password

## 📊 Veritabanı Şeması

### Ana Tablolar
- `users` - Kullanıcı bilgileri
- `teachers` - Öğretmen profilleri
- `categories` - Kategoriler (hierarchical)
- `reservations` - Rezervasyonlar
- `notifications` - Bildirimler
- `favorites` - Favori öğretmenler
- `audit_logs` - Sistem logları

## 🚀 Deployment

### Production Deployment
```bash
# Docker ile production deployment
docker-compose -f docker-compose.prod.yml up -d

# SSL sertifikası ekleme
# Let's Encrypt ile otomatik SSL
```

### Environment Setup
1. Production environment variables'ları ayarla
2. SSL sertifikası kurulumu
3. Domain name konfigürasyonu
4. Database backup stratejisi

## 📈 Monitoring

### Log Management
- Application logs: `storage/logs/`
- Nginx logs: `/var/log/nginx/`
- Database logs: PostgreSQL logs

### Performance Monitoring
- Laravel Telescope (development)
- Application Performance Monitoring (APM)
- Database query optimization

## 🔒 Güvenlik

### Implemented Security Features
- JWT token authentication
- Password hashing (bcrypt)
- SQL injection protection
- XSS protection
- CSRF protection
- Rate limiting
- Input validation

### Security Best Practices
- Regular security updates
- Environment variable protection
- Database access control
- API rate limiting
- Secure headers

## 🤝 Katkıda Bulunma

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için `LICENSE` dosyasına bakın.

## 📞 İletişim

- **Proje Sahibi:** Nazliyavuz Platform
- **Email:** info@nazliyavuz.com
- **Website:** https://nazliyavuz.com

## 🙏 Teşekkürler

- Laravel ekibine
- Flutter ekibine
- Tüm açık kaynak katkıda bulunanlara

---

**Not:** Bu dokümantasyon sürekli güncellenmektedir. En güncel bilgiler için proje repository'sini takip edin.
