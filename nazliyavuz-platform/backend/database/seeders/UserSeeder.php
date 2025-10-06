<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Teacher;
use App\Models\Category;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Admin kullanıcı
        $admin = User::firstOrCreate(
            ['email' => 'admin@nazliyavuz.com'],
            [
                'name' => 'Admin User',
                'password' => Hash::make('password'),
                'role' => 'admin',
                'verified_at' => now(),
                'email_verified_at' => now(),
            ]
        );

        // Örnek öğrenciler
        $students = [
            [
                'name' => 'Ahmet Yılmaz',
                'email' => 'ahmet@example.com',
                'role' => 'student',
            ],
            [
                'name' => 'Ayşe Demir',
                'email' => 'ayse@example.com',
                'role' => 'student',
            ],
            [
                'name' => 'Mehmet Kaya',
                'email' => 'mehmet@example.com',
                'role' => 'student',
            ],
            [
                'name' => 'Fatma Özkan',
                'email' => 'fatma@example.com',
                'role' => 'student',
            ],
        ];

        foreach ($students as $studentData) {
            User::firstOrCreate(
                ['email' => $studentData['email']],
                [
                    'name' => $studentData['name'],
                    'password' => Hash::make('password'),
                    'role' => $studentData['role'],
                    'verified_at' => now(),
                    'email_verified_at' => now(),
                ]
            );
        }

        // Örnek öğretmenler
        $teachers = [
            [
                'name' => 'Dr. Zeynep Aktaş',
                'email' => 'zeynep@example.com',
                'bio' => '15 yıllık müzik eğitimi deneyimi olan piyano öğretmeni. Konservatuar mezunu.',
                'education' => ['İstanbul Üniversitesi Konservatuar', 'Müzik Eğitimi Yüksek Lisans'],
                'certifications' => ['ABRSM Grade 8 Piano', 'Müzik Öğretmenliği Sertifikası'],
                'price_hour' => 150.00,
                'languages' => ['Türkçe', 'İngilizce'],
                'categories' => ['piyano', 'kulak-egitimi'],
            ],
            [
                'name' => 'Prof. Dr. Can Özkan',
                'email' => 'can@example.com',
                'bio' => 'Matematik profesörü. 20 yıllık üniversite deneyimi.',
                'education' => ['Boğaziçi Üniversitesi Matematik', 'MIT Doktora'],
                'certifications' => ['Profesörlük', 'Matematik Öğretmenliği'],
                'price_hour' => 200.00,
                'languages' => ['Türkçe', 'İngilizce'],
                'categories' => ['matematik', 'fizik'],
            ],
            [
                'name' => 'Ece Yıldız',
                'email' => 'ece@example.com',
                'bio' => 'Yoga eğitmeni ve wellness koçu. 10 yıllık deneyim.',
                'education' => ['Yoga Alliance 200h', 'Pilates Eğitmenliği'],
                'certifications' => ['RYT 200', 'Pilates Mat Sertifikası'],
                'price_hour' => 120.00,
                'languages' => ['Türkçe'],
                'categories' => ['yoga', 'meditasyon'],
            ],
            [
                'name' => 'Emre Şahin',
                'email' => 'emre@example.com',
                'bio' => 'Full-stack developer ve teknoloji eğitmeni.',
                'education' => ['Bilgisayar Mühendisliği', 'Yazılım Geliştirme'],
                'certifications' => ['AWS Certified', 'Google Cloud Professional'],
                'price_hour' => 180.00,
                'languages' => ['Türkçe', 'İngilizce'],
                'categories' => ['programlama', 'web-tasarimi'],
            ],
            [
                'name' => 'Selin Korkmaz',
                'email' => 'selin@example.com',
                'bio' => 'İngilizce öğretmeni. Cambridge sertifikalı.',
                'education' => ['İngiliz Dili ve Edebiyatı', 'CELTA Sertifikası'],
                'certifications' => ['CELTA', 'IELTS Examiner'],
                'price_hour' => 100.00,
                'languages' => ['Türkçe', 'İngilizce'],
                'categories' => ['ingilizce'],
            ],
            [
                'name' => 'Murat Güneş',
                'email' => 'murat@example.com',
                'bio' => 'Gitar öğretmeni ve müzisyen. Konservatuar mezunu.',
                'education' => ['Ankara Konservatuar', 'Gitar Performans'],
                'certifications' => ['Gitar Eğitmenliği', 'Müzik Prodüksiyon'],
                'price_hour' => 130.00,
                'languages' => ['Türkçe'],
                'categories' => ['gitar'],
            ],
        ];

        foreach ($teachers as $teacherData) {
            $user = User::firstOrCreate(
                ['email' => $teacherData['email']],
                [
                    'name' => $teacherData['name'],
                    'password' => Hash::make('password'),
                    'role' => 'teacher',
                    'verified_at' => now(),
                    'email_verified_at' => now(),
                ]
            );

            $teacher = Teacher::firstOrCreate(
                ['user_id' => $user->id],
                [
                    'bio' => $teacherData['bio'],
                    'education' => $teacherData['education'],
                    'certifications' => $teacherData['certifications'],
                    'price_hour' => $teacherData['price_hour'],
                    'languages' => $teacherData['languages'],
                    'rating_avg' => rand(40, 50) / 10, // 4.0 - 5.0 arası
                    'rating_count' => rand(5, 50),
                    'is_approved' => 1,
                ]
            );

            // Kategorileri ekle
            $categoryIds = Category::whereIn('slug', $teacherData['categories'])->pluck('id');
            $teacher->categories()->sync($categoryIds);
        }
    }
}