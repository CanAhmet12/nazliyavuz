<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Teacher;
use App\Models\Category;
use App\Models\Reservation;
use App\Models\Rating;
use App\Models\Notification;
use App\Models\Chat;
use App\Models\Message;
use App\Models\TeacherAvailability;
use App\Models\Lesson;

use Illuminate\Support\Facades\Hash;

class RealisticDataSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $this->createAdmin();
        $this->createTeachers();
        $this->createStudents();
        $this->createTeacherAvailabilities();
        $this->createReservations();
        $this->createLessons();
        $this->createRatings();
        $this->createChats();
        $this->createMessages();
        
        echo "✅ Gerçekçi veriler başarıyla oluşturuldu!\n";
    }

    private function createAdmin()
    {
        User::firstOrCreate(
            ['email' => 'admin@nazliyavuz.com'],
            [
                'name' => 'Admin User',
                'password' => Hash::make('password'),
                'role' => 'admin',
                'email_verified_at' => now(),
            ]
        );
        echo "✅ Admin kullanıcı oluşturuldu\n";
    }

    private function createTeachers()
    {
        $teachers = [
            [
                'name' => 'Dr. Ayşe Yılmaz',
                'email' => 'ayse.teacher@nazliyavuz.com',
                'price_hour' => 150.00,
                'bio' => '15 yıllık deneyime sahip matematik öğretmeni. Üniversite hazırlık ve okul sınavlarına öğrenci yetiştiriyorum.',
                'experience_years' => 15,
                'certifications' => json_encode(['Matematik Öğretmenliği', 'Pedagojik Formasyon', 'Eğitim Uzmanı']),
                'categories' => ['Matematik'],
            ],
            [
                'name' => 'Öğretmen Mehmet Kaya',
                'email' => 'mehmet.teacher@nazliyavuz.com',
                'price_hour' => 120.00,
                'bio' => '10 yıldır İngilizce eğitimi veriyorum. İş İngilizcesi ve genel İngilizce konusunda uzmanım.',
                'experience_years' => 10,
                'certifications' => json_encode(['İngilizce Öğretmenliği', 'CELTA Sertifikası']),
                'categories' => ['İngilizce'],
            ],
            [
                'name' => 'Öğr. Gör. Zeynep Demir',
                'email' => 'zeynep.teacher@nazliyavuz.com',
                'price_hour' => 200.00,
                'bio' => 'Konservatuvardan mezun, profesyonel müzik öğretmeni. Piyano ve solfej dersleri veriyorum.',
                'experience_years' => 8,
                'certifications' => json_encode(['Müzik Öğretmenliği', 'Piyano Uzmanlığı']),
                'categories' => ['Müzik'],
            ],
            [
                'name' => 'Dr. Can Özkan',
                'email' => 'can.teacher@nazliyavuz.com',
                'price_hour' => 180.00,
                'bio' => 'Fizik doktorası olan eğitmenim. Üniversite ve lise düzeyinde fizik dersleri veriyorum.',
                'experience_years' => 12,
                'certifications' => json_encode(['Fizik Doktorası', 'Pedagojik Formasyon']),
                'categories' => ['Fizik'],
            ],
        ];

        foreach ($teachers as $teacherData) {
            $user = User::firstOrCreate(
                ['email' => $teacherData['email']],
                [
                    'name' => $teacherData['name'],
                    'password' => Hash::make('password'),
                    'role' => 'teacher',
                    'email_verified_at' => now(),
                ]
            );

            if (!$user->teacher) {
                $teacher = Teacher::create([
                    'user_id' => $user->id,
                    'is_approved' => true,
                    'price_hour' => $teacherData['price_hour'],
                    'bio' => $teacherData['bio'],
                    'experience_years' => $teacherData['experience_years'],
                    'certifications' => $teacherData['certifications'],
                ]);
                
                // Kategori ilişkilerini ekle
                foreach ($teacherData['categories'] as $categoryName) {
                    $category = Category::where('name', $categoryName)->first();
                    if ($category) {
                        $teacher->categories()->attach($category->id);
                    }
                }
                
                echo "✅ Öğretmen oluşturuldu: {$teacherData['name']} (User ID: {$user->id})\n";
            } else {
                echo "ℹ️ Öğretmen zaten var: {$teacherData['name']} (User ID: {$user->teacher->user_id})\n";
            }
        }
    }

    private function createStudents()
    {
        $students = [
            ['name' => 'Ali Yıldız', 'email' => 'ali.student@nazliyavuz.com'],
            ['name' => 'Emre Şahin', 'email' => 'emre.student@nazliyavuz.com'],
            ['name' => 'Fatma Kaya', 'email' => 'fatma.student@nazliyavuz.com'],
            ['name' => 'Zeynep Aktaş', 'email' => 'zeynep.student@nazliyavuz.com'],
            ['name' => 'Can Özkan', 'email' => 'can.student@nazliyavuz.com'],
        ];

        foreach ($students as $studentData) {
            User::firstOrCreate(
                ['email' => $studentData['email']],
                [
                    'name' => $studentData['name'],
                    'password' => Hash::make('password'),
                    'role' => 'student',
                    'email_verified_at' => now(),
                ]
            );
            echo "✅ Öğrenci oluşturuldu: {$studentData['name']}\n";
        }
    }

    private function createTeacherAvailabilities()
    {
        $teachers = Teacher::with('user')->get();
        
        if ($teachers->isEmpty()) {
            echo "⚠️ Öğretmen bulunamadı\n";
            return;
        }
        
        foreach ($teachers as $teacher) {
            if (!$teacher->user_id) {
                echo "⚠️ Öğretmen user_id'si yok: {$teacher->user->name}\n";
                continue;
            }
            
            // Her öğretmen için haftalık müsaitlik
            $days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
            
            foreach ($days as $day) {
                TeacherAvailability::create([
                    'teacher_id' => $teacher->user_id,
                    'day_of_week' => $day,
                    'start_time' => '09:00',
                    'end_time' => '17:00',
                    'is_available' => true,
                ]);
            }
            echo "✅ Müsaitlik oluşturuldu: {$teacher->user->name} (User ID: {$teacher->user_id})\n";
        }
    }

    private function createReservations()
    {
        $teachers = Teacher::with('user', 'categories')->get();
        $students = User::where('role', 'student')->get();
        
        if ($teachers->isEmpty() || $students->isEmpty()) {
            echo "⚠️ Öğretmen veya öğrenci bulunamadı\n";
            return;
        }

        $subjects = [
            1 => 'Matematik Dersi',
            2 => 'İngilizce Dersi',
            3 => 'Müzik Dersi',
            4 => 'Fizik Dersi',
            5 => 'Kimya Dersi',
            6 => 'Biyoloji Dersi',
            7 => 'Tarih Dersi',
            8 => 'Türkçe Dersi',
        ];

        // Her öğrenci için 2-3 rezervasyon oluştur
        foreach ($students as $student) {
            $randTeachers = $teachers->random(min(2, $teachers->count()));
            
            foreach ($randTeachers as $teacher) {
                // Öğretmenin kategorilerinden birini seç
                $category = $teacher->categories->first();
                
                for ($i = 1; $i <= 3; $i++) {
                    // İlk rezervasyon completed, diğerleri pending/accepted
                    $status = $i === 1 ? 'completed' : (['pending', 'accepted'][array_rand([0, 1])]);
                    
                    $categoryId = $category ? $category->id : 1;
                    $subject = $subjects[$categoryId] ?? 'Matematik Dersi';
                    
                    Reservation::create([
                        'student_id' => $student->id,
                        'teacher_id' => $teacher->user->id,
                        'category_id' => $categoryId,
                        'subject' => $subject,
                        'proposed_datetime' => now()->subDays($i * 7), // Geçmiş tarih
                        'duration_minutes' => 60,
                        'price' => $teacher->price_hour,
                        'status' => $status,
                        'notes' => 'Rezervasyon notu',
                    ]);
                }
            }
            echo "✅ Rezervasyonlar oluşturuldu: {$student->name}\n";
        }
    }

    private function createLessons()
    {
        // Sadece accepted ve completed rezervasyonlar için ders oluştur
        $reservations = Reservation::whereIn('status', ['accepted', 'completed'])->get();
        
        foreach ($reservations as $reservation) {
            Lesson::create([
                'reservation_id' => $reservation->id,
                'teacher_id' => $reservation->teacher_id,
                'student_id' => $reservation->student_id,
                'scheduled_at' => $reservation->proposed_datetime,
                'started_at' => $reservation->status === 'completed' ? $reservation->proposed_datetime : null,
                'ended_at' => $reservation->status === 'completed' ? $reservation->proposed_datetime->copy()->addMinutes($reservation->duration_minutes) : null,
                'duration_minutes' => $reservation->duration_minutes,
                'status' => $reservation->status === 'completed' ? 'completed' : 'scheduled',
                'notes' => $reservation->status === 'completed' ? 'Tamamlanan ders' : 'Planlanan ders',
            ]);
        }
        echo "✅ Dersler oluşturuldu (" . $reservations->count() . " ders)\n";
    }

    private function createRatings()
    {
        $reservations = Reservation::where('status', 'completed')
            ->with(['student', 'teacher'])
            ->get();

        foreach ($reservations as $reservation) {
            if (!$reservation->rating) {
                Rating::create([
                    'student_id' => $reservation->student_id,
                    'teacher_id' => $reservation->teacher_id,
                    'reservation_id' => $reservation->id,
                    'rating' => rand(4, 5),
                ]);
            }
        }
        echo "✅ Değerlendirmeler oluşturuldu\n";
    }

    private function createChats()
    {
        $students = User::where('role', 'student')->get();
        $teachers = Teacher::with('user')->get();

        foreach ($students as $student) {
            $randomTeachers = $teachers->random(min(2, $teachers->count()));
            
            foreach ($randomTeachers as $teacher) {
                Chat::firstOrCreate([
                    'user1_id' => $student->id,
                    'user2_id' => $teacher->user->id,
                ]);
            }
        }
        echo "✅ Chat'ler oluşturuldu\n";
    }

    private function createMessages()
    {
        $chats = Chat::with(['user1', 'user2'])->get();

        foreach ($chats as $chat) {
            // Her chat için birkaç mesaj oluştur
            for ($i = 1; $i <= 3; $i++) {
                $sender = $i % 2 == 1 ? $chat->user1 : $chat->user2;
                $receiver = $sender->id == $chat->user1_id ? $chat->user2 : $chat->user1;

                Message::create([
                    'chat_id' => $chat->id,
                    'sender_id' => $sender->id,
                    'receiver_id' => $receiver->id,
                    'content' => "Merhaba! Mesaj numarası: {$i}",
                    'message_type' => 'text',
                    'message_status' => 'sent',
                    'is_read' => $i == 1 ? false : true,
                ]);
            }
        }
        echo "✅ Mesajlar oluşturuldu\n";
    }

}
