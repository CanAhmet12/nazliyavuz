# 📹 VIDEO CALL TEST KILAVUZU

## 🎯 Video Görüşme Sistemi - Test ve Kullanım Rehberi

**Durum:** ✅ %95 Tamamlanmış - Test Aşamasında

---

## 📋 SİSTEM GEREKSİNİMLERİ

### Cihaz Gereksinimleri:
- ✅ **2 gerçek cihaz** (1 telefon + 1 tablet veya 2 telefon)
- ✅ **İyi internet bağlantısı** (WiFi veya 4G)
- ✅ **Kamera izni** (her iki cihazda)
- ✅ **Mikrofon izni** (her iki cihazda)

### Yazılım Gereksinimleri:
- ✅ Flutter SDK 3.8.1+
- ✅ flutter_webrtc: ^1.2.0 (aktif)
- ✅ pusher_channels_flutter: ^2.2.1 (aktif)
- ✅ Backend API çalışıyor olmalı

---

## 🚀 HIZLI TEST (5 Dakika)

### Adım 1: İki Cihaza Uygulama Yükle
```bash
# Cihaz 1 (Öğretmen)
flutter run -d <device-1-id>

# Cihaz 2 (Öğrenci)
flutter run -d <device-2-id>
```

### Adım 2: Farklı Kullanıcılarla Giriş Yap
```
Cihaz 1: Teacher hesabı
Cihaz 2: Student hesabı
```

### Adım 3: Chat Aç ve Video Call Başlat
```
1. Cihaz 1'de: Chat listesinden öğrenciyi seç
2. Üst sağ köşedeki 📹 (video call) ikonuna tıkla
3. Cihaz 2'de: Incoming call ekranı görünecek
4. "Accept" (Kabul Et) butonuna tıkla
5. ✅ Video görüşme başlamalı!
```

---

## 🔍 DETAYLI TEST SENARYOLARI

### Test 1: Video Call Başlatma
**Beklenen Davranış:**
```
1. ✅ Kamera izni istenmeli (ilk kullanımda)
2. ✅ Mikrofon izni istenmeli (ilk kullanımda)
3. ✅ Local video görünmeli (kendi kameranız)
4. ✅ "Aranıyor..." mesajı görünmeli
5. ✅ Karşı tarafta "Incoming Call" ekranı açılmalı
6. ✅ Zil/titreşim olmalı (push notification)
```

**Test Adımları:**
```bash
1. ChatScreen'de video call butonuna tıkla
2. İzinleri onayla
3. Local video'nun göründüğünü kontrol et
4. Karşı cihazda incoming call ekranını kontrol et
```

**❌ Hata Senaryoları:**
- Kamera izni reddedilirse → Error mesajı göster
- Internet yoksa → "Bağlantı hatası" mesajı
- Karşı taraf offline ise → "Kullanıcı müsait değil"

---

### Test 2: Call Yanıtlama
**Beklenen Davranış:**
```
1. ✅ "Accept" butonuna tıklandığında kamera açılmalı
2. ✅ Local video görünmeli
3. ✅ Remote video görünmeli (arayan taraf)
4. ✅ Call controls görünmeli (mute, video, end)
5. ✅ Call timer başlamalı (00:00 → 00:01 → ...)
```

**Test Adımları:**
```bash
1. Incoming call ekranında "Accept" tıkla
2. 2-3 saniye bekle
3. Her iki cihazda da video görüldüğünü kontrol et
4. Ses testini yap (konuş, karşı taraf duyuyor mu?)
```

**❌ Hata Senaryoları:**
- Remote video gelmiyorsa → Pusher signaling kontrol et
- Ses duyulmuyorsa → Mikrofon izni kontrol et
- Black screen → Kamera izni/compatibility

---

### Test 3: Call Controls
**Beklenen Davranış:**
```
Mute Button:
✅ Tıklandığında mikrofonun kapanması
✅ Icon değişmesi (mic → mic_off)
✅ Karşı tarafın sesi duymaması

Video Button:
✅ Tıklandığında kameranın kapanması
✅ Icon değişmesi (videocam → videocam_off)
✅ Karşı tarafta black screen/placeholder

Switch Camera Button:
✅ Ön kamera ↔ Arka kamera geçişi
✅ Video stream'in kesintisiz devam etmesi

End Call Button:
✅ Çağrının sonlanması
✅ Her iki tarafın da call screen'den çıkması
✅ Backend'e call end kaydının gitmesi
```

