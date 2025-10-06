<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Yeni Değerlendirme</title>
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
            font-size: 24px;
            font-weight: bold;
            color: #2563eb;
            margin-bottom: 10px;
        }
        .title {
            color: #059669;
            font-size: 20px;
            margin-bottom: 20px;
        }
        .rating-box {
            background-color: #f0fdf4;
            border-left: 4px solid #059669;
            padding: 15px;
            margin: 20px 0;
            text-align: center;
        }
        .stars {
            font-size: 24px;
            color: #fbbf24;
            margin: 10px 0;
        }
        .student-info {
            background-color: #fef3c7;
            border-left: 4px solid #f59e0b;
            padding: 15px;
            margin: 20px 0;
        }
        .comment-box {
            background-color: #f8fafc;
            border-left: 4px solid #64748b;
            padding: 15px;
            margin: 20px 0;
            font-style: italic;
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
            <h1 class="title">⭐ Yeni Değerlendirme Aldınız!</h1>
        </div>

        <p>Merhaba <strong>{{ $teacher->name }}</strong>,</p>
        
        <p>{{ $student->name }} öğrencinizden yeni bir değerlendirme aldınız:</p>

        <div class="rating-box">
            <h3>📊 Değerlendirme</h3>
            <div class="stars">
                @for($i = 1; $i <= 5; $i++)
                    @if($i <= $rating)
                        ★
                    @else
                        ☆
                    @endif
                @endfor
            </div>
            <p><strong>{{ $rating }}/5</strong> puan aldınız!</p>
        </div>

        <div class="student-info">
            <h3>👨‍🎓 Öğrenci Bilgileri</h3>
            <p><strong>İsim:</strong> {{ $student->name }}</p>
            <p><strong>E-posta:</strong> {{ $student->email }}</p>
        </div>

        @if($comment)
        <div class="comment-box">
            <h3>💬 Yorum</h3>
            <p>"{{ $comment }}"</p>
        </div>
        @endif

        <p>Bu değerlendirme profil sayfanızda görüntülenecek ve diğer öğrenciler tarafından görülebilecektir. Değerlendirmeleriniz için teşekkür ederiz!</p>

        <div style="text-align: center;">
            <a href="{{ $platformUrl }}/profile" class="button">Profilimi Görüntüle</a>
        </div>

        <div class="footer">
            <p>Bu e-posta Nazliyavuz Platform tarafından otomatik olarak gönderilmiştir.</p>
            <p>© {{ date('Y') }} Nazliyavuz Platform. Tüm hakları saklıdır.</p>
        </div>
    </div>
</body>
</html>
