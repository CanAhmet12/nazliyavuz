# Proje Konusu

Bu uygulama, özel yetenek sınavlarına hazırlanan öğrencilerin işitsel algısını ve nota duyum yeteneğini geliştirmeye yönelik bir sistem olacak.
Uygulama kullanıcıya rastgele piyano sesleri (notalar) verecek, öğrenci bu sesi vokal olarak tekrar edecek, sistem ise bu sesi tuner (akort analizi) yardımıyla dinleyip doğru veya yanlış şeklinde anında geri bildirim verecek.

## Bu sayede öğrenci;

- Kulağını güçlendirecek,
- Nota duyumunu geliştirecek,
- Gerçek sınav koşullarına yakın şekilde alıştırma yapabilecek.

---

## Temel Özellikler

### Rastgele Nota Üretimi ve Çalma:
Uygulama piyano seslerini belirli bir aralıkta (örneğin C3 - B5) rastgele olarak çalar. Bu sesler ister MIDI tabanlı ister gerçek piyano kayıtlarından alınmış WAV/MP3 dosyaları şeklinde olabilir.

### Ses Kaydı ve Mikrofon Entegrasyonu:
Kullanıcı mikrofon üzerinden sesi tekrar eder. Sistem bu sesi alır, frekans analizini yapar.

### Gömülü Tuner Sistemi (Pitch Detection):
Yapay zekâ tabanlı tuner algoritması (örneğin autocorrelation veya FFT tabanlı analiz) ile öğrencinin söylediği sesin hangi nota olduğunu tespit eder. Bu, piyano sesinin frekansıyla karşılaştırılarak "doğru", "yarım ton düşük", "yarım ton yüksek" gibi detaylı geri bildirim verir.

### Doğruluk Geri Bildirimi:
Ekranda öğrenciye anında görsel bir dönüş yapılır. Örneğin:

- Doğru: Frekans eşleşmesi tam.
- Yakın: ±10 Hz aralıkta.
- Yanlış: Belirgin fark varsa.

### (Opsiyonel) Skor/Puanlama Sistemi:
Her doğru tekrarda puan verilir, yanlışlarda ise puan azalır. Bu sistem öğrencinin gelişimini ölçmesine yardımcı olur.

### (Opsiyonel) Egzersiz ve İstatistik Modu:
Belirli aralıklar, zorluk seviyeleri ve egzersiz oturumları oluşturularak öğrencinin hangi notalarda zorlandığı, hangi bölgelerde daha başarılı olduğu istatistiksel olarak gösterilebilir.

---

## Teknik Plan

| Aşama | Açıklama | Süre |
|-------|----------|------|
| 1. Seslerin Hazırlanması ve Nota Sistemi | Uygulamada kullanılacak piyano seslerinin seçimi, nota aralığının belirlenmesi ve veri yapısının oluşturulması. | 2 gün |
| 2. Rastgele Ses Çalma Modülü | Rastgele nota üretimi, ses çalma fonksiyonları ve kullanıcı arayüzünün hazırlanması. | 2 gün |
| 3. Mikrofon ve Tuner (Pitch Detection) Entegrasyonu | Kullanıcı sesini algılayan, analiz eden ve referans sesle karşılaştıran ana motorun geliştirilmesi. | 4 gün |
| 4. Geri Bildirim Sistemi | Doğru, yanlış, yakın gibi sonuçların anlık olarak ekranda gösterilmesi. | 2 gün |
| 5. Test ve Performans Optimizasyonu | Farklı cihazlarda ses gecikmesi, hassasiyet ve doğruluk oranlarının test edilmesi. | 2 gün |

**Toplam Süre:** Yaklaşık 12–14 gün  
**Platform:** Android (daha sonra isteğe bağlı olarak iOS uyumu yapılabilir)

---

## Teklif Aralığı

| Paket | İçerik | Fiyat (₺) |
|-------|--------|-----------|
| Temel Paket | Rastgele ses + tuner analizi + doğruluk bildirimi | 30.000 ₺ |
| Standart Paket | Temel özellikler + skor sistemi + kullanıcı profili | 42.000 ₺ |
| Profesyonel Paket | Standart özellikler + egzersiz modları + istatistiksel analiz | 55.000 ₺ |

- Tüm paketlerde 1 hafta ücretsiz teknik destek dahildir.
- Dilerseniz ilk etapta temel sürümü yapıp test ederiz, ardından sistemin doğruluğunu onayladığınızda ileri seviye modülleri ekleyebiliriz.

---

## Kısaca Uygulamanın İşleyişi

1. Uygulama piyanodan rastgele bir nota çalar.
2. Öğrenci mikrofonla bu sesi tekrar eder.
3. Sistem sesi analiz eder, tuner mantığında frekansı çıkarır.
4. Uygulama öğrencinin doğru mu yanlış mı söylediğini otomatik tespit eder.
5. Sonuç anında ekranda gösterilir (veya skor tablosuna eklenir).

Bu sayede öğrenciler kendi kendine sınav pratiği yapabilir,
siz de öğrencilerin ilerlemesini gözlemleyebilir, sistem üzerinden test modülleri oluşturabilirsiniz.