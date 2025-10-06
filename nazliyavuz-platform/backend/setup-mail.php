<?php
/**
 * Nazliyavuz Platform - Mail Kurulum Script'i
 * Bu script mail konfigürasyonunu otomatik olarak ayarlar
 */

echo "🚀 Nazliyavuz Platform Mail Kurulum Script'i\n";
echo "==========================================\n\n";

// Mail konfigürasyon seçenekleri
$mailConfigs = [
    'gmail' => [
        'name' => 'Gmail SMTP',
        'host' => 'smtp.gmail.com',
        'port' => 587,
        'encryption' => 'tls',
        'instructions' => [
            'Gmail hesabınızda 2FA aktif olmalı',
            'Gmail App Password oluşturun',
            'App Password\'u MAIL_PASSWORD olarak kullanın'
        ]
    ],
    'mailgun' => [
        'name' => 'Mailgun',
        'host' => 'smtp.mailgun.org',
        'port' => 587,
        'encryption' => 'tls',
        'instructions' => [
            'Mailgun hesabı oluşturun',
            'Domain ekleyin',
            'API key\'i MAIL_PASSWORD olarak kullanın'
        ]
    ],
    'sendgrid' => [
        'name' => 'SendGrid',
        'host' => 'smtp.sendgrid.net',
        'port' => 587,
        'encryption' => 'tls',
        'instructions' => [
            'SendGrid hesabı oluşturun',
            'API key oluşturun',
            'API key\'i MAIL_PASSWORD olarak kullanın',
            'MAIL_USERNAME = apikey'
        ]
    ]
];

echo "📧 Mevcut Mail Servisleri:\n";
foreach ($mailConfigs as $key => $config) {
    echo "{$key}. {$config['name']}\n";
}

echo "\nHangi mail servisini kullanmak istiyorsunuz? (gmail/mailgun/sendgrid): ";
$choice = trim(fgets(STDIN));

if (!isset($mailConfigs[$choice])) {
    echo "❌ Geçersiz seçim!\n";
    exit(1);
}

$selectedConfig = $mailConfigs[$choice];

echo "\n📋 {$selectedConfig['name']} Kurulum Talimatları:\n";
foreach ($selectedConfig['instructions'] as $instruction) {
    echo "• {$instruction}\n";
}

echo "\n🔧 Gerekli .env Ayarları:\n";
echo "MAIL_MAILER=smtp\n";
echo "MAIL_HOST={$selectedConfig['host']}\n";
echo "MAIL_PORT={$selectedConfig['port']}\n";
echo "MAIL_ENCRYPTION={$selectedConfig['encryption']}\n";

if ($choice === 'sendgrid') {
    echo "MAIL_USERNAME=apikey\n";
} else {
    echo "MAIL_USERNAME=your_email@domain.com\n";
}

echo "MAIL_PASSWORD=your_app_password_or_api_key\n";
echo "MAIL_FROM_ADDRESS=noreply@nazliyavuz.com\n";
echo "MAIL_FROM_NAME=\"Nazliyavuz Platform\"\n";

echo "\n📝 .env dosyanızı oluşturmak için:\n";
echo "cp .env.example .env\n";
echo "php artisan key:generate\n";

echo "\n🧪 Mail sistemini test etmek için:\n";
echo "php artisan mail:test your_email@domain.com\n";

echo "\n✅ Kurulum tamamlandı!\n";
echo "📚 Daha fazla bilgi için: https://laravel.com/docs/mail\n";
?>
