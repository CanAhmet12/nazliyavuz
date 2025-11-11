# 🔐 SOSYAL MEDYA GİRİŞİ - YAPILANDIRMA REHBERİ

## 🎯 Google ve Apple Sign-In Kurulum Rehberi

**Durum:** ✅ %95 Tamamlanmış - Sadece Konfigürasyon Gerekiyor

---

## 📋 İÇİNDEKİLER

1. [Google Sign-In Kurulumu](#google-sign-in)
2. [Apple Sign-In Kurulumu](#apple-sign-in)
3. [Test Senaryoları](#test)
4. [Sorun Giderme](#troubleshooting)

---

## 🔵 GOOGLE SIGN-IN KURULUMU

### ✅ Kod Hazır - Sadece Konfigürasyon Gerekiyor!

### Adım 1: Firebase Console Setup

#### 1.1 Firebase Project Oluştur/Seç
```
1. https://console.firebase.google.com/ gir
2. Mevcut projeyi seç veya yeni oluştur
3. Project Settings (⚙️) > General
```

#### 1.2 Android App Ekle (İlk Kez İse)
```
1. "Add app" > Android
2. Package name: com.nazliyavuz.app
3. App nickname: Nazliyavuz App
4. Download google-services.json
5. android/app/ klasörüne kopyala
```

#### 1.3 iOS App Ekle (İlk Kez İse)
```
1. "Add app" > iOS
2. Bundle ID: com.nazliyavuz.app
3. App nickname: Nazliyavuz App
4. Download GoogleService-Info.plist
5. ios/Runner/ klasörüne kopyala (Xcode ile)
```

---

### Adım 2: Android Configuration

#### 2.1 SHA-1 Fingerprint Al
```bash
cd nazliyavuz-platform/frontend/nazliyavuz_app/android
./gradlew signingReport
```

**Output'ta şunu ara:**
```
Variant: debug
Config: debug
Store: C:\Users\AHMET CAN\.android\debug.keystore
Alias: AndroidDebugKey
SHA1: A1:B2:C3:D4:E5:F6:...  ← BUNU KOPYALA
```

#### 2.2 SHA-1'i Firebase'e Ekle
```
1. Firebase Console > Project Settings
2. Scroll down > "Your apps" bölümü
3. Android app seç
4. "Add fingerprint" butonuna tıkla
5. SHA-1'i yapıştır
6. Save
```

#### 2.3 google-services.json Güncelle
```
1. Firebase Console > Project Settings
2. Android app > "Download google-services.json"
3. İndirilen dosyayı android/app/ klasörüne kopyala (üzerine yaz)
```

#### 2.4 OAuth Consent Screen
```
1. Google Cloud Console'a git: https://console.cloud.google.com/
2. APIs & Services > OAuth consent screen
3. User type: External seç
4. App name: Nazliyavuz
5. User support email: <sizin email>
6. Developer contact: <sizin email>
7. Save and Continue
```

#### 2.5 OAuth Client ID (Otomatik)
```
Firebase Android app eklendiğinde otomatik oluşur.
Kontrol: APIs & Services > Credentials
```

---

### Adım 3: iOS Configuration

#### 3.1 Bundle ID Kontrol
```bash
# Xcode ile aç:
open nazliyavuz-platform/frontend/nazliyavuz_app/ios/Runner.xcworkspace

# Bundle ID'yi kontrol et:
Runner > General > Bundle Identifier
Örn: com.nazliyavuz.app
```

#### 3.2 GoogleService-Info.plist Ekle
```
1. Firebase Console > iOS app > Download GoogleService-Info.plist
2. Xcode'da Runner klasörüne sağ tıkla
3. Add Files to "Runner"
4. GoogleService-Info.plist'i seç
5. "Copy items if needed" işaretle
6. Add
```

#### 3.3 URL Schemes Ekle
```
1. Xcode'da Runner seç
2. Info tab > URL Types
3. "+" butonuna tıkla

URL Scheme #1: (GoogleService-Info.plist'ten)
- Identifier: google
- URL Schemes: com.googleusercontent.apps.XXXXX
  (GoogleService-Info.plist > REVERSED_CLIENT_ID değerini kopyala)

NOT: GoogleService-Info.plist'i TextEdit ile aç:
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.123456789-xxx</string>
```

#### 3.4 Info.plist Güncelle
```xml
<!-- ios/Runner/Info.plist -->

<!-- Mevcut <dict> tag'i içine ekle: -->

<!-- Google Sign-In URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.XXXXXXX</string>
        </array>
    </dict>
</array>

<!-- Google Client ID (opsiyonel) -->
<key>GIDClientID</key>
<string>XXXXXXX.apps.googleusercontent.com</string>
```

---

### Adım 4: Test Google Sign-In

#### 4.1 Android Test
```bash
# Build ve run
flutter clean
flutter pub get
flutter run -d <android-device-id>

# Test:
1. Login ekranına git
2. "Google" butonuna tıkla
3. Google hesabını seç
4. İzinleri onayla
5. ✅ Ana sayfaya yönlendirilmeli
```

#### 4.2 iOS Test
```bash
# Build ve run
flutter clean
flutter pub get
flutter run -d <ios-device-id>

# Test:
1. Login ekranına git
2. "Google" butonuna tıkla
3. Google hesabını seç
4. İzinleri onayla
5. ✅ Ana sayfaya yönlendirilmeli
```

---

## 🍎 APPLE SIGN-IN KURULUMU

### ⚠️ Gereksinimler:
- Apple Developer Account ($99/yıl) **ZORUNLU**
- iOS **Gerçek Cihaz** (Simulator çalışmaz!)
- macOS (Xcode gerekiyor)

---

### Adım 1: Apple Developer Portal

#### 1.1 Developer Account Kontrol
```
1. https://developer.apple.com/ gir
2. Apple ID ile giriş yap
3. Membership aktif mi kontrol et ($99/yıl)
```

#### 1.2 App ID'yi Yapılandır
```
1. Certificates, Identifiers & Profiles
2. Identifiers > App IDs
3. com.nazliyavuz.app'i bul (veya oluştur)
4. "Sign in with Apple" özelliğini işaretle
5. Save
```

---

### Adım 2: Xcode Configuration

#### 2.1 Signing & Capabilities
```bash
# Xcode ile aç:
open ios/Runner.xcworkspace
```

```
1. Runner seç (sol panel)
2. Signing & Capabilities tab
3. "Automatically manage signing" işaretle
4. Team: Apple Developer account'ını seç
5. "+ Capability" butonuna tıkla
6. "Sign in with Apple" seç
```

#### 2.2 Bundle ID Doğrula
```
1. Runner > General tab
2. Bundle Identifier: com.nazliyavuz.app
3. Team seçili olmalı
```

---

### Adım 3: Backend Configuration (Zaten Yapılmış)

Backend'de Apple Sign-In endpoint'i hazır:
```
POST /api/v1/auth/social/apple
```

---

### Adım 4: Test Apple Sign-In

#### ⚠️ SADECE iOS GERÇEK CİHAZDA ÇALIŞIR!

```bash
# iOS gerçek cihaz bağla
flutter devices

# Run
flutter run -d <ios-device-id>

# Test:
1. Login ekranına git
2. "Apple" butonuna tıkla
3. Face ID / Touch ID ile onayla
4. Email paylaşımını seç (Hide / Share)
5. ✅ Ana sayfaya yönlendirilmeli
```

---

## 🧪 TEST SENARYOLARI

### Test 1: Google Sign-In (Yeni Kullanıcı)
```
1. Login ekranında "Google" butonuna tıkla
2. Google hesabı seç (ilk kez kullanılıyor)
3. İzinleri onayla
4. ✅ Otomatik kayıt olmalı
5. ✅ Ana sayfaya yönlendirilmeli
6. ✅ Profil fotoğrafı sync olmalı
```

### Test 2: Google Sign-In (Mevcut Kullanıcı)
```
1. Login ekranında "Google" butonuna tıkla
2. Daha önce kaydolmuş Google hesabı seç
3. ✅ Otomatik giriş yapmalı
4. ✅ Ana sayfaya yönlendirilmeli
```

### Test 3: Google Sign-In (Email Conflict)
```
Senaryo: Email zaten başka hesapla kayıtlı

1. Login ekranında "Google" butonuna tıkla
2. Email'i zaten kayıtlı bir hesap seç
3. ❌ Hata mesajı göstermeli:
   "Bu email adresi zaten kayıtlı. Lütfen şifrenizle giriş yapın."
```

### Test 4: Apple Sign-In (Hide Email)
```
1. Login ekranında "Apple" butonuna tıkla
2. "Hide My Email" seç
3. ✅ Apple private relay email kullanılmalı
4. ✅ Kayıt tamamlanmalı
```

### Test 5: Account Linking
```
1. Normal email/password ile kayıt ol
2. Profile > Settings > Linked Accounts
3. "Link Google Account" tıkla
4. Google hesabını seç
5. ✅ Hesap bağlanmalı
6. ✅ Her iki yöntemle de giriş yapılabilmeli
```

---

## 🐛 SORUN GİDERME

### Sorun 1: "PlatformException: sign_in_failed"

**Sebep:** SHA-1 fingerprint eksik veya yanlış

**Çözüm:**
```bash
1. SHA-1'i yeniden al:
   cd android && ./gradlew signingReport

2. Firebase Console'da güncelle:
   Project Settings > Android app > Add fingerprint

3. google-services.json'ı yeniden indir

4. Clean build:
   flutter clean && flutter pub get && flutter run
```

---

### Sorun 2: "Error 403: Access Denied"

**Sebep:** OAuth consent screen yapılandırılmamış

**Çözüm:**
```
1. Google Cloud Console > OAuth consent screen
2. User type: External seç
3. App name ve email'leri ekle
4. Save
5. Tekrar dene
```

---

### Sorun 3: "Invalid client"

**Sebep:** OAuth Client ID yanlış veya eksik

**Çözüm:**
```
1. Firebase Console > Project Settings
2. Android/iOS app > Delete
3. Yeniden ekle (SHA-1/Bundle ID ile)
4. google-services.json / GoogleService-Info.plist güncelle
```

---

### Sorun 4: Apple Sign-In "Not Supported"

**Sebep:** Android cihazda veya iOS simulator'da test ediliyor

**Çözüm:**
```
Apple Sign-In SADECE iOS gerçek cihazda çalışır!
- iOS gerçek cihaz bağla
- flutter run -d <ios-device-id>
```

---

### Sorun 5: "Capability not found"

**Sebep:** Xcode'da "Sign in with Apple" capability eklenmemiş

**Çözüm:**
```
1. Xcode > Runner > Signing & Capabilities
2. "+ Capability"
3. "Sign in with Apple" ekle
4. Clean build
```

---

## ✅ KONFIGÜRASYON CHECKLIST

### Android:
- [ ] google-services.json android/app/ klasöründe
- [ ] SHA-1 fingerprint Firebase'e eklendi
- [ ] OAuth consent screen yapılandırıldı
- [ ] Google Sign-In test edildi

### iOS:
- [ ] GoogleService-Info.plist ios/Runner/ klasöründe
- [ ] URL Schemes (REVERSED_CLIENT_ID) eklendi
- [ ] Bundle ID doğru
- [ ] Google Sign-In test edildi

### iOS (Apple Sign-In):
- [ ] Apple Developer account aktif
- [ ] App ID'de "Sign in with Apple" etkin
- [ ] Xcode'da capability eklendi
- [ ] iOS gerçek cihazda test edildi

---

## 📊 TEST RAPORU

```
Test Tarihi: __________
Test Eden: __________

GOOGLE SIGN-IN:
[ ] Android - Yeni kullanıcı - BAŞARILI / BAŞARISIZ
[ ] Android - Mevcut kullanıcı - BAŞARILI / BAŞARISIZ
[ ] iOS - Yeni kullanıcı - BAŞARILI / BAŞARISIZ
[ ] iOS - Mevcut kullanıcı - BAŞARILI / BAŞARISIZ

APPLE SIGN-IN:
[ ] iOS - Yeni kullanıcı - BAŞARILI / BAŞARISIZ
[ ] iOS - Mevcut kullanıcı - BAŞARILI / BAŞARISIZ
[ ] iOS - Hide email - BAŞARILI / BAŞARISIZ
[ ] iOS - Share email - BAŞARILI / BAŞARISIZ

ACCOUNT LINKING:
[ ] Google hesap bağlama - BAŞARILI / BAŞARISIZ
[ ] Apple hesap bağlama - BAŞARILI / BAŞARISIZ

Notlar:
_______________________________________
```

---

## 🎯 FİNAL CHECKLIST

- [ ] Google Sign-In Android'de çalışıyor
- [ ] Google Sign-In iOS'ta çalışıyor
- [ ] Apple Sign-In iOS'ta çalışıyor (gerçek cihaz)
- [ ] Profil fotoğrafları sync oluyor
- [ ] Account linking çalışıyor
- [ ] Error handling doğru çalışıyor
- [ ] Tüm test senaryoları başarılı

**✅ PAKET 1 - SOCIAL AUTH: TAMAMLANDI!** 🎉

---

**Hazırlayan:** AI Assistant  
**Tarih:** 20 Ekim 2025  
**Versiyon:** 1.0  
**Proje:** Nazliyavuz (TERENCE EĞİTİM)

