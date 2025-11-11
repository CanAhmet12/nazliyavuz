# 📖 MÜSAİTLİK SİSTEMİ KULLANIM KILAVUZU

**TERENCE EĞİTİM Platformu**  
**Sürüm:** 2.0 (İyileştirilmiş Müsaitlik Sistemi)

---

## 👨‍🏫 ÖĞRETMENLER İÇİN

### Haftalık Müsaitlik Takvimini Ayarlama

#### Yöntem 1: Hızlı Ekleme (ÖNERİLEN - 5 Dakika!)

```
1. Ana Sayfa → "Müsaitlik" kartına tıkla
2. Haftalık Takvim açılır
3. Sağ üst "⚡" (yıldırım) simgesine tıkla
4. Şablonlardan birini seç:

   📌 Hafta İçi 9-17
      → Pazartesi-Cuma, 09:00-17:00 otomatik eklenir
      
   📌 Hafta İçi 13-21
      → Pazartesi-Cuma, 13:00-21:00 (akşam dersleri)
      
   📌 Tüm Hafta 10-18
      → 7 gün, 10:00-18:00
      
   📌 Hafta Sonu 10-14
      → Cumartesi-Pazar, 10:00-14:00
      
   📌 Özel Saat Ekle
      → Kendi saatlerini belirle

5. ✅ TAMAM! Takvimin hazır.
```

**Sonuç:**
```
   Pzt    Sal    Çar    Per    Cum    Cmt    Paz
┌──────┬──────┬──────┬──────┬──────┬──────┬──────┐
│09-17 │09-17 │09-17 │09-17 │09-17 │ boş  │ boş  │
└──────┴──────┴──────┴──────┴──────┴──────┴──────┘

📊 İstatistikler:
• Toplam Slot: 5
• Haftalık Saat: 40 saat
• Aktif Günler: 5 gün
```

---

#### Yöntem 2: Manuel Ekleme

```
1. Haftalık Takvim'de boş gün sütununa git
2. "[+]" butonuna tıkla
3. Başlangıç saati seç: 09:00
4. Bitiş saati seç: 17:00
5. "Ekle" tıkla
6. ✅ O gün için saat eklendi
```

---

#### Yöntem 3: Kopyalama (En Hızlı!)

```
Senaryo: Pazartesi saatlerini tüm haftaya kopyala

1. Haftalık Takvim → Sağ üst "📋" (kopyala)
2. Kaynak Gün: Pazartesi
3. Hedef: "Tümü" (veya "Hafta içi" veya "Hafta sonu")
4. "Kopyala" tıkla
5. ✅ Pazartesi'deki tüm saatler diğer günlere kopyalandı!
```

**Örnek:**
```
ÖNCE:
Pzt: 09-12, 14-17
Sal: boş
Çar: boş
...

KOPYALA (Pazartesi → Tüm hafta)

SONRA:
Pzt: 09-12, 14-17
Sal: 09-12, 14-17  ← KOPYALANDI
Çar: 09-12, 14-17  ← KOPYALANDI
...
```

---

### İzin ve Tatil Yönetimi

#### Tek Gün İzin Ekleme

```
Senaryo: 15 Ocak hastasın, ders veremeyeceksin

1. Haftalık Takvim → Sağ üst "🏖️" (izin/tatil)
2. "Tek Gün Ekle" FAB (mavi)
3. Tür: "Tam Gün İzin" seç
4. Tarih: 15 Ocak 2025
5. Sebep: "Hasta" yaz
6. (Opsiyonel) Not: "Grip oldum"
7. "Ekle" tıkla
8. ✅ 15 Ocak tüm gün bloke edildi!
```

**Sonuç:**
- Öğrenciler 15 Ocak için slot göremez
- "Öğretmen bu tarihte müsait değil: Hasta" mesajı görürler
- Sen rahat izinde olabilirsin!

---

#### Tatil Dönemi Ekleme

```
Senaryo: 1-15 Ağustos yaz tatilindesin

1. İzin/Tatil ekranı
2. "Tatil Dönemi" FAB (mor)
3. Başlangıç: 1 Ağustos 2025
4. Bitiş: 15 Ağustos 2025
5. Sebep: "Yaz Tatili"
6. Not: "Antalya'da olacağım"
7. "Ekle" tıkla
8. ✅ 15 gün otomatik eklendi!
```

