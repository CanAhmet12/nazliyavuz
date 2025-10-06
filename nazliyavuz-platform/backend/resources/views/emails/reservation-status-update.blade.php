<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Rezervasyon Durumu Güncellendi</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #4CAF50; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f9f9f9; }
        .footer { text-align: center; padding: 20px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Rezervasyon Durumu Güncellendi</h1>
        </div>
        <div class="content">
            <p>Merhaba {{ $student->name }},</p>
            <p>Rezervasyonunuzun durumu güncellenmiştir:</p>
            <ul>
                <li><strong>Öğretmen:</strong> {{ $teacher->name }}</li>
                <li><strong>Tarih:</strong> {{ $reservation->proposed_datetime }}</li>
                <li><strong>Durum:</strong> {{ ucfirst($reservation->status) }}</li>
                <li><strong>Konu:</strong> {{ $reservation->subject }}</li>
            </ul>
            <p>Detaylar için platformu ziyaret edebilirsiniz.</p>
        </div>
        <div class="footer">
            <p>Nazliyavuz Platform</p>
        </div>
    </div>
</body>
</html>
