<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Teacher;
use App\Models\Category;
use App\Models\Reservation;
use App\Models\Lesson;
use App\Models\Rating;
use App\Models\Assignment;
use App\Models\Payment;
use App\Models\Chat;
use App\Models\Message;
use App\Models\Notification;
use App\Models\SharedFile;
use App\Models\TeacherAvailability;
use App\Models\TeacherCertification;
use Illuminate\Support\Facades\Hash;
use Carbon\Carbon;

class ComprehensiveDataSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $this->command->info('🚀 Starting comprehensive data seeding...');

        // 1. Create Categories (Hierarchical)
        $this->createCategories();
        
        // 2. Create Users (Students, Teachers, Admin)
        $users = $this->createUsers();
        
        // 3. Create Teachers with detailed profiles
        $teachers = $this->createTeachers($users['teachers']);
        
        // 4. Create Teacher-Category relationships
        $this->createTeacherCategories($teachers);
        
        // 5. Create Teacher Availabilities
        $this->createTeacherAvailabilities($teachers);
        
        // 6. Create Teacher Certifications
        $this->createTeacherCertifications($teachers);
        
        // 7. Create Reservations
        $reservations = $this->createReservations($users['students'], $teachers);
        
        // 8. Create Lessons
        $lessons = $this->createLessons($reservations);
        
        // 9. Create Ratings
        $this->createRatings($lessons);
        
        // 10. Create Assignments
        $this->createAssignments($teachers, $users['students'], $reservations);
        
        // 11. Create Payments
        $this->createPayments($reservations);
        
        // 12. Create Chats and Messages
        $this->createChatsAndMessages($users['students'], $teachers);
        
        // 13. Create Notifications
        $this->createNotifications($users['students'], $teachers);
        
        // 14. Create Shared Files
        $this->createSharedFiles($teachers, $users['students']);
        
        $this->command->info('✅ Comprehensive data seeding completed!');
        $this->command->info('📊 Created:');
        $this->command->info('   - ' . User::count() . ' Users');
        $this->command->info('   - ' . Teacher::count() . ' Teachers');
        $this->command->info('   - ' . Category::count() . ' Categories');
        $this->command->info('   - ' . Reservation::count() . ' Reservations');
        $this->command->info('   - ' . Lesson::count() . ' Lessons');
        $this->command->info('   - ' . Rating::count() . ' Ratings');
        $this->command->info('   - ' . Assignment::count() . ' Assignments');
        $this->command->info('   - ' . Payment::count() . ' Payments');
        $this->command->info('   - ' . Chat::count() . ' Chats');
        $this->command->info('   - ' . Message::count() . ' Messages');
        $this->command->info('   - ' . Notification::count() . ' Notifications');
        $this->command->info('   - ' . SharedFile::count() . ' Shared Files');
    }

    private function createCategories()
    {
        $this->command->info('📚 Creating categories...');
        
        $categories = [
            // Ana Kategoriler
            ['name' => 'Okul Dersleri', 'slug' => 'okul-dersleri', 'description' => 'İlkokul, ortaokul ve lise dersleri', 'icon' => 'school'],
            ['name' => 'Yabancı Dil', 'slug' => 'yabanci-dil', 'description' => 'İngilizce, Almanca, Fransızca ve diğer diller', 'icon' => 'language'],
            ['name' => 'Sanat ve Tasarım', 'slug' => 'sanat-ve-tasarim', 'description' => 'Resim, müzik, grafik tasarım', 'icon' => 'palette'],
            ['name' => 'Bilgisayar ve Teknoloji', 'slug' => 'bilgisayar-ve-teknoloji', 'description' => 'Programlama, web tasarım, yazılım', 'icon' => 'computer'],
            ['name' => 'Spor ve Fitness', 'slug' => 'spor-ve-fitness', 'description' => 'Futbol, basketbol, fitness, yoga', 'icon' => 'fitness_center'],
            ['name' => 'Müzik', 'slug' => 'muzik', 'description' => 'Piyano, gitar, keman, şan', 'icon' => 'music_note'],
            ['name' => 'Kişisel Gelişim', 'slug' => 'kisisel-gelisim', 'description' => 'Liderlik, iletişim, motivasyon', 'icon' => 'psychology'],
            ['name' => 'Mesleki Eğitim', 'slug' => 'mesleki-egitim', 'description' => 'İş dünyası, girişimcilik, finans', 'icon' => 'business'],
        ];

        $createdCategories = [];
        foreach ($categories as $categoryData) {
            $category = Category::create([
                'name' => $categoryData['name'],
                'slug' => $categoryData['slug'],
                'description' => $categoryData['description'],
                'icon' => $categoryData['icon'],
                'is_active' => true,
                'sort_order' => rand(1, 10),
            ]);
            $createdCategories[] = $category;
        }

        // Alt kategoriler oluştur
        $subCategories = [
            // Okul Dersleri alt kategorileri
            ['parent' => 'okul-dersleri', 'name' => 'Matematik', 'slug' => 'matematik'],
            ['parent' => 'okul-dersleri', 'name' => 'Türkçe', 'slug' => 'turkce'],
            ['parent' => 'okul-dersleri', 'name' => 'Fen Bilimleri', 'slug' => 'fen-bilimleri'],
            ['parent' => 'okul-dersleri', 'name' => 'Sosyal Bilgiler', 'slug' => 'sosyal-bilgiler'],
            ['parent' => 'okul-dersleri', 'name' => 'İngilizce', 'slug' => 'ingilizce'],
            ['parent' => 'okul-dersleri', 'name' => 'Tarih', 'slug' => 'tarih'],
            ['parent' => 'okul-dersleri', 'name' => 'Coğrafya', 'slug' => 'cografya'],
            ['parent' => 'okul-dersleri', 'name' => 'Fizik', 'slug' => 'fizik'],
            ['parent' => 'okul-dersleri', 'name' => 'Kimya', 'slug' => 'kimya'],
            ['parent' => 'okul-dersleri', 'name' => 'Biyoloji', 'slug' => 'biyoloji'],

            // Yabancı Dil alt kategorileri
            ['parent' => 'yabanci-dil', 'name' => 'İngilizce Dil', 'slug' => 'ingilizce-dil'],
            ['parent' => 'yabanci-dil', 'name' => 'Almanca', 'slug' => 'almanca'],
            ['parent' => 'yabanci-dil', 'name' => 'Fransızca', 'slug' => 'fransizca'],
            ['parent' => 'yabanci-dil', 'name' => 'İspanyolca', 'slug' => 'ispanyolca'],
            ['parent' => 'yabanci-dil', 'name' => 'Arapça', 'slug' => 'arapca'],

            // Sanat ve Tasarım alt kategorileri
            ['parent' => 'sanat-ve-tasarim', 'name' => 'Resim', 'slug' => 'resim'],
            ['parent' => 'sanat-ve-tasarim', 'name' => 'Grafik Tasarım', 'slug' => 'grafik-tasarim'],
            ['parent' => 'sanat-ve-tasarim', 'name' => 'İllüstrasyon', 'slug' => 'illustrasyon'],
            ['parent' => 'sanat-ve-tasarim', 'name' => 'Fotoğrafçılık', 'slug' => 'fotografcilik'],

            // Bilgisayar ve Teknoloji alt kategorileri
            ['parent' => 'bilgisayar-ve-teknoloji', 'name' => 'Programlama', 'slug' => 'programlama'],
            ['parent' => 'bilgisayar-ve-teknoloji', 'name' => 'Web Tasarım', 'slug' => 'web-tasarim'],
            ['parent' => 'bilgisayar-ve-teknoloji', 'name' => 'Mobil Uygulama', 'slug' => 'mobil-uygulama'],
            ['parent' => 'bilgisayar-ve-teknoloji', 'name' => 'Veri Analizi', 'slug' => 'veri-analizi'],
            ['parent' => 'bilgisayar-ve-teknoloji', 'name' => 'Siber Güvenlik', 'slug' => 'siber-guvenlik'],

            // Spor ve Fitness alt kategorileri
            ['parent' => 'spor-ve-fitness', 'name' => 'Futbol', 'slug' => 'futbol'],
            ['parent' => 'spor-ve-fitness', 'name' => 'Basketbol', 'slug' => 'basketbol'],
            ['parent' => 'spor-ve-fitness', 'name' => 'Fitness', 'slug' => 'fitness'],
            ['parent' => 'spor-ve-fitness', 'name' => 'Yoga', 'slug' => 'yoga'],
            ['parent' => 'spor-ve-fitness', 'name' => 'Yüzme', 'slug' => 'yuzme'],

            // Müzik alt kategorileri
            ['parent' => 'muzik', 'name' => 'Piyano', 'slug' => 'piyano'],
            ['parent' => 'muzik', 'name' => 'Gitar', 'slug' => 'gitar'],
            ['parent' => 'muzik', 'name' => 'Keman', 'slug' => 'keman'],
            ['parent' => 'muzik', 'name' => 'Şan', 'slug' => 'san'],
            ['parent' => 'muzik', 'name' => 'Bateri', 'slug' => 'bateri'],
        ];

        foreach ($subCategories as $subCategoryData) {
            $parentCategory = Category::where('slug', $subCategoryData['parent'])->first();
            if ($parentCategory) {
                Category::create([
                    'parent_id' => $parentCategory->id,
                    'name' => $subCategoryData['name'],
                    'slug' => $subCategoryData['slug'],
                    'description' => $subCategoryData['name'] . ' dersleri',
                    'is_active' => true,
                    'sort_order' => rand(1, 10),
                ]);
            }
        }

        $this->command->info('✅ Created ' . Category::count() . ' categories');
    }

    private function createUsers()
    {
        $this->command->info('👥 Creating users...');
        
        $users = [
            'students' => [],
            'teachers' => [],
            'admin' => null,
        ];

        // Admin user
        $admin = User::create([
            'name' => 'Admin User',
            'email' => 'admin@nazliyavuz.com',
            'password' => Hash::make('password'),
            'role' => 'admin',
            'email_verified_at' => now(),
            'verified_at' => now(),
        ]);
        $users['admin'] = $admin;

        // Student users (10 students)
        $studentNames = [
            'Ahmet Yılmaz', 'Ayşe Demir', 'Mehmet Kaya', 'Fatma Özkan', 'Ali Çelik',
            'Zeynep Arslan', 'Mustafa Şahin', 'Elif Yıldız', 'Burak Öztürk', 'Selin Kara'
        ];

        foreach ($studentNames as $index => $name) {
            $student = User::create([
                'name' => $name,
                'email' => 'student' . ($index + 1) . '@example.com',
                'password' => Hash::make('password'),
                'role' => 'student',
                'email_verified_at' => now(),
                'verified_at' => now(),
            ]);
            $users['students'][] = $student;
        }

        // Teacher users (15 teachers)
        $teacherNames = [
            'Dr. Emre Şahin', 'Prof. Ece Yıldız', 'Öğr. Gör. Can Özkan', 'Dr. Selin Kara',
            'Prof. Dr. Mehmet Demir', 'Öğr. Gör. Ayşe Kaya', 'Dr. Ali Yılmaz', 'Prof. Fatma Öztürk',
            'Dr. Zeynep Arslan', 'Öğr. Gör. Mustafa Çelik', 'Dr. Elif Şahin', 'Prof. Burak Yıldız',
            'Dr. Selen Kara', 'Öğr. Gör. Onur Demir', 'Prof. Dr. Nil Özkan'
        ];

        foreach ($teacherNames as $index => $name) {
            $teacher = User::create([
                'name' => $name,
                'email' => 'teacher' . ($index + 1) . '@example.com',
                'password' => Hash::make('password'),
                'role' => 'teacher',
                'email_verified_at' => now(),
                'verified_at' => now(),
                'teacher_status' => 'approved',
                'approved_at' => now(),
                'approved_by' => $admin->id,
            ]);
            $users['teachers'][] = $teacher;
        }

        $this->command->info('✅ Created ' . User::count() . ' users');
        return $users;
    }

    private function createTeachers($teacherUsers)
    {
        $this->command->info('👨‍🏫 Creating teacher profiles...');
        
        $teachers = [];
        $bios = [
            'Matematik alanında 10 yıllık deneyime sahip, öğrencilerimin başarısı için çalışıyorum.',
            'Fen bilimleri öğretmeni olarak laboratuvar deneyimlerimle öğrencilerime farklı bakış açıları kazandırıyorum.',
            'Yabancı dil öğretiminde iletişim odaklı yaklaşımım ile öğrencilerimin konuşma becerilerini geliştiriyorum.',
            'Sanat ve tasarım alanında yaratıcılığı destekleyen bir öğretmen olarak çalışıyorum.',
            'Bilgisayar programlama konusunda güncel teknolojileri takip ederek öğrencilerime aktarıyorum.',
            'Müzik eğitiminde teorik bilgiyi pratikle birleştirerek öğrencilerimin müzikal gelişimini destekliyorum.',
            'Spor eğitimi alanında sağlıklı yaşam bilincini aşılayan bir antrenör olarak çalışıyorum.',
            'Kişisel gelişim konusunda öğrencilerimin potansiyelini ortaya çıkarmaya odaklanıyorum.',
            'Mesleki eğitim alanında iş dünyasının ihtiyaçlarına uygun eğitim veriyorum.',
            'Özel eğitim alanında farklı öğrenme stillerine uygun yaklaşımlar geliştiriyorum.',
        ];

        $educations = [
            ['İstanbul Üniversitesi Matematik Bölümü', 'Boğaziçi Üniversitesi Yüksek Lisans'],
            ['ODTÜ Fizik Bölümü', 'MIT Doktora'],
            ['İTÜ Bilgisayar Mühendisliği', 'Stanford Üniversitesi Yüksek Lisans'],
            ['Mimar Sinan Güzel Sanatlar', 'Sorbonne Üniversitesi Sanat Tarihi'],
            ['Hacettepe Üniversitesi Müzik', 'Konservatuar Yüksek Lisans'],
        ];

        $certifications = [
            ['Microsoft Certified Trainer', 'Google Certified Educator'],
            ['IELTS Examiner', 'Cambridge English Teacher'],
            ['Adobe Certified Expert', 'Autodesk Certified Professional'],
            ['Yoga Alliance RYT 200', 'Pilates Mat Certification'],
            ['TEFL Certificate', 'CELTA Certificate'],
        ];

        $languages = [
            ['Türkçe', 'İngilizce', 'Almanca'],
            ['Türkçe', 'İngilizce', 'Fransızca'],
            ['Türkçe', 'İngilizce', 'İspanyolca'],
            ['Türkçe', 'İngilizce'],
            ['Türkçe', 'İngilizce', 'Arapça'],
        ];

        foreach ($teacherUsers as $index => $user) {
            $teacher = Teacher::create([
                'user_id' => $user->id,
                'bio' => $bios[$index % count($bios)],
                'education' => $educations[$index % count($educations)],
                'certifications' => $certifications[$index % count($certifications)],
                'price_hour' => rand(50, 300),
                'languages' => $languages[$index % count($languages)],
                'rating_avg' => rand(35, 50) / 10, // 3.5 - 5.0
                'rating_count' => rand(5, 50),
                'online_available' => rand(0, 1) == 1,
                'is_approved' => true,
                'approved_at' => now(),
                'approved_by' => 1, // Admin user
            ]);
            $teachers[] = $teacher;
        }

        $this->command->info('✅ Created ' . count($teachers) . ' teacher profiles');
        return $teachers;
    }

    private function createTeacherCategories($teachers)
    {
        $this->command->info('🔗 Creating teacher-category relationships...');
        
        $categories = Category::all();
        
        foreach ($teachers as $teacher) {
            // Her öğretmene 2-4 kategori ata
            $randomCategories = $categories->random(rand(2, 4));
            $teacher->categories()->attach($randomCategories->pluck('id'));
        }

        $this->command->info('✅ Created teacher-category relationships');
    }

    private function createTeacherAvailabilities($teachers)
    {
        $this->command->info('📅 Creating teacher availabilities...');
        
        $days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        $timeSlots = ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00'];
        
        foreach ($teachers as $teacher) {
            // Her öğretmen için 3-5 gün seç
            $availableDays = collect($days)->random(rand(3, 5));
            
            foreach ($availableDays as $day) {
                $startIndex = rand(0, count($timeSlots) - 3);
                $startTime = $timeSlots[$startIndex];
                $endIndex = min($startIndex + rand(1, 3), count($timeSlots) - 1);
                $endTime = $timeSlots[$endIndex];
                
                TeacherAvailability::create([
                    'teacher_id' => $teacher->user_id,
                    'day_of_week' => $day,
                    'start_time' => $startTime,
                    'end_time' => $endTime,
                    'is_available' => true,
                ]);
            }
        }

        $this->command->info('✅ Created teacher availabilities');
    }

    private function createTeacherCertifications($teachers)
    {
        $this->command->info('🏆 Creating teacher certifications...');
        
        $certifications = [
            'Microsoft Certified Trainer',
            'Google Certified Educator',
            'IELTS Examiner',
            'Cambridge English Teacher',
            'Adobe Certified Expert',
            'Autodesk Certified Professional',
            'Yoga Alliance RYT 200',
            'Pilates Mat Certification',
            'TEFL Certificate',
            'CELTA Certificate',
        ];
        
        foreach ($teachers as $teacher) {
            // Her öğretmen için 1-3 sertifika
            $randomCerts = collect($certifications)->random(rand(1, 3));
            
            foreach ($randomCerts as $cert) {
                TeacherCertification::create([
                    'teacher_id' => $teacher->user_id,
                    'certification_type' => 'certificate',
                    'institution' => 'Professional Organization',
                    'certificate_number' => 'CERT-' . rand(1000, 9999),
                    'issue_date' => now()->subMonths(rand(1, 24)),
                    'expiry_date' => now()->addYears(rand(1, 3)),
                    'status' => 'verified',
                    'verified_at' => now()->subMonths(rand(1, 12)),
                ]);
            }
        }

        $this->command->info('✅ Created teacher certifications');
    }

    private function createReservations($students, $teachers)
    {
        $this->command->info('📝 Creating reservations...');
        
        $reservations = [];
        $subjects = [
            'Matematik - Fonksiyonlar', 'Fizik - Mekanik', 'Kimya - Organik Kimya',
            'Biyoloji - Genetik', 'Türkçe - Edebiyat', 'Tarih - Osmanlı Tarihi',
            'Coğrafya - İklim', 'İngilizce - Grammar', 'Almanca - Konuşma',
            'Fransızca - Yazma', 'Resim - Portre', 'Müzik - Piyano',
            'Spor - Futbol', 'Programlama - Python', 'Web Tasarım - HTML/CSS'
        ];
        
        $statuses = ['pending', 'accepted', 'completed', 'cancelled'];
        $categories = Category::all();
        
        foreach ($students as $student) {
            // Her öğrenci için 3-8 rezervasyon
            $reservationCount = rand(3, 8);
            
            for ($i = 0; $i < $reservationCount; $i++) {
                $teacher = $teachers[rand(0, count($teachers) - 1)];
                $category = $categories->random();
                $status = $statuses[rand(0, count($statuses) - 1)];
                
                $proposedDate = now()->addDays(rand(-30, 30))->addHours(rand(9, 18));
                
                $reservation = Reservation::create([
                    'student_id' => $student->id,
                    'teacher_id' => $teacher->user_id,
                    'category_id' => $category->id,
                    'subject' => $subjects[rand(0, count($subjects) - 1)],
                    'proposed_datetime' => $proposedDate,
                    'duration_minutes' => [30, 45, 60, 90][rand(0, 3)],
                    'price' => $teacher->price_hour * ([30, 45, 60, 90][rand(0, 3)] / 60),
                    'status' => $status,
                    'notes' => 'Ders notları: ' . $subjects[rand(0, count($subjects) - 1)],
                    'teacher_notes' => $status === 'completed' ? 'Ders başarıyla tamamlandı.' : null,
                ]);
                
                $reservations[] = $reservation;
            }
        }

        $this->command->info('✅ Created ' . count($reservations) . ' reservations');
        return $reservations;
    }

    private function createLessons($reservations)
    {
        $this->command->info('📚 Creating lessons...');
        
        $lessons = [];
        $statuses = ['scheduled', 'in_progress', 'completed', 'cancelled'];
        
        foreach ($reservations as $reservation) {
            if (in_array($reservation->status, ['accepted', 'completed'])) {
                $status = $reservation->status === 'completed' ? 'completed' : $statuses[rand(0, 2)];
                
                $scheduledAt = $reservation->proposed_datetime;
                $startedAt = null;
                $endedAt = null;
                
                if (in_array($status, ['in_progress', 'completed'])) {
                    $startedAt = $scheduledAt->copy()->addMinutes(5);
                }
                
                if ($status === 'completed') {
                    $endedAt = $startedAt->copy()->addMinutes($reservation->duration_minutes);
                }
                
                $lesson = Lesson::create([
                    'reservation_id' => $reservation->id,
                    'teacher_id' => $reservation->teacher_id,
                    'student_id' => $reservation->student_id,
                    'scheduled_at' => $scheduledAt,
                    'started_at' => $startedAt,
                    'ended_at' => $endedAt,
                    'duration_minutes' => $reservation->duration_minutes,
                    'status' => $status,
                    'notes' => $status === 'completed' ? 'Ders başarıyla tamamlandı.' : null,
                    'rating' => $status === 'completed' ? rand(3, 5) : null,
                    'feedback' => $status === 'completed' ? 'Çok faydalı bir ders oldu.' : null,
                ]);
                
                $lessons[] = $lesson;
            }
        }

        $this->command->info('✅ Created ' . count($lessons) . ' lessons');
        return $lessons;
    }

    private function createRatings($lessons)
    {
        $this->command->info('⭐ Creating ratings...');
        
        $completedLessons = collect($lessons)->where('status', 'completed');
        
        foreach ($completedLessons as $lesson) {
            Rating::create([
                'student_id' => $lesson->student_id,
                'teacher_id' => $lesson->teacher_id,
                'reservation_id' => $lesson->reservation_id,
                'rating' => rand(3, 5),
                'review' => [
                    'Çok faydalı bir ders oldu.',
                    'Öğretmen çok sabırlı ve anlayışlı.',
                    'Ders çok verimli geçti.',
                    'Kesinlikle tavsiye ederim.',
                    'Çok profesyonel bir yaklaşım.',
                ][rand(0, 4)],
                'created_at' => $lesson->ended_at,
            ]);
        }

        $this->command->info('✅ Created ' . Rating::count() . ' ratings');
    }

    private function createAssignments($teachers, $students, $reservations)
    {
        $this->command->info('📋 Creating assignments...');
        
        $titles = [
            'Matematik Ödevi - Fonksiyonlar',
            'Fizik Projesi - Mekanik',
            'Kimya Deneyi - Asit-Baz',
            'Biyoloji Araştırması - Genetik',
            'Türkçe Kompozisyon',
            'Tarih Sunumu',
            'Coğrafya Harita Çalışması',
            'İngilizce Essay',
            'Resim Çalışması',
            'Müzik Performansı',
        ];
        
        $difficulties = ['easy', 'medium', 'hard'];
        $statuses = ['pending', 'submitted', 'graded'];
        
        foreach ($teachers as $teacher) {
            // Her öğretmen için 2-5 ödev
            $assignmentCount = rand(2, 5);
            
            for ($i = 0; $i < $assignmentCount; $i++) {
                $student = $students[rand(0, count($students) - 1)];
                $reservation = $reservations[rand(0, count($reservations) - 1)];
                $status = $statuses[rand(0, count($statuses) - 1)];
                
                $dueDate = now()->addDays(rand(1, 14));
                $submittedAt = null;
                $gradedAt = null;
                $grade = null;
                
                if (in_array($status, ['submitted', 'graded'])) {
                    $submittedAt = $dueDate->copy()->subDays(rand(0, 3));
                }
                
                if ($status === 'graded') {
                    $gradedAt = $submittedAt->copy()->addDays(rand(1, 3));
                    $grade = rand(60, 100);
                }
                
                Assignment::create([
                    'teacher_id' => $teacher->user_id,
                    'student_id' => $student->id,
                    'reservation_id' => $reservation->id,
                    'title' => $titles[rand(0, count($titles) - 1)],
                    'description' => 'Detaylı ödev açıklaması burada yer alır.',
                    'due_date' => $dueDate,
                    'difficulty' => $difficulties[rand(0, count($difficulties) - 1)],
                    'status' => $status,
                    'grade' => $grade,
                    'feedback' => $status === 'graded' ? 'Çok güzel bir çalışma olmuş.' : null,
                    'submission_notes' => $status !== 'pending' ? 'Ödev başarıyla teslim edildi.' : null,
                    'submitted_at' => $submittedAt,
                    'graded_at' => $gradedAt,
                ]);
            }
        }

        $this->command->info('✅ Created ' . Assignment::count() . ' assignments');
    }

    private function createPayments($reservations)
    {
        $this->command->info('💳 Creating payments...');
        
        $paymentMethods = ['credit_card', 'bank_transfer', 'paypal', 'stripe'];
        $statuses = ['pending', 'success', 'failed', 'cancelled'];
        
        foreach ($reservations as $reservation) {
            if (in_array($reservation->status, ['accepted', 'completed'])) {
                $status = $reservation->status === 'completed' ? 'success' : $statuses[rand(0, 2)];
                
                Payment::create([
                    'reservation_id' => $reservation->id,
                    'user_id' => $reservation->student_id,
                    'amount' => $reservation->price,
                    'currency' => 'TRY',
                    'paytr_order_id' => 'ORDER-' . rand(100000, 999999),
                    'payment_method' => $paymentMethods[rand(0, count($paymentMethods) - 1)],
                    'status' => $status,
                    'transaction_id' => 'TXN-' . rand(100000, 999999),
                    'paid_at' => $status === 'completed' ? $reservation->proposed_datetime->copy()->subDays(rand(1, 7)) : null,
                ]);
            }
        }

        $this->command->info('✅ Created ' . Payment::count() . ' payments');
    }

    private function createChatsAndMessages($students, $teachers)
    {
        $this->command->info('💬 Creating chats and messages...');
        
        $chats = [];
        
        // Her öğrenci-öğretmen çifti için chat oluştur
        foreach ($students as $student) {
            $randomTeachers = collect($teachers)->random(rand(2, 4));
            
            foreach ($randomTeachers as $teacher) {
                $chat = Chat::create([
                    'user1_id' => $student->id,
                    'user2_id' => $teacher->user_id,
                ]);
                
                $chats[] = $chat;
                
                // Her chat için 3-10 mesaj
                $messageCount = rand(3, 10);
                for ($i = 0; $i < $messageCount; $i++) {
                    $isFromStudent = rand(0, 1) == 1;
                    $senderId = $isFromStudent ? $student->id : $teacher->user_id;
                    
                    $messages = [
                        'Merhaba, ders hakkında sorularım var.',
                        'Teşekkürler, çok faydalı oldu.',
                        'Yarın ders var mı?',
                        'Ödevimi tamamladım.',
                        'Çok güzel anlattınız.',
                    ];
                    
                    Message::create([
                        'sender_id' => $senderId,
                        'receiver_id' => $isFromStudent ? $teacher->user_id : $student->id,
                        'content' => $messages[rand(0, 4)],
                        'message_type' => 'text',
                        'is_read' => rand(0, 1) == 1,
                        'created_at' => now()->subDays(rand(0, 30))->addHours(rand(0, 23)),
                    ]);
                }
            }
        }

        $this->command->info('✅ Created ' . Chat::count() . ' chats and ' . Message::count() . ' messages');
    }

    private function createNotifications($students, $teachers)
    {
        $this->command->info('🔔 Creating notifications...');
        
        $types = ['reservation_created', 'reservation_accepted', 'lesson_reminder', 'assignment_due', 'payment_received'];
        $titles = [
            'Yeni Rezervasyon',
            'Rezervasyon Onaylandı',
            'Ders Hatırlatması',
            'Ödev Teslim Tarihi',
            'Ödeme Alındı',
        ];
        
        $allUsers = array_merge($students, $teachers);
        $allUsers = array_filter($allUsers); // Remove null values
        
        foreach ($allUsers as $user) {
            if (!$user || !$user->id) {
                continue; // Skip null users
            }
            
            // Her kullanıcı için 5-15 bildirim
            $notificationCount = rand(5, 15);
            
            for ($i = 0; $i < $notificationCount; $i++) {
                $type = $types[rand(0, count($types) - 1)];
                $title = $titles[rand(0, count($titles) - 1)];
                
                Notification::create([
                    'user_id' => $user->id,
                    'type' => $type,
                    'payload' => json_encode([
                        'title' => $title,
                        'message' => $title . ' ile ilgili detaylar.',
                        'data' => 'sample_data'
                    ]),
                    'read_at' => rand(0, 1) == 1 ? now()->subDays(rand(0, 7)) : null,
                    'created_at' => now()->subDays(rand(0, 30)),
                ]);
            }
        }

        $this->command->info('✅ Created ' . Notification::count() . ' notifications');
    }

    private function createSharedFiles($teachers, $students)
    {
        $this->command->info('📁 Creating shared files...');
        
        $fileTypes = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'png', 'mp4', 'mp3'];
        $fileNames = [
            'ders-notlari.pdf', 'odev-ornegi.docx', 'sunum.pptx',
            'resim.jpg', 'video.mp4', 'ses-kaydi.mp3',
            'dokuman.pdf', 'tablo.xlsx', 'grafik.png'
        ];
        
        $allUsers = array_merge($students, $teachers);
        $allUsers = array_filter($allUsers); // Remove null values
        
        foreach ($allUsers as $user) {
            if (!$user || !$user->id) {
                continue; // Skip null users
            }
            
            // Her kullanıcı için 2-5 dosya
            $fileCount = rand(2, 5);
            
            for ($i = 0; $i < $fileCount; $i++) {
                $fileName = $fileNames[rand(0, count($fileNames) - 1)];
                $fileType = $fileTypes[rand(0, count($fileTypes) - 1)];
                
                SharedFile::create([
                    'teacher_id' => $user->role === 'teacher' ? $user->id : null,
                    'student_id' => $user->role === 'student' ? $user->id : null,
                    'name' => $fileName,
                    'file_path' => '/uploads/' . $fileName,
                    'file_size' => rand(100, 5000), // KB
                    'mime_type' => 'application/' . $fileType,
                    'category' => ['document', 'image', 'video', 'audio'][rand(0, 3)],
                    'description' => $fileName . ' dosyası',
                ]);
            }
        }

        $this->command->info('✅ Created ' . SharedFile::count() . ' shared files');
    }
}