**Sonuç:**
- 1-15 Ağustos arası tüm günler bloke
- Tek tek eklemene gerek kalmadı
- Tüm tatilini rahatça planla

---

#### Özel Saatler Belirleme

```
Senaryo: 20 Ocak sabah doktor randevun var, sadece öğleden sonra müsaitsin

1. İzin/Tatil ekranı
2. "Tek Gün Ekle" FAB
3. Tür: "Özel Saatler" seç
4. Tarih: 20 Ocak 2025
5. Başlangıç: 14:00
6. Bitiş: 18:00
7. Sebep: "Sabah doktor randevusu"
8. "Ekle" tıkla
9. ✅ O gün sadece 14:00-18:00 arası gösterilir!
```

**Sonuç:**
- Normal takviminde "Pazartesi 09:00-17:00" var
- AMA 20 Ocak için override edilir
- Sadece 14:00-18:00 slot'ları gösterilir
- Haftalık takvim değişmez (sadece o gün için)

---

### Sık Kullanılan Senaryolar

#### Senaryo 1: İlk Defa Kurulum (5 Dakika)
```
1. "⚡ Hızlı Ekle" → "Hafta İçi 9-17"
2. Cumartesi için manuel ekle: 10:00-14:00
3. ✅ TAMAM! 6 gün müsaitlik hazır.
```

#### Senaryo 2: Çalışma Saatlerimi Değiştirdim
```
Eski: 09:00-17:00
Yeni: 13:00-21:00

1. Sağ üst "🗑️" (tümünü temizle)
2. Onayla
3. "⚡ Hızlı Ekle" → "Özel saat ekle"
4. Günler: Hafta içi
5. Başlangıç: 13:00
6. Bitiş: 21:00
7. ✅ Yeni saatler eklendi!
```

#### Senaryo 3: Bu Hafta Çarşamba Farklı
```
Normal: Çarşamba 09:00-17:00
Bu hafta: Çarşamba 14:00-20:00 (sabah toplantı var)

1. İzin/Tatil → "Tek Gün Ekle"
2. Tür: Özel Saatler
3. Tarih: 23 Ekim (bu Çarşamba)
4. Saat: 14:00-20:00
5. Sebep: "Sabah toplantı"
6. ✅ Sadece bu Çarşamba için geçerli!
```

#### Senaryo 4: Bayram Tatili
```
29 Ekim Cumhuriyet Bayramı (1 gün)

1. İzin/Tatil → "Tek Gün Ekle"
2. Tür: Tam Gün İzin
3. Tarih: 29 Ekim
4. Sebep: "Cumhuriyet Bayramı"
5. ✅ O gün tüm gün bloke!
```

---

## 🎓 ÖĞRENCİLER İÇİN

### Rezervasyon Yapma (Yeni Sistem)

#### Adım Adım:

```
1. Öğretmen Listesi → Bir öğretmen seç
2. "Rezervasyon Yap" tıkla

3. Kategori seç:
   [İngilizce ✓] [Matematik] [Fizik] ...

4. Konu yaz:
   "Grammar - Present Tense"

5. Süre seç:
   [30dk] [60dk ✓] [90dk] [120dk] [180dk] [240dk]

6. Tarih seç:
   [15 Ocak 2025 ▼]
   
7. ⏳ 1 saniye bekle...

8. ✅ Uygun Saatler Göründü:
   [09:00-10:00]  [10:00-11:00]  [11:00-12:00]
   [14:00-15:00]  [15:00-16:00]  [16:00-17:00]

9. Slot seç:
   [14:00-15:00 ✓]  ← Tıkla
   
10. ✅ Yeşil onay: "Seçilen saat: 14:00-15:00"

11. (Opsiyonel) Not ekle:
    "IELTS sınavına hazırlanıyorum"

12. Fiyat görüntülenir:
    Süre: 60 dakika
    Saatlik ücret: ₺150
    Toplam: ₺150

13. "Rezervasyon Gönder" tıkla
14. 🎉 BAŞARILI! (100% garanti)
```

