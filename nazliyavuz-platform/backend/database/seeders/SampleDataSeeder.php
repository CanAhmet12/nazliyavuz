<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Teacher;
use App\Models\Category;
use App\Models\Reservation;
use App\Models\Rating;
use App\Models\Notification;
use Illuminate\Support\Facades\Hash;

class SampleDataSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Create sample users
        $this->createSampleUsers();
        
        // Create sample teachers
        $this->createSampleTeachers();
        
        // Create sample reservations
        $this->createSampleReservations();
        
        // Create sample ratings
        $this->createSampleRatings();
        
        // Create sample notifications
        $this->createSampleNotifications();
    }

    private function createSampleUsers()
    {
        $users = [
            [
                'name' => 'Ahmet Yılmaz (Sample)',
                'email' => 'ahmet.sample2@example.com',
                'password' => Hash::make('password123'),
                'role' => 'teacher',
                'email_verified_at' => now(),
                'profile_photo_url' => null,
            ],
            [
                'name' => 'Sarah Johnson',
                'email' => 'sarah.sample2@example.com',
                'password' => Hash::make('password123'),
                'role' => 'teacher',
                'email_verified_at' => now(),
                'profile_photo_url' => null,
            ],
            [
                'name' => 'Mehmet Kaya (Sample)',
                'email' => 'mehmet.sample2@example.com',
                'password' => Hash::make('password123'),
                'role' => 'teacher',
                'email_verified_at' => now(),
                'profile_photo_url' => null,
            ],
            [
                'name' => 'Ayşe Demir (Sample)',
                'email' => 'ayse.sample2@example.com',
                'password' => Hash::make('password123'),
                'role' => 'teacher',
                'email_verified_at' => now(),
                'profile_photo_url' => null,
            ],
            [
                'name' => 'Emre Özkan (Sample)',
                'email' => 'emre.sample2@example.com',
                'password' => Hash::make('password123'),
                'role' => 'teacher',
                'email_verified_at' => now(),
                'profile_photo_url' => null,
            ],
            [
                'name' => 'Zeynep Kaya (Sample)',
                'email' => 'zeynep.sample2@example.com',
                'password' => Hash::make('password123'),
                'role' => 'student',
                'email_verified_at' => now(),
                'profile_photo_url' => null,
            ],
            [
                'name' => 'Ali Veli (Sample)',
                'email' => 'ali.sample2@example.com',
                'password' => Hash::make('password123'),
                'role' => 'student',
                'email_verified_at' => now(),
                'profile_photo_url' => null,
            ],
            [
                'name' => 'Fatma Şahin (Sample)',
                'email' => 'fatma.sample2@example.com',
                'password' => Hash::make('password123'),
                'role' => 'student',
                'email_verified_at' => now(),
                'profile_photo_url' => null,
            ],
        ];

        foreach ($users as $userData) {
            User::create($userData);
        }
    }

    private function createSampleCategories()
    {
        $categories = [
            [
                'name' => 'Matematik',
                'slug' => 'matematik',
                'description' => 'Matematik dersleri ve konuları',
                'icon' => 'calculate',
                'is_active' => true,
            ],
            [
                'name' => 'İngilizce',
                'slug' => 'ingilizce',
                'description' => 'İngilizce dil öğrenimi',
                'icon' => 'language',
                'is_active' => true,
            ],
            [
                'name' => 'Fizik',
                'slug' => 'fizik',
                'description' => 'Fizik dersleri ve konuları',
                'icon' => 'science',
                'is_active' => true,
            ],
            [
                'name' => 'Kimya',
                'slug' => 'kimya',
                'description' => 'Kimya dersleri ve konuları',
                'icon' => 'biotech',
                'is_active' => true,
            ],
            [
                'name' => 'Biyoloji',
                'slug' => 'biyoloji',
                'description' => 'Biyoloji dersleri ve konuları',
                'icon' => 'eco',
                'is_active' => true,
            ],
        ];

        foreach ($categories as $categoryData) {
            Category::create($categoryData);
        }
    }

    private function createSampleTeachers()
    {
        $teachers = [
            [
                'user_id' => 1,
                'bio' => '8 yıllık deneyime sahip matematik öğretmeni. Öğrencilerimin başarısı benim için en önemli şey.',
                'education' => ['İstanbul Üniversitesi Matematik Bölümü', 'Yüksek Lisans'],
                'certifications' => ['Pedagojik Formasyon', 'Matematik Öğretmenliği'],
                'price_hour' => 50.0,
                'languages' => ['Türkçe', 'İngilizce'],
                'online_available' => true,
                'is_approved' => true,
                'rating_avg' => 4.8,
                'rating_count' => 25,
            ],
            [
                'user_id' => 2,
                'bio' => 'Native English speaker with 5 years of teaching experience. I love helping students improve their English.',
                'education' => ['Oxford University English Literature', 'TEFL Certificate'],
                'certifications' => ['TEFL', 'IELTS Examiner'],
                'price_hour' => 45.0,
                'languages' => ['İngilizce', 'Türkçe'],
                'online_available' => true,
                'is_approved' => true,
                'rating_avg' => 4.9,
                'rating_count' => 30,
            ],
            [
                'user_id' => 3,
                'bio' => '12 yıllık deneyime sahip fizik öğretmeni. Fiziği sevdirmek için çeşitli yöntemler kullanıyorum.',
                'education' => ['Boğaziçi Üniversitesi Fizik Bölümü', 'Doktora'],
                'certifications' => ['Fizik Öğretmenliği', 'Araştırma Metodları'],
                'price_hour' => 60.0,
                'languages' => ['Türkçe', 'İngilizce'],
                'online_available' => true,
                'is_approved' => true,
                'rating_avg' => 4.7,
                'rating_count' => 20,
            ],
            [
                'user_id' => 4,
                'bio' => 'Kimya alanında uzman, öğrencilerime kimyanın güzelliğini göstermeye çalışıyorum.',
                'education' => ['Hacettepe Üniversitesi Kimya Bölümü', 'Yüksek Lisans'],
                'certifications' => ['Kimya Öğretmenliği', 'Laboratuvar Güvenliği'],
                'price_hour' => 40.0,
                'languages' => ['Türkçe'],
                'online_available' => true,
                'is_approved' => true,
                'rating_avg' => 4.6,
                'rating_count' => 18,
            ],
            [
                'user_id' => 5,
                'bio' => 'Biyoloji öğretmeni olarak doğanın mucizelerini öğrencilerime aktarmaya çalışıyorum.',
                'education' => ['Ankara Üniversitesi Biyoloji Bölümü', 'Yüksek Lisans'],
                'certifications' => ['Biyoloji Öğretmenliği', 'Çevre Bilimleri'],
                'price_hour' => 55.0,
                'languages' => ['Türkçe', 'İngilizce'],
                'online_available' => true,
                'is_approved' => true,
                'rating_avg' => 4.8,
                'rating_count' => 22,
            ],
        ];

        foreach ($teachers as $teacherData) {
            $teacher = Teacher::create($teacherData);
            
            // Attach categories to teachers
            $categories = Category::whereIn('name', ['Matematik', 'İngilizce', 'Fizik', 'Kimya', 'Biyoloji'])->get();
            $teacher->categories()->attach($categories->pluck('id'));
        }
    }

    private function createSampleReservations()
    {
        $reservations = [
            [
                'student_id' => 6,
                'teacher_id' => 1,
                'category_id' => 1,
                'subject' => 'Matematik',
                'proposed_datetime' => now()->addDays(1)->setTime(14, 0),
                'duration_minutes' => 60,
                'status' => 'accepted',
                'price' => 50.0,
                'notes' => 'Matematik dersi için rezervasyon',
            ],
            [
                'student_id' => 7,
                'teacher_id' => 2,
                'category_id' => 2,
                'subject' => 'İngilizce',
                'proposed_datetime' => now()->addDays(2)->setTime(16, 30),
                'duration_minutes' => 90,
                'status' => 'accepted',
                'price' => 45.0,
                'notes' => 'İngilizce konuşma pratiği',
            ],
            [
                'student_id' => 8,
                'teacher_id' => 3,
                'category_id' => 3,
                'subject' => 'Fizik',
                'proposed_datetime' => now()->addDays(3)->setTime(10, 0),
                'duration_minutes' => 60,
                'status' => 'pending',
                'price' => 60.0,
                'notes' => 'Fizik ödevi yardımı',
            ],
            [
                'student_id' => 6,
                'teacher_id' => 4,
                'category_id' => 4,
                'subject' => 'Kimya',
                'proposed_datetime' => now()->addDays(4)->setTime(15, 0),
                'duration_minutes' => 60,
                'status' => 'completed',
                'price' => 40.0,
                'notes' => 'Kimya dersi tamamlandı',
            ],
            [
                'student_id' => 7,
                'teacher_id' => 5,
                'category_id' => 5,
                'subject' => 'Biyoloji',
                'proposed_datetime' => now()->addDays(5)->setTime(11, 0),
                'duration_minutes' => 60,
                'status' => 'accepted',
                'price' => 55.0,
                'notes' => 'Biyoloji dersi',
            ],
        ];

        foreach ($reservations as $reservationData) {
            Reservation::create($reservationData);
        }
    }

    private function createSampleRatings()
    {
        $ratings = [
            [
                'student_id' => 6,
                'teacher_id' => 1,
                'reservation_id' => 1,
                'rating' => 5,
            ],
            [
                'student_id' => 7,
                'teacher_id' => 2,
                'reservation_id' => 2,
                'rating' => 5,
            ],
            [
                'student_id' => 8,
                'teacher_id' => 3,
                'reservation_id' => 3,
                'rating' => 4,
            ],
            [
                'student_id' => 6,
                'teacher_id' => 4,
                'reservation_id' => 4,
                'rating' => 5,
            ],
            [
                'student_id' => 7,
                'teacher_id' => 5,
                'reservation_id' => 5,
                'rating' => 4,
                
            ],
        ];

        foreach ($ratings as $ratingData) {
            Rating::create($ratingData);
        }
    }

    private function createSampleNotifications()
    {
        $notifications = [
            [
                'user_id' => 6,
                'type' => 'reservation_confirmed',
                'payload' => json_encode([
                    'title' => 'Rezervasyon Onaylandı',
                    'message' => 'Matematik dersi rezervasyonunuz onaylandı.',
                    'reservation_id' => 1
                ]),
                'read_at' => null,
            ],
            [
                'user_id' => 7,
                'type' => 'new_message',
                'payload' => json_encode([
                    'title' => 'Yeni Mesaj',
                    'message' => 'Sarah Johnson size mesaj gönderdi.',
                    'teacher_id' => 2
                ]),
                'read_at' => null,
            ],
            [
                'user_id' => 8,
                'type' => 'reservation_reminder',
                'payload' => json_encode([
                    'title' => 'Rezervasyon Hatırlatması',
                    'message' => 'Yarın saat 10:00\'da fizik dersiniz var.',
                    'reservation_id' => 3
                ]),
                'read_at' => null,
            ],
        ];

        foreach ($notifications as $notificationData) {
            Notification::create($notificationData);
        }
    }
}
