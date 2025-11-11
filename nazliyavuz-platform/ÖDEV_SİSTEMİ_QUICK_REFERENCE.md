# 📚 ÖDEV YÖNETİMİ - HIZLI REFERANS

**Son Güncelleme:** 21 Ekim 2025

---

## 🚀 HIZLI BAŞLANGIÇ

### Backend Commands

```bash
# Overdue ödevleri güncelle
php artisan assignments:update-overdue

# Hatırlatma gönder
php artisan assignments:send-reminders

# Route listesi
php artisan route:list --path=assignments

# Test
php artisan tinker
>>> Assignment::where('status', 'pending')->count()
```

---

## 📡 API ENDPOINTS (12 adet)

### GET Requests
```
GET /assignments                    → Tüm ödevler
GET /assignments/student            → Öğrenci ödevleri
GET /assignments/teacher            → Öğretmen ödevleri
GET /assignments/student/statistics → İstatistikler
GET /assignments/{id}/download      → Dosya indir
```

### POST Requests
```
POST /assignments                         → Yeni ödev
POST /assignments/{id}/submit             → Ödev teslim
POST /assignments/{id}/grade              → Notlandır
POST /assignments/{id}/request-resubmission → Tekrar teslim iste
POST /assignments/{id}/extend-deadline    → Son tarih uzat
```

### PUT/DELETE Requests
```
PUT    /assignments/{id}  → Ödev güncelle
DELETE /assignments/{id}  → Ödev sil
```

---

## 🎓 NOT SİSTEMİ

### Geçerli Notlar (13)
```
A+  A  A-
B+  B  B-
C+  C  C-
D+  D  D-
F
```

### GPA Karşılıkları
```
A+ = 4.0    B+ = 3.3    C+ = 2.3    D+ = 1.3
A  = 4.0    B  = 3.0    C  = 2.0    D  = 1.0
A- = 3.7    B- = 2.7    C- = 1.7    D- = 0.7
F  = 0.0
```

### Backend Kullanım
```php
use App\Rules\ValidGrade;

// Validation
'grade' => ['required', new ValidGrade()]

// Conversion
$numeric = ValidGrade::gradeToNumeric('A+');  // 4.0
$letter = ValidGrade::numericToGrade(3.5);    // 'A'
```

### Frontend Kullanım
```dart
// Geçerli notlar
final grades = apiService.getValidGrades();

// Dropdown
DropdownButton<String>(
    items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
)
```

---

## 📤 ÖDEV TESLİMİ

### Request
```php
POST /assignments/{id}/submit

FormData:
- submission_notes: string (optional)
- file: file (optional, max 10MB)

Allowed Files:
✅ PDF, DOC, DOCX
✅ TXT
✅ JPG, PNG
✅ ZIP, RAR
```

### Response
```json
{
    "success": true,
    "message": "Ödev başarıyla teslim edildi"
}
```

### Notifications
```
Öğrenciye: ✅ Teslim onayı
Öğretmene: ✅ "📤 Ödev Teslim Edildi"
```

---

## ⭐ NOTLANDIRMA

### Request
```php
POST /assignments/{id}/grade

{
    "grade": "A+",     // Required, must be valid
    "feedback": "..."  // Optional
}
```

### Validation
```
❌ "Z" → Invalid grade
❌ "100" → Invalid grade
❌ "AA" → Invalid grade
✅ "A+" → Valid
✅ "B" → Valid
```

### Notifications
```
Öğrenciye: ✅ "⭐ Ödev Notlandırıldı"
Email: ✅ (eğer enabled ise)
```

---

## 🔄 TEKRAR TESLİM

### Request
```php
POST /assignments/{id}/request-resubmission

{
    "feedback": "Lütfen kaynakları ekleyin",  // Required
    "new_due_date": "2025-11-05T23:59:59"    // Optional
}
```

### Sistem Değişiklikleri
```
status: submitted/graded → pending
grade: {value} → null
graded_at: {date} → null
feedback: append (history korunur)
due_date: update (if provided)
```

### Notification
```
Öğrenciye: "🔄 Tekrar Teslim İstendi"
Type: assignment
Force Push: true
Action: "Ödevi Görüntüle"
```

---

## ⏰ SON TARİH UZATMA

### Request
```php
POST /assignments/{id}/extend-deadline

{
    "new_due_date": "2025-11-10T23:59:59",  // Required
    "reason": "Öğrenci hasta"                // Optional
}
```

### Sistem Değişiklikleri
```
due_date: {old} → {new}
status: overdue → pending (if overdue)
feedback: append extension note
```

