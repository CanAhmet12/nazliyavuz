# Kurumsal Kütüphane Yönetim Sistemi

## Proje Özeti

Kurumsal kütüphane yönetimi için kapsamlı bir sistem. Üyelik yönetimi, katalog arama, ödünç-iade işlemleri, rezervasyon yönetimi, çok şube desteği ve detaylı raporlama özelliklerini içerir.

## Teknoloji Stack

### Backend
- **Framework:** NestJS (Node.js) veya .NET 8
- **Veritabanı:** PostgreSQL
- **Cache & Queue:** Redis
- **Kimlik Doğrulama:** OAuth2/OIDC + MFA

### Frontend
- **Framework:** React + Next.js veya Angular
- **Responsive Design:** Mobil ve desktop uyumlu
- **Erişilebilirlik:** WCAG 2.1 AA standartları

### Altyapı
- **Containerization:** Docker + Kubernetes
- **CI/CD:** GitHub Actions / GitLab CI
- **Monitoring:** Prometheus + Grafana
- **Backup:** Günlük otomatik yedekleme

## Temel Özellikler

### 1. Üyelik Yönetimi
- Kayıt ve doğrulama (e-posta/SMS)
- OAuth2/OIDC kimlik doğrulama
- İki faktörlü doğrulama (MFA)
- Üye profili ve geçmişi

### 2. Katalog & Arama
- Tam metin arama
- Gelişmiş filtreler (yazar, yıl, konu, dil)
- ISBN/barkod arama
- Sıralama ve önizleme

### 3. Ödünç-İade
- Barkod ile hızlı işlem
- Otomatik gecikme hesaplama
- Yenileme kuralları
- Otomatik bildirimler

### 4. Rezervasyon Yönetimi
- Üye rezervasyon yönetimi
- Bekleme listesi
- Otomatik bildirimler

### 5. Çok Şube & Raf Yönetimi
- Şube bazlı envanter
- Transfer yönetimi
- Bölüm/raf hiyerarşisi

### 6. Raporlama
- Envanter raporları
- Dolaşım raporları
- Gecikme raporları
- CSV/PDF dışa aktarma

### 7. Portallar
- **Personel Paneli:** Yönetim ve iş akışları
- **Üye Portalı:** Kullanıcı dostu arayüz
- **Yönetici Paneli:** Tenant ve şube yönetimi

## Güvenlik & Uyumluluk

- KVKK uyumlu veri saklama
- Veri şifreleme (in-transit & at-rest)
- RBAC (Rol Tabanlı Erişim Kontrolü)
- Audit logs (denetim kayıtları)
- Rate limiting
- WCAG 2.1 AA erişilebilirlik

## Paketler & Fiyatlandırma

### MVP Paketi - İlk Sürüm
**Özellikler:**
- Tek şube desteği
- Temel üyelik yönetimi
- Katalog ve arama
- Barkod ile ödünç-iade
- Basit rezervasyon
- Temel raporlar
- Üye ve personel portalları

**Geliştirme Süresi:** 6-8 hafta

**Fiyat:** **85.000 TL**

---

### Standart Kurumsal Paketi
**Özellikler:**
- MVP + tüm özellikler
- Çok şube desteği
- Raf yönetimi
- Gelişmiş raporlama
- RBAC ve audit log
- Çok dilli destek
- Performans optimizasyonu

**Geliştirme Süresi:** 10-14 hafta

**Fiyat:** **130.000 TL**

---

### Enterprise Paketi
**Özellikler:**
- Standart + tüm özellikler
- Çok-tenant (çok kuruluş) desteği
- RFID entegrasyonu (opsiyonel)
- SIP2/NCIP entegrasyonu
- Donanım tedarik yönetimi
- 7/24 SLA desteği
- Saha kurulum desteği
- 12 aylık bakım

**Geliştirme Süresi:** 16-20 hafta

**Fiyat:** **220.000 TL**

*Not: RFID donanım ve kurulum maliyeti ayrıca hesaplanır.*

---

## Geliştirme Aşamaları

### Faz 1: Hazırlık & Analiz (2 hafta)
- Gereksinim analizi
- Veri göç planı
- Tasarım onayları

### Faz 2: MVP Geliştirme (6-8 hafta)
- Temel modüller
- Üye ve personel paneli
- Basit raporlar
- Test ve iyileştirmeler

### Faz 3: Standart Özellikler (3-4 hafta)
- Çok şube desteği
- Gelişmiş raporlama
- RBAC ve güvenlik
- İyileştirmeler

### Faz 4: Enterprise Özellikler (5-7 hafta)
- Çok-tenant mimarisi
- RFID/SIP2 entegrasyonları
- Donanım kurulumları
- Performans optimizasyonu

### Faz 5: Test & Yayın (3-4 hafta)
- Erişilebilirlik denetimi
- Güvenlik denetimi
- KVKK uyum kontrolü
- Canlı ortam kurulumu

**Toplam Süre:**
- MVP: 2-3 ay
- Standart: 3-4 ay
- Enterprise: 5-7 ay

---

## Teslim Edilecekler

- Tam çalışan kod tabanı  
- Docker container yapılandırması  
- API dokümantasyonu  
- Veritabanı şeması (ERD)  
- Migration script'leri  
- Kullanıcı kılavuzu  
- Test raporları  
- Güvenlik raporu  
- KVKK uyum raporu  
- 30 gün ücretsiz destek  

---

## İletişim & Başlangıç

### Başlangıç Adımları

1. **Paket Seçimi:** MVP, Standart veya Enterprise
2. **Sözleşme:** Proje detayları ve gizlilik anlaşması
3. **Ödeme:** Başlangıç %30, aşamalı ödeme
4. **Workshop:** 2 haftalık gereksinim analizi
5. **Geliştirme:** Hemen başlayalım!

### Bakım & Destek

- **Aylık Bakım:** %10-15 yıllık proje maliyeti
- **SLA:** Kritik hatalar için 4 saat müdahale
- **Uptime:** %99.9 hedef
- **Hosting:** AWS/GCP/Azure veya kurum içi

---

## Neden Bu Projeyi Seçmelisiniz?

- Kurumsal kütüphane deneyimi  
- KVKK ve güvenlik odaklı yaklaşım  
- Ölçeklenebilir ve sağlam mimari  
- Opsiyonel donanım entegrasyonları  
- Kapsamlı dokümantasyon ve destek  
- Modern teknolojiler  

---
## Hazırlayan

**AHMET CAN KARAKIŞLA**

**FINTELLİ YAZILIM GELİŞTİRME STARTUP**

Ankara, Gölbaşı
