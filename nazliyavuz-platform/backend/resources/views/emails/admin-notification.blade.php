<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Admin Bildirimi</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #F44336; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f9f9f9; }
        .footer { text-align: center; padding: 20px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>{{ $subject }}</h1>
        </div>
        <div class="content">
            <p>{{ $message }}</p>
            @if(!empty($data))
            <h3>Detaylar:</h3>
            <ul>
                @foreach($data as $key => $value)
                <li><strong>{{ $key }}:</strong> {{ $value }}</li>
                @endforeach
            </ul>
            @endif
        </div>
        <div class="footer">
            <p>Nazliyavuz Platform Admin</p>
        </div>
    </div>
</body>
</html>