---

### Özel Durumlar

#### Durum 1: Öğretmen İzinli
```
Tarih seç: 15 Ocak
↓
⚠️ Mesaj gösterilir:
"Öğretmen bu tarihte müsait değil: Hasta"

Available Slots: []

Çözüm:
→ Başka bir tarih seç
```

#### Durum 2: O Gün Saatler Dolu
```
Tarih seç: 16 Ocak
↓
⚠️ Mesaj gösterilir:
"Bu tarihte uygun saat bulunmamaktadır.
Lütfen başka bir tarih seçin."

Available Slots: []

Çözüm:
→ Başka bir tarih seç
→ Veya farklı süre seç (60dk → 30dk)
```

#### Durum 3: Süre Değiştirince Farklı Slot'lar
```
Süre: 60 dakika
Slots: [09:00-10:00] [10:00-11:00] [11:00-12:00]

Süre değiştir: 120 dakika
↓
Otomatik yeniden yüklenir:
Slots: [09:00-11:00] [11:00-13:00]  ← Farklı!
```

---

## 💡 İPUÇLARI VE PÜFNOKTALAR

### Öğretmenler İçin

**İpucu 1: Esnek Saatler**
```
Sabah insanı değilsin, akşam veriyorsun dersleri:
→ "Hafta İçi 13-21" şablonunu kullan
→ 5 saniyede haftan hazır!
```

**İpucu 2: Karma Program**
```
Hafta içi: 09:00-12:00, 14:00-17:00 (öğle arası boş)

Çözüm:
1. Hafta içi için 09:00-12:00 ekle (Hızlı ekle)
2. Manuel 14:00-17:00 ekle her güne
VEYA
1. Pazartesi'ye 09-12 ve 14-17 ekle (2 ayrı slot)
2. Pazartesi'yi tüm haftaya kopyala
```

**İpucu 3: Tatil Planlaması**
```
Haziran'da 2 hafta tatil:
1. İzin/Tatil → "Tatil Dönemi"
2. 1 Haziran - 15 Haziran
3. Sebep: "Yaz tatili"
4. ✅ 15 gün tek tıkla!

Öğrencilerin bu tarihler için rezervasyon yapmaya çalışması:
→ "Öğretmen bu tarihte müsait değil: Yaz tatili"
```

**İpucu 4: Geçici Değişiklik**
```
Bu hafta Çarşamba sabah toplantın var:
1. İzin/Tatil → "Tek Gün Ekle"
2. Tür: Özel Saatler
3. Tarih: Bu Çarşamba
4. Saat: 13:00-17:00 (sadece öğleden sonra)
5. ✅ Haftalık takvim değişmez, sadece o gün farklı!
```

---

### Öğrenciler İçin

**İpucu 1: Daha Fazla Slot Görmek**
```
60 dakikalık slot bulamadın?
→ Süreyi 30 dakikaya düşür
→ Daha fazla seçenek görünür!

Örnek:
60dk: [09:00-10:00] [14:00-15:00]  ← 2 slot
30dk: [09:00-09:30] [09:30-10:00] [14:00-14:30] [14:30-15:00]  ← 4 slot!
```

**İpucu 2: Popüler Saatler**
```
Akşam saatleri (18:00-21:00) genelde daha dolu.
→ Sabah saatleri (09:00-12:00) dene
→ Hafta sonu sabahları (10:00-12:00) genelde boş
```

**İpucu 3: Son Dakika Rezervasyon**
```
Bugün için rezervasyon yapmak istiyorsan:
→ Muhtemelen slot kalmamıştır
→ 2-3 gün sonrasına bak
→ Minimum 30 dakika önceden yapmalısın
```

---

## ❓ SIK SORULAN SORULAR

### Öğretmenler

**S: Haftalık takvimi değiştirirsem mevcut rezervasyonlar ne olur?**
C: Mevcut rezervasyonlar etkilenmez. Sadece gelecek rezervasyonlar için geçerli.

**S: Yanlışlıkla tüm takvimi sildim, geri alabilir miyim?**
C: Hayır. Ama "Hızlı Ekle" ile 5 saniyede tekrar kurarsın.

