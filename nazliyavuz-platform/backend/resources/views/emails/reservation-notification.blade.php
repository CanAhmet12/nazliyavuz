<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Yeni Rezervasyon Talebi</title>
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
        .reservation-details {
            background-color: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .detail-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            padding-bottom: 10px;
            border-bottom: 1px solid #e2e8f0;
        }
        .detail-row:last-child {
            border-bottom: none;
            margin-bottom: 0;
        }
        .detail-label {
            font-weight: bold;
            color: #4a5568;
        }
        .detail-value {
            color: #2d3748;
        }
        .button {
            display: inline-block;
            background-color: #059669;
            color: white;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            margin: 20px 0;
        }
        .button:hover {
            background-color: #047857;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Nazliyavuz Platform</div>
            <h1 class="title">Yeni Rezervasyon Talebi</h1>
        </div>

        <div class="content">
            <p>Merhaba <strong>{{ $teacher->name }}</strong>,</p>
            
            <p><strong>{{ $student->name }}</strong> adlı öğrenci sizden ders rezervasyonu talep etti.</p>
            
            <div class="reservation-details">
                <h3 style="margin-top: 0; color: #2d3748;">Rezervasyon Detayları</h3>
                
                <div class="detail-row">
                    <span class="detail-label">Öğrenci:</span>
                    <span class="detail-value">{{ $student->name }}</span>
                </div>
                
                <div class="detail-row">
                    <span class="detail-label">Konu:</span>
                    <span class="detail-value">{{ $reservation->subject }}</span>
                </div>
                
                <div class="detail-row">
                    <span class="detail-label">Tarih ve Saat:</span>
                    <span class="detail-value">{{ \Carbon\Carbon::parse($reservation->proposed_datetime)->format('d.m.Y H:i') }}</span>
                </div>
                
                <div class="detail-row">
                    <span class="detail-label">Süre:</span>
                    <span class="detail-value">{{ $reservation->duration_minutes }} dakika</span>
                </div>
                
                <div class="detail-row">
                    <span class="detail-label">Ücret:</span>
                    <span class="detail-value">{{ number_format($reservation->price, 2) }} TL</span>
                </div>
                
                @if($reservation->notes)
                <div class="detail-row">
                    <span class="detail-label">Notlar:</span>
                    <span class="detail-value">{{ $reservation->notes }}</span>
                </div>
                @endif
            </div>
            
            <p>Rezervasyonu onaylamak veya reddetmek için uygulamaya giriş yapın.</p>
            
            <div style="text-align: center;">
                <a href="{{ config('app.frontend_url') }}/reservations" class="button">Rezervasyonları Görüntüle</a>
            </div>
        </div>

        <div class="footer">
            <p>Bu e-posta otomatik olarak gönderilmiştir. Lütfen yanıtlamayın.</p>
            <p>© 2025 Nazliyavuz Platform. Tüm hakları saklıdır.</p>
        </div>
    </div>
</body>
</html>