### Extension Note Format
```
[Son Tarih Uzatıldı: 01.11.2025 23:59 → 10.11.2025 23:59]
Sebep: Öğrenci hasta
```

---

## 📥 DOSYA İNDİRME

### Request
```php
GET /assignments/{id}/download

Authorization: Bearer {token}
```

### Authorization
```
✅ Ödev sahibi öğrenci
✅ Ödev oluşturan öğretmen
❌ Diğer kullanıcılar
```

### Response
```
Content-Type: application/pdf (or actual MIME)
Content-Disposition: attachment; filename="original_name.pdf"
Body: File binary data
```

---

## 📊 İSTATİSTİKLER

### Request
```php
GET /assignments/student/statistics

Authorization: Bearer {student_token}
```

### Response Fields
```json
{
    // Temel sayılar
    "total": int,
    "pending": int,
    "submitted": int,
    "graded": int,
    "overdue": int,
    
    // Oranlar (%)
    "completion_rate": float,
    "on_time_submission_rate": float,
    
    // Ortalamalar
    "average_grade_numeric": float,   // GPA
    "average_grade_letter": string,   // Letter
    
    // Analiz
    "difficulty_breakdown": {
        "easy|medium|hard": {
            "total": int,
            "completed": int,
            "average_grade": string
        }
    },
    
    // Trend (6 ay)
    "monthly_trend": {
        "YYYY-MM": {
            "month": string,
            "total": int,
            "completed": int,
            "average_grade": string
        }
    }
}
```

---

## ⏰ SCHEDULER

### Jobs

**1. Update Overdue:**
```
Command: assignments:update-overdue
Schedule: Every 5 minutes
Action: pending → overdue (if past due)
```

**2. Send Reminders:**
```
Command: assignments:send-reminders
Schedule: Daily at 09:00
Action: Notify students (2 days before)
```

### Manual Run
```bash
php artisan assignments:update-overdue
php artisan assignments:send-reminders
```

### Scheduler Status
```bash
# Laravel 10+
php artisan schedule:list

# Test
php artisan schedule:test
```

---

## 🔔 NOTIFICATIONS

### Tipleri (8)

| # | Tip | Alıcı | Tetikleyici |
|---|-----|-------|-------------|
| 1 | Created | Öğrenci | Ödev oluşturuldu |
| 2 | Submitted | Öğretmen | Ödev teslim edildi |
| 3 | Graded | Öğrenci | Ödev notlandı |
| 4 | Updated | Öğrenci | Ödev güncellendi |
| 5 | Deleted | Öğrenci | Ödev silindi |
| 6 | Resubmission | Öğrenci | Tekrar teslim istendi |
| 7 | Extension | Öğrenci | Son tarih uzatıldı |
| 8 | Reminder | Öğrenci | Hatırlatma (2 gün önce) |

### Channels
```
✅ In-app (database)
✅ Push (FCM)
✅ Email (important ones)
```

---

## 🐛 TROUBLESHOOTING

### Scheduler Çalışmıyor

```bash
# 1. Check crontab
crontab -l

# 2. Test manually
php artisan schedule:run

# 3. Check logs
tail -f storage/logs/laravel.log
```

### Cache Temizlenmiyor

```bash
# 1. Check observer
php artisan tinker
>>> App\Models\Assignment::getObservableEvents()

# 2. Clear manually
php artisan cache:clear

# 3. Check logs
grep "cache cleared" storage/logs/laravel.log
```

### Bildirim Gitmiyor

```bash
# 1. Check queue
php artisan queue:work

# 2. Check FCM tokens
SELECT fcm_token FROM users WHERE id = ?;

# 3. Check logs
grep "notification" storage/logs/laravel.log
```

### File Upload Başarısız

```bash
# 1. Check storage permissions
ls -la storage/app/public/assignments

# 2. Check file size limit (php.ini)
upload_max_filesize = 10M
post_max_size = 10M

# 3. Check MIME type
grep "MIME" storage/logs/laravel.log
```

---

## ✅ CHECKLIST

### Production Deployment

Backend:
- [x] Code deployed
- [x] Dependencies installed
- [x] Cache optimized
- [x] Observer registered
- [x] Commands registered
- [x] Scheduler configured
- [x] Queue worker running
- [ ] Tests run

Frontend:
- [x] API methods added
- [ ] UI screens updated (P2)
- [ ] Build created
- [ ] Deployed

Monitoring:
- [ ] Error tracking
- [ ] Performance monitoring
- [ ] Log aggregation
- [ ] Alerting setup

---

**Referans için bu dosyayı kullan! 📖**

