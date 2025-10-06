<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Reservation;
use App\Models\User;
use App\Models\Teacher;
use App\Models\Category;

class ReservationSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Test rezervasyonları oluştur
        $student = User::where('role', 'student')->first();
        $teacher = Teacher::first();
        $category = Category::first();

        if ($student && $teacher && $category) {
            // Bekleyen rezervasyon
            Reservation::create([
                'student_id' => $student->id,
                'teacher_id' => $teacher->user_id,
                'category_id' => $category->id,
                'subject' => 'Matematik Dersi',
                'proposed_datetime' => now()->addDays(1)->setTime(14, 0),
                'duration_minutes' => 60,
                'price' => 100.00,
                'status' => 'pending',
                'notes' => 'Lütfen temel konuları anlatın',
            ]);

            // Kabul edilmiş rezervasyon
            Reservation::create([
                'student_id' => $student->id,
                'teacher_id' => $teacher->user_id,
                'category_id' => $category->id,
                'subject' => 'İngilizce Konuşma',
                'proposed_datetime' => now()->addDays(2)->setTime(16, 0),
                'duration_minutes' => 90,
                'price' => 150.00,
                'status' => 'accepted',
                'notes' => 'Konuşma pratiği yapmak istiyorum',
            ]);

            // Tamamlanmış rezervasyon
            Reservation::create([
                'student_id' => $student->id,
                'teacher_id' => $teacher->user_id,
                'category_id' => $category->id,
                'subject' => 'Fizik Ödevi',
                'proposed_datetime' => now()->subDays(1)->setTime(10, 0),
                'duration_minutes' => 45,
                'price' => 75.00,
                'status' => 'completed',
                'notes' => 'Ödev konularını anlamak istiyorum',
            ]);

            $this->command->info('✅ Test rezervasyonları oluşturuldu!');
        } else {
            $this->command->error('❌ Gerekli veriler bulunamadı!');
            $this->command->error('Student: ' . ($student ? 'Var' : 'Yok'));
            $this->command->error('Teacher: ' . ($teacher ? 'Var' : 'Yok'));
            $this->command->error('Category: ' . ($category ? 'Var' : 'Yok'));
        }
    }
}
