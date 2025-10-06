<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Şifre Sıfırlama</title>
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
        .title {
            font-size: 24px;
            color: #1f2937;
            margin-bottom: 20px;
        }
        .content {
            margin-bottom: 30px;
        }
        .button {
            display: inline-block;
            background-color: #dc2626;
            color: white;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            margin: 20px 0;
        }
        .button:hover {
            background-color: #b91c1c;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: 14px;
        }
        .warning {
            background-color: #fef2f2;
            border: 1px solid #f87171;
            border-radius: 8px;
            padding: 15px;
            margin: 20px 0;
            color: #991b1b;
        }
        .info {
            background-color: #eff6ff;
            border: 1px solid #93c5fd;
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
            <div class="logo">Nazliyavuz Platform</div>
            <h1 class="title">Şifre Sıfırlama</h1>
        </div>

        <div class="content">
            <p>Merhaba <strong>{{ $user->name }}</strong>,</p>
            
            <p>Hesabınız için şifre sıfırlama talebinde bulundunuz. Şifrenizi sıfırlamak için aşağıdaki butona tıklayın:</p>
            
            <div style="text-align: center;">
                <a href="{{ $resetUrl }}" class="button">Şifremi Sıfırla</a>
            </div>
            
            <div class="warning">
                <strong>Güvenlik Uyarısı:</strong> Bu link 60 dakika geçerlidir ve sadece bir kez kullanılabilir. Eğer şifre sıfırlama talebinde bulunmadıysanız, bu e-postayı görmezden gelebilirsiniz.
            </div>
            
            <div class="info">
                <strong>Bilgi:</strong> Şifrenizi sıfırladıktan sonra, tüm cihazlarınızdan çıkış yapmanız gerekebilir.
            </div>
            
            <p>Eğer bu talebi siz yapmadıysanız, hesabınızın güvenliği için derhal bizimle iletişime geçin.</p>
        </div>

        <div class="footer">
            <p>Bu e-posta otomatik olarak gönderilmiştir. Lütfen yanıtlamayın.</p>
            <p>© 2025 Nazliyavuz Platform. Tüm hakları saklıdır.</p>
        </div>
    </div>
</body>
</html>