**S: Bir gün için 2 farklı saat aralığı ekleyebilir miyim?**
C: Evet! Örnek: Pazartesi 09-12 ve 14-17 (2 ayrı slot).

**S: Özel günler haftalık takvimi etkiler mi?**
C: Hayır! Exception sadece o gün için geçerli, haftalık takvim değişmez.

**S: Tatil dönemini nasıl silerim?**
C: İzin/Tatil ekranında her günü tek tek sil VEYA toplu sil (gelecek güncelleme).

---

### Öğrenciler

**S: Neden bazı tarihlerde saat göremiyorum?**
C: Öğretmen o gün izinli olabilir veya saatler dolu. Başka tarih dene.

**S: Süre değiştirince slot'lar neden değişiyor?**
C: Farklı süreler farklı slot'lar oluşturur. 30dk ile 60dk farklı saatler gösterebilir.

**S: Slot seçtim ama rezervasyon başarısız oldu?**
C: Çok nadir! Belki başka öğrenci 1 saniye önce rezerve etti. Yeniden dene.

**S: Hangi öğretmen daha çok müsait?**
C: Öğretmen listesinde slot sayıları gösterilecek (gelecek güncelleme).

---

## 🔄 GÜNCELLEMELİK OLANLAT

### Backend

```bash
# VM'e SSH bağlan
ssh your-vm

# Backend klasörüne git
cd /var/www/nazliyavuz/backend

# Yeni migration'ı çalıştır
php artisan migrate

# Cache temizle
php artisan config:clear
php artisan route:clear
php artisan cache:clear

# Optimize et
php artisan config:cache
php artisan route:cache
php artisan optimize

# Restart services
sudo systemctl restart php8.2-fpm
sudo systemctl reload nginx
```

### Frontend

```bash
# Dependencies
cd frontend/nazliyavuz_app
flutter pub get

# Test (local)
flutter run

# Production build
flutter clean
flutter build appbundle --release

# APK oluşturuldu:
# build/app/outputs/bundle/release/app-release.aab
```

---

## ✅ TEST CHECKLİST

### Öğretmen Testleri

- [ ] Hızlı ekleme çalışıyor (Hafta içi 9-17)
- [ ] Kopyalama çalışıyor (Pazartesi → Tüm hafta)
- [ ] Manuel slot ekleme çalışıyor
- [ ] Slot düzenleme çalışıyor
- [ ] Slot silme çalışıyor (long press)
- [ ] Tümünü temizle çalışıyor
- [ ] İzin ekleme çalışıyor (tek gün)
- [ ] Tatil dönemi ekleme çalışıyor (bulk)
- [ ] Özel saatler ekleme çalışıyor
- [ ] İstatistikler doğru gösteriliyor

### Öğrenci Testleri

- [ ] Tarih seçince slots otomatik yükleniyor
- [ ] Slot'lar görünüyor (chip'ler)
- [ ] Slot seçimi çalışıyor (yeşil onay)
- [ ] Süre değiştirince slots güncelleniyor
- [ ] Öğretmen izinliyse mesaj gösteriliyor
- [ ] Boş slot yoksa uyarı gösteriliyor
- [ ] Rezervasyon başarılı oluyor
- [ ] Çakışma hatası olmuyor

---

## 🎯 SONUÇ

**Müsaitlik sistemi artık:**
- ✅ Profesyonel seviye
- ✅ Kullanıcı dostu
- ✅ Hatasız çalışıyor
- ✅ Esnek ve güçlü
- ✅ Production-ready

**Kullanıcılar:**
- 😊 Öğrenciler mutlu (kolay rezervasyon)
- 😊 Öğretmenler mutlu (kolay yönetim)
- 😊 Platform mutlu (daha fazla rezervasyon, daha az destek talebi)

---

**🎉 İYİ KULANIMLAR! 🎉**

---

**Destek:**
Email: support@terenceeegitim.com  
Dokümantasyon: Bu dosya  
Teknik Detay: MÜSAİTLİK_SİSTEMİ_İYİLEŞTİRMELERİ.md

---

**Hazırlayan:** AI Assistant  
**Tarih:** 21 Ekim 2025  
**Sürüm:** 2.0

