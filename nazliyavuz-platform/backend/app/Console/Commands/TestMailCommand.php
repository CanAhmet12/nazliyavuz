<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;
use App\Models\User;
use App\Services\MailService;

class TestMailCommand extends Command
{
    protected $signature = 'mail:test {email?}';
    protected $description = 'Test mail gönderimi - e-posta sistemini test eder';

    public function handle()
    {
        $email = $this->argument('email') ?? 'test@example.com';
        
        $this->info("🚀 Mail sistemi test ediliyor...");
        $this->info("📧 Test e-posta adresi: {$email}");
        
        // Mail konfigürasyonunu göster
        $this->showMailConfig();
        
        // Test mail gönder
        try {
            $this->sendTestMail($email);
            $this->info("✅ Test mail başarıyla gönderildi!");
        } catch (\Exception $e) {
            $this->error("❌ Mail gönderimi başarısız: " . $e->getMessage());
            $this->error("🔧 Çözüm önerileri:");
            $this->line("1. .env dosyasında MAIL_* ayarlarını kontrol edin");
            $this->line("2. Gmail App Password kullandığınızdan emin olun");
            $this->line("3. Firewall ayarlarını kontrol edin");
            $this->line("4. php artisan config:cache komutunu çalıştırın");
        }
    }
    
    private function showMailConfig()
    {
        $this->info("📋 Mail Konfigürasyonu:");
        $this->table(
            ['Ayar', 'Değer'],
            [
                ['MAIL_MAILER', config('mail.default')],
                ['MAIL_HOST', config('mail.mailers.smtp.host')],
                ['MAIL_PORT', config('mail.mailers.smtp.port')],
                ['MAIL_USERNAME', config('mail.mailers.smtp.username') ? '***' : 'BOŞ'],
                ['MAIL_ENCRYPTION', config('mail.mailers.smtp.encryption')],
                ['MAIL_FROM_ADDRESS', config('mail.from.address')],
                ['MAIL_FROM_NAME', config('mail.from.name')],
            ]
        );
    }
    
    private function sendTestMail($email)
    {
        Mail::send('emails.test-mail', [
            'message' => 'Bu bir test mailidir.',
            'timestamp' => now()->format('d.m.Y H:i:s'),
        ], function ($message) use ($email) {
            $message->to($email)
                ->subject('🧪 Nazliyavuz Platform - Mail Testi');
        });
    }
}