**Test Adımları:**
```bash
1. Mute butonuna tıkla → konuş → karşı taraf duymamalı
2. Mute'u kaldır → konuş → karşı taraf duymalı
3. Video butonuna tıkla → karşı tarafta black screen
4. Video'yu aç → karşı tarafta video gelmeli
5. Switch camera → ön/arka kamera geçişi
6. End call → her iki taraf da kapatmalı
```

---

### Test 4: Call Timer ve Duration
**Beklenen Davranış:**
```
✅ Call timer başlamalı (00:00)
✅ Her saniye artmalı (00:01, 00:02, ...)
✅ Call bittiğinde duration backend'e kaydedilmeli
✅ Call history'de duration görünmeli
```

**Test Adımları:**
```bash
1. Call'u başlat ve 30 saniye konuş
2. Call'u sonlandır
3. Backend'de call history'yi kontrol et:
   GET /api/v1/video-call/history
4. Duration'ın 30 saniye olduğunu doğrula
```

---

### Test 5: Network Quality
**Beklenen Davranış:**
```
WiFi → 4G Geçişi:
✅ Bağlantı korunmalı (reconnect)
✅ Video/Audio kesintisiz devam etmeli

Zayıf Internet:
✅ Video quality düşmeli (adaptive bitrate)
✅ Bağlantı kopmamalı

Internet Kesilmesi:
✅ "Bağlantı koptu" mesajı
✅ Auto-reconnect denemesi (5 saniye)
✅ Başarısızsa call sonlanmalı
```

**Test Adımları:**
```bash
1. WiFi'da call başlat
2. WiFi'ı kapat, 4G'ye geç
3. Bağlantının devam ettiğini kontrol et
4. Airplane mode aç → call sonlanmalı
```

---

### Test 6: Call History ve Statistics
**Beklenen Davranış:**
```
✅ Her call backend'e kaydedilmeli
✅ Call history ekranında görünmeli
✅ Duration, date, time bilgileri doğru
✅ Call statistics hesaplanmalı
```

**Test Adımları:**
```bash
1. 2-3 adet call yap
2. Call history ekranını aç
3. Tüm call'ları gördüğünü kontrol et
4. Statistics'i kontrol et:
   - Total calls
   - Total duration
   - Average duration
```

---

## 🐛 BILINEN SORUNLAR ve ÇÖZÜMLER

### Sorun 1: Remote Video Gelmiyor
**Belirtiler:**
```
✅ Local video görünüyor
❌ Remote video siyah ekran
```

**Çözüm:**
```bash
1. Pusher signaling channel kontrol et
2. Backend logs kontrol et:
   - Offer/Answer SDP exchange
   - ICE candidate exchange
3. Her iki cihazda da internet var mı?
4. STUN server erişilebilir mi?
```

**Debug:**
```dart
// webrtc_service.dart içinde:
print('📤 [WEBRTC] Offer sent: $offer');
print('📥 [WEBRTC] Answer received: $answer');
print('🧊 [WEBRTC] ICE candidate: $candidate');
```

---

### Sorun 2: Ses Duyulmuyor
**Belirtiler:**
```
✅ Video görünüyor
❌ Ses gelmiyor
```

**Çözüm:**
```bash
1. Mikrofon izni verildi mi?
2. Mute durumu kontrol et (kazara mute olabilir)
3. Ses seviyesi kontrol et (0 olabilir)
4. Bluetooth kulaklık bağlı mı? (audio routing)
```

**Debug:**
```dart
// Mikrofon izni kontrol:
await Permission.microphone.status;

// Audio track kontrol:
final audioTracks = localStream.getAudioTracks();
print('Audio tracks: ${audioTracks.length}');
print('Audio enabled: ${audioTracks.first.enabled}');
```

---

### Sorun 3: Call Bağlanamiyor
**Belirtiler:**
```
✅ Call başlatıldı
❌ "Aranıyor..." sürekli görünüyor
❌ Karşı tarafa bildirim gitmiyor
```

