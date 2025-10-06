<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rezervasyon Hatırlatması</title>
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
            color: #dc2626;
            font-size: 20px;
            margin-bottom: 20px;
        }
        .reminder-box {
            background-color: #fef2f2;
            border-left: 4px solid #dc2626;
            padding: 15px;
            margin: 20px 0;
        }
        .teacher-info {
            background-color: #fef3c7;
            border-left: 4px solid #f59e0b;
            padding: 15px;
            margin: 20px 0;
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
            <h1 class="title">⏰ Rezervasyon Hatırlatması</h1>
        </div>

        <p>Merhaba <strong>{{ $student->name }}</strong>,</p>
        
        <p>Yarın gerçekleşecek rezervasyonunuzu hatırlatmak istiyoruz:</p>

        <div class="reminder-box">
            <h3>📅 Rezervasyon Detayları</h3>
            <p><strong>Öğretmen:</strong> {{ $teacher->name }}</p>
            <p><strong>Tarih:</strong> {{ $reservation->date->format('d.m.Y') }}</p>
            <p><strong>Saat:</strong> {{ $reservation->start_time }} - {{ $reservation->end_time }}</p>
            <p><strong>Ders Türü:</strong> {{ $reservation->lesson_type }}</p>
            @if($reservation->notes)
            <p><strong>Notlar:</strong> {{ $reservation->notes }}</p>
            @endif
        </div>

        <div class="teacher-info">
            <h3>👨‍🏫 Öğretmen Bilgileri</h3>
            <p><strong>İsim:</strong> {{ $teacher->name }}</p>
            <p><strong>E-posta:</strong> {{ $teacher->email }}</p>
            @if($reservation->teacher->bio)
            <p><strong>Hakkında:</strong> {{ $reservation->teacher->bio }}</p>
            @endif
        </div>

        <p><strong>Önemli Notlar:</strong></p>
        <ul>
            <li>Rezervasyonunuzu iptal etmek istiyorsanız, en az 2 saat önceden bildirmeniz gerekmektedir.</li>
            <li>Ders başlamadan 10 dakika önce hazır olmanızı öneririz.</li>
            <li>Herhangi bir sorunuz varsa öğretmeninizle iletişime geçebilirsiniz.</li>
        </ul>

        <div style="text-align: center;">
            <a href="{{ $platformUrl }}/reservations" class="button">Rezervasyonlarımı Görüntüle</a>
        </div>

        <div class="footer">
            <p>Bu e-posta Nazliyavuz Platform tarafından otomatik olarak gönderilmiştir.</p>
            <p>© {{ date('Y') }} Nazliyavuz Platform. Tüm hakları saklıdır.</p>
        </div>
    </div>
</body>
</html>
