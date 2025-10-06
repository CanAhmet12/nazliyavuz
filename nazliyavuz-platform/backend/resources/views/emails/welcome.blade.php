<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hoş Geldiniz</title>
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
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
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
            color: #059669;
            font-size: 22px;
            margin-bottom: 20px;
        }
        .welcome-box {
            background-color: #f0fdf4;
            border-left: 4px solid #059669;
            padding: 20px;
            margin: 20px 0;
        }
        .features {
            background-color: #f8fafc;
            border-left: 4px solid #64748b;
            padding: 20px;
            margin: 20px 0;
        }
        .feature-item {
            margin: 10px 0;
            padding: 10px;
            background-color: white;
            border-radius: 6px;
            border-left: 3px solid #2563eb;
        }
        .button {
            display: inline-block;
            background-color: #2563eb;
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 6px;
            margin: 20px 0;
        }
        .footer {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            font-size: 14px;
            color: #6b7280;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Nazliyavuz Platform</div>
            <h1 class="title">🎉 Hoş Geldiniz!</h1>
        </div>

        <div class="welcome-box">
            <h2>Merhaba {{ $user->name }}!</h2>
            <p>Nazliyavuz Platform'a katıldığınız için çok mutluyuz! Artık eğitim dünyasının bir parçasısınız.</p>
        </div>

        <p>Platformumuzda neler yapabileceğinizi keşfedin:</p>

        <div class="features">
            <h3>🚀 Platform Özellikleri</h3>
            
            <div class="feature-item">
                <strong>📚 Öğretmen Bulun:</strong> Alanında uzman öğretmenleri keşfedin ve rezervasyon yapın.
            </div>
            
            <div class="feature-item">
                <strong>📅 Rezervasyon Sistemi:</strong> Uygun zamanlarınızda ders rezervasyonu yapın.
            </div>
            
            <div class="feature-item">
                <strong>⭐ Değerlendirme:</strong> Aldığınız dersleri değerlendirin ve yorum yapın.
            </div>
            
            <div class="feature-item">
                <strong>🔍 Gelişmiş Arama:</strong> Kategori, fiyat ve rating'e göre filtreleme yapın.
            </div>
            
            <div class="feature-item">
                <strong>📱 Mobil Uygulama:</strong> Her yerden erişim sağlayın.
            </div>
        </div>

        @if($user->role === 'teacher')
        <div class="welcome-box">
            <h3>👨‍🏫 Öğretmen Olarak</h3>
            <p>Profilinizi tamamlayın, uygunluk saatlerinizi belirleyin ve öğrencilerinizle buluşun!</p>
        </div>
        @else
        <div class="welcome-box">
            <h3>👨‍🎓 Öğrenci Olarak</h3>
            <p>İhtiyacınız olan konularda uzman öğretmenleri bulun ve öğrenmeye başlayın!</p>
        </div>
        @endif

        <div style="text-align: center;">
            <a href="{{ $platformUrl }}" class="button">Platforma Git</a>
        </div>

        <p><strong>İpuçları:</strong></p>
        <ul>
            <li>Profilinizi tamamlayarak daha iyi eşleşmeler elde edin</li>
            <li>Rezervasyonlarınızı takip edin</li>
            <li>Değerlendirmelerinizi paylaşın</li>
            <li>Destek için bizimle iletişime geçin</li>
        </ul>

        <div class="footer">
            <p>Bu e-posta Nazliyavuz Platform tarafından otomatik olarak gönderilmiştir.</p>
            <p>© {{ date('Y') }} Nazliyavuz Platform. Tüm hakları saklıdır.</p>
        </div>
    </div>
</body>
</html>
