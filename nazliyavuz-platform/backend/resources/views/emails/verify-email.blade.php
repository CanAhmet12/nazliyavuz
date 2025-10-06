<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E-posta Doğrulama</title>
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
            background-color: #2563eb;
            color: white;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            margin: 20px 0;
        }
        .button:hover {
            background-color: #1d4ed8;
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
            background-color: #fef3c7;
            border: 1px solid #f59e0b;
            border-radius: 8px;
            padding: 15px;
            margin: 20px 0;
            color: #92400e;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Nazliyavuz Platform</div>
            <h1 class="title">E-posta Adresinizi Doğrulayın</h1>
        </div>

        <div class="content">
            <p>Merhaba <strong>{{ $user->name }}</strong>,</p>
            
            <p>Nazliyavuz Platform'a hoş geldiniz! Hesabınızı aktifleştirmek için e-posta adresinizi doğrulamanız gerekiyor.</p>
            
            <div style="text-align: center; margin: 30px 0;">
                <div style="background-color: #f8fafc; border: 2px solid #2563eb; border-radius: 12px; padding: 30px; margin: 20px 0;">
                    <h3 style="color: #1f2937; margin-bottom: 15px;">Doğrulama Kodunuz:</h3>
                    <div style="font-size: 48px; font-weight: bold; color: #2563eb; letter-spacing: 8px; font-family: 'Courier New', monospace;">
                        {{ $verificationCode }}
                    </div>
                    <p style="color: #6b7280; margin-top: 15px; font-size: 14px;">Bu kodu uygulamaya girerek hesabınızı doğrulayın</p>
                </div>
            </div>
            
            <div class="warning">
                <strong>Önemli:</strong> Bu kod 15 dakika geçerlidir. Eğer kod geçersiz olursa, uygulamadan tekrar doğrulama e-postası talep edebilirsiniz.
            </div>
            
            <p>Eğer bu hesabı siz oluşturmadıysanız, bu e-postayı görmezden gelebilirsiniz.</p>
        </div>

        <div class="footer">
            <p>Bu e-posta otomatik olarak gönderilmiştir. Lütfen yanıtlamayın.</p>
            <p>© 2025 Nazliyavuz Platform. Tüm hakları saklıdır.</p>
        </div>
    </div>
</body>
</html>
