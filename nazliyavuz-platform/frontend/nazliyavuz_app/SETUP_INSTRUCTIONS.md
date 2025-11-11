# 🚀 OTOMATIK SETUP TALİMATLARI

## ⚠️ SADECE 3 ADIM KALDI!

Bu işlemleri **sadece siz** yapabilirsiniz çünkü Firebase hesabınıza erişim gerekiyor.
Ama her şeyi maksimum kolaylaştırdık!

---

## 📱 ADIM 1: SHA-1 Fingerprint Alın (5 dakika)

### Windows için:

```powershell
# Bu komutu PowerShell'de çalıştırın:
cd "C:\Users\AHMET CAN\Desktop\nazliyavuz - Kopya\nazliyavuz-platform\frontend\nazliyavuz_app\android"
.\gradlew signingReport
```

### Çıktıda şunu arayın:

```
Variant: debug
Config: debug
Store: C:\Users\...\.android\debug.keystore
Alias: AndroidDebugKey
MD5: XX:XX:XX:...
SHA1: A1:B2:C3:D4:E5:F6:G7:H8:I9:J0:K1:L2:M3:N4:O5:P6:Q7:R8:S9:T0  ← BUNU KOPYALAYIN!
SHA-256: ...
```

**SHA1 satırındaki değeri kopyalayın!**

---

## 🔥 ADIM 2: Firebase Console'da SHA-1 Ekleyin (3 dakika)

1. **Firebase Console'a gidin:** https://console.firebase.google.com

2. **Projenizi seçin** (TERENCE EĞİTİM veya Nazliyavuz)

3. Sol üstteki **⚙️ (Ayarlar) → Project Settings** tıklayın

4. Aşağı kaydırın, **"Your apps"** bölümünde **Android** uygulamanızı bulun

5. **"SHA certificate fingerprints"** başlığında **"Add fingerprint"** butonuna tıklayın

6. Kopyaladığınız SHA-1'i yapıştırın ve **Save** tıklayın

7. Aynı sayfada **"google-services.json"** butonuna tıklayın ve dosyayı indirin

8. İndirdiğiniz dosyayı **şuraya kopyalayın:**
   ```
   C:\Users\AHMET CAN\Desktop\nazliyavuz - Kopya\nazliyavuz-platform\frontend\nazliyavuz_app\android\app\google-services.json
   ```

---

## 🍎 ADIM 3: iOS için GoogleService-Info.plist (2 dakika)

1. **Aynı Firebase Console sayfasında** (Project Settings)

2. **iOS** uygulamanızı bulun

3. **"GoogleService-Info.plist"** butonuna tıklayın ve indirin

4. İndirdiğiniz dosyayı **şuraya kopyalayın:**
   ```
   C:\Users\AHMET CAN\Desktop\nazliyavuz - Kopya\nazliyavuz-platform\frontend\nazliyavuz_app\ios\Runner\GoogleService-Info.plist
   ```

5. **Dosyayı text editor ile açın** ve şu satırı bulun:
   ```xml
   <key>REVERSED_CLIENT_ID</key>
   <string>com.googleusercontent.apps.123456789-abcdefg</string>
   ```
   
6. `com.googleusercontent.apps.123456789-abcdefg` değerini **kopyalayın**

7. Bu dosyayı açın:
   ```
   C:\Users\AHMET CAN\Desktop\nazliyavuz - Kopya\nazliyavuz-platform\frontend\nazliyavuz_app\ios\Runner\Info.plist
   ```

8. Şu satırı bulun:
   ```xml
   <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
   ```

9. `YOUR-CLIENT-ID` yerine kopyaladığınız değeri yapıştırın

---

## ✅ İŞTE BU KADAR!

Artık test edebilirsiniz:

```bash
cd "C:\Users\AHMET CAN\Desktop\nazliyavuz - Kopya\nazliyavuz-platform\frontend\nazliyavuz_app"
flutter pub get
flutter run
```

---

## 🎯 TEST CHECKLIST

Uygulamayı çalıştırdıktan sonra test edin:

- [ ] Login ekranında "Google ile Giriş" butonu var mı?
- [ ] Butona tıklayınca Google hesap seçimi açılıyor mu?
- [ ] Giriş yapılabiliyor mu?
- [ ] Chat ekranında mikrofon butonu var mı?
- [ ] Sesli mesaj kaydediliyor mu?
- [ ] Sesli mesaj oynatılıyor mu?
- [ ] Video call butonu çalışıyor mu?

---

## ❓ SORUN ÇIKARSA

**Problem: "PlatformException"**
→ SHA-1'i doğru eklediniz mi? google-services.json güncel mi?

**Problem: "Google Sign-In failed"**
→ Firebase Console'da Android package name doğru mu?
→ SHA-1 eklenmiş mi?

**Problem: iOS'ta çalışmıyor**
→ GoogleService-Info.plist doğru yere kopyalandı mı?
→ Info.plist'teki URL Scheme düzeltildi mi?

---

**Yardım:** Herhangi bir adımda takılırsanız ekran görüntüsü gönderin!


