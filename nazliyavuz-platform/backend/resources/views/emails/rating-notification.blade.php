<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Değerlendirme Bildirimi</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #FF9800; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f9f9f9; }
        .footer { text-align: center; padding: 20px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Yeni Değerlendirme Aldınız</h1>
        </div>
        <div class="content">
            <p>Merhaba {{ $teacher->name }},</p>
            <p>{{ $student->name }} adlı öğrencinizden yeni bir değerlendirme aldınız:</p>
            <ul>
                <li><strong>Puan:</strong> {{ $rating }}/5</li>
                @if($review)
                <li><strong>Yorum:</strong> {{ $review }}</li>
                @endif
            </ul>
            <p>Detaylar için platformu ziyaret edebilirsiniz.</p>
        </div>
        <div class="footer">
            <p>Nazliyavuz Platform</p>
        </div>
    </div>
</body>
</html>