**Çözüm:**
```bash
1. Backend API çalışıyor mu?
   curl http://34.122.224.35/api/v1/health
   
2. Push notification ayarları doğru mu?
   - Firebase config
   - FCM token kayıtlı mı?
   
3. Pusher connection var mı?
   - Pusher dashboard'da connection görünüyor mu?
```

---

### Sorun 4: Kamera Açılmıyor
**Belirtiler:**
```
❌ Kamera izni hatası
❌ Black screen
```

**Çözüm:**
```bash
1. Kamera izni verildi mi?
   Ayarlar → Uygulamalar → Nazliyavuz → İzinler → Kamera
   
2. Başka uygulama kamerayı kullanıyor mu?
   - Tüm uygulamaları kapat
   - Cihazı yeniden başlat
   
3. Kamera hardware sorunlu mu?
   - Standart kamera uygulamasını test et
```

---

## 📊 TEST CHECKLIST

### ✅ Temel Özellikler
- [ ] Video call başlatma (caller)
- [ ] Video call yanıtlama (receiver)
- [ ] Local video görünüyor
- [ ] Remote video görünüyor
- [ ] Ses duyuluyor (her iki yön)
- [ ] Call timer çalışıyor

### ✅ Call Controls
- [ ] Mute/Unmute çalışıyor
- [ ] Video On/Off çalışıyor
- [ ] Switch camera çalışıyor
- [ ] End call çalışıyor

### ✅ Edge Cases
- [ ] Call reject çalışıyor
- [ ] Call timeout (30 saniye cevapsız)
- [ ] Network değişimi (WiFi → 4G)
- [ ] Background handling (uygulama minimize)
- [ ] Incoming call while in call

### ✅ Backend Integration
- [ ] Call history kaydediliyor
- [ ] Duration doğru hesaplanıyor
- [ ] Statistics güncelleniyor
- [ ] Push notifications gidiyor

---

## 🎯 BAŞARILI TEST KRİTERLERİ

### ✅ Test Başarılı Sayılır:
```
1. ✅ Video call 30 saniye kesintisiz çalışmalı
2. ✅ Her iki tarafta video/audio görünmeli
3. ✅ Tüm controls çalışmalı
4. ✅ Call history kaydedilmeli
5. ✅ Error handling düzgün çalışmalı
```

### ❌ Test Başarısız Sayılır:
```
1. ❌ Video/Audio bağlantı kurulmuyor
2. ❌ Sürekli reconnect deniyor
3. ❌ Controls çalışmıyor
4. ❌ Call history kaydedilmiyor
5. ❌ App crash oluyor
```

---

## 📱 TEST SONUÇLARI RAPORU

```
Test Tarihi: __________
Test Eden: __________
Cihaz 1: __________
Cihaz 2: __________
Network: WiFi / 4G

[ ] Video Call Başlatma - BAŞARILI / BAŞARISIZ
[ ] Call Yanıtlama - BAŞARILI / BAŞARISIZ
[ ] Video Quality - İYİ / ORTA / KÖTÜ
[ ] Audio Quality - İYİ / ORTA / KÖTÜ
[ ] Controls - BAŞARILI / BAŞARISIZ
[ ] Call History - BAŞARILI / BAŞARISIZ

Notlar:
_______________________________________
_______________________________________
```

---

## 🚨 SORUN RAPORLAMA

Sorun bulursanız:
```
1. Screenshot al
2. Video kaydı al (mümkünse)
3. Console logs'u kaydet
4. Aşağıdaki bilgileri topla:
   - Cihaz modeli
   - Android/iOS versiyonu
   - App versiyonu
   - İnternet hızı
   - Error mesajı
```

---

## ✅ FİNAL CHECKLIST

Test tamamlandığında:
- [ ] Video call 10 kez başarılı oldu
- [ ] Tüm controls test edildi
- [ ] Network geçişleri test edildi
- [ ] Call history doğru çalışıyor
- [ ] Dokümantasyon güncellendi
- [ ] Bug raporları oluşturuldu (varsa)

**✅ PAKET 1 - VİDEO CALL: TAMAMLANDI!** 🎉

---

**Hazırlayan:** AI Assistant  
**Tarih:** 20 Ekim 2025  
**Versiyon:** 1.0  
**Proje:** Nazliyavuz (TERENCE EĞİTİM)

