# Production Migration Strategy - Category Update

## 🚨 **KRİTİK UYARILAR**

### ⚠️ **ÖNEMLİ NOTLAR**
- Bu migration production'da **VERİ KAYBI** riski taşır
- **MUTLAKA BACKUP** alın
- **MAINTENANCE MODE** aktif edin
- **ROLLBACK PLANI** hazırlayın

## 📋 **MIGRATION ADIMLARI**

### **1. ÖN HAZIRLIK (Production Öncesi)**
```bash
# 1. Backup al
php artisan backup:run

# 2. Maintenance mode aktif et
php artisan down --message="Kategori güncellemesi yapılıyor"

# 3. Cache temizle
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
```

### **2. VERİTABANI MIGRATION'LARI**
```bash
# 1. Mevcut kategorileri yedekle
php artisan tinker --execute="
\$categories = App\Models\Category::all();
file_put_contents('backup_categories.json', json_encode(\$categories));
echo 'Categories backed up to backup_categories.json';
"

# 2. Teacher-Category ilişkilerini yedekle
php artisan tinker --execute="
\$relations = DB::table('teacher_category')->get();
file_put_contents('backup_teacher_category.json', json_encode(\$relations));
echo 'Teacher-Category relations backed up';
"

# 3. Kategorileri temizle
php artisan tinker --execute="
DB::table('teacher_category')->delete();
DB::table('categories')->delete();
echo 'Categories cleared';
"

# 4. Yeni kategorileri ekle
php artisan db:seed --class=CategorySeeder

# 5. Teacher-Category ilişkilerini yeniden kur
php artisan db:seed --class=UserSeeder
```

### **3. FRONTEND DEPLOYMENT**
```bash
# 1. Frontend cache'i temizle
flutter clean
flutter pub get

# 2. Build al
flutter build apk --release
flutter build web --release

# 3. Deploy et
# (Deployment stratejinize göre)
```

### **4. POST-DEPLOYMENT KONTROLLER**
```bash
# 1. API endpoint'leri test et
curl -X GET "https://your-api.com/api/v1/categories"
curl -X GET "https://your-api.com/api/v1/categories/fallback/san"

# 2. Veritabanı kontrolü
php artisan tinker --execute="
echo 'Ana Kategoriler: ' . App\Models\Category::whereNull('parent_id')->count();
echo 'Alt Kategoriler: ' . App\Models\Category::whereNotNull('parent_id')->count();
echo 'Teacher-Category İlişkileri: ' . DB::table('teacher_category')->count();
"

# 3. Maintenance mode kapat
php artisan up
```

## 🔄 **ROLLBACK PLANI**

### **Eğer Sorun Olursa:**
```bash
# 1. Maintenance mode aktif et
php artisan down --message="Rollback yapılıyor"

# 2. Veritabanını geri yükle
php artisan tinker --execute="
\$categories = json_decode(file_get_contents('backup_categories.json'), true);
foreach(\$categories as \$cat) {
    App\Models\Category::create(\$cat);
}
echo 'Categories restored';
"

# 3. Teacher-Category ilişkilerini geri yükle
php artisan tinker --execute="
\$relations = json_decode(file_get_contents('backup_teacher_category.json'), true);
foreach(\$relations as \$rel) {
    DB::table('teacher_category')->insert((array)\$rel);
}
echo 'Teacher-Category relations restored';
"

# 4. Maintenance mode kapat
php artisan up
```

## 📊 **MONITORING**

### **Kontrol Edilecekler:**
- [ ] API response times
- [ ] Error rates
- [ ] User complaints
- [ ] Search functionality
- [ ] Category filtering

### **Log Monitoring:**
```bash
# Error logları izle
tail -f storage/logs/laravel.log | grep -i "category\|error"

# API response times
tail -f storage/logs/laravel.log | grep -i "api"
```

## 🎯 **BAŞARI KRİTERLERİ**

- ✅ Tüm API endpoint'leri 200 döndürüyor
- ✅ Kategori filtreleme çalışıyor
- ✅ Teacher-Category ilişkileri doğru
- ✅ Frontend'de kategori listesi görünüyor
- ✅ Eski slug'lar fallback ile çalışıyor
- ✅ Error rate %1'in altında

## 📞 **ACİL DURUM KONTACT**

- **Backend Developer:** [İletişim bilgisi]
- **DevOps Engineer:** [İletişim bilgisi]
- **Project Manager:** [İletişim bilgisi]

## 📝 **NOTLAR**

- Migration süresi: ~30 dakika
- Downtime: ~15 dakika
- Risk seviyesi: **YÜKSEK**
- Rollback süresi: ~10 dakika

---

**⚠️ Bu migration'ı production'da çalıştırmadan önce staging environment'ta test edin!**
