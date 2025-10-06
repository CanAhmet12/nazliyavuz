<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mail Testi</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            background-color: #ffffff;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 28px;
            font-weight: bold;
            color: #2563eb;
            margin-bottom: 10px;
        }
        .success {
            background-color: #d1fae5;
            border: 1px solid #10b981;
            border-radius: 8px;
            padding: 15px;
            margin: 20px 0;
            color: #065f46;
        }
        .info {
            background-color: #dbeafe;
            border: 1px solid #3b82f6;
            border-radius: 8px;
            padding: 15px;
            margin: 20px 0;
            color: #1e40af;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🧪 Nazliyavuz Platform</div>
            <h1>Mail Sistemi Test</h1>
        </div>

        <div class="success">
            <h3>✅ Mail Sistemi Çalışıyor!</h3>
            <p>Bu mail, Nazliyavuz Platform mail sisteminin düzgün çalıştığını gösterir.</p>
        </div>

        <div class="info">
            <h4>📋 Test Bilgileri:</h4>
            <p><strong>Mesaj:</strong> Mail sistemi başarıyla test edildi</p>
            <p><strong>Gönderim Zamanı:</strong> {{ date('d.m.Y H:i:s') }}</p>
            <p><strong>Mail Konfigürasyonu:</strong> Aktif</p>
        </div>

        <p>Eğer bu maili alabiliyorsanız, e-posta doğrulama sistemi de çalışacaktır.</p>

        <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; text-align: center; color: #6b7280; font-size: 14px;">
            <p>© {{ date('Y') }} Nazliyavuz Platform - Mail Test Sistemi</p>
        </div>
    </div>
</body>
</html>
