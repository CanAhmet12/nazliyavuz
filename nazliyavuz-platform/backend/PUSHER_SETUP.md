# Pusher Real-time Messaging Setup

## Pusher Konfigürasyonu

Anlık mesajlaşma sistemini aktif etmek için aşağıdaki adımları takip edin:

### 1. Pusher Hesabı Oluşturun
- [Pusher.com](https://pusher.com) adresine gidin
- Ücretsiz hesap oluşturun
- Yeni bir app oluşturun

### 2. Pusher Bilgilerini Alın
Pusher dashboard'dan aşağıdaki bilgileri alın:
- App ID
- Key
- Secret
- Cluster

### 3. Environment Dosyasını Güncelleyin
`backend/.env` dosyasına aşağıdaki satırları ekleyin:

```env
# Pusher Configuration
PUSHER_APP_ID=your_pusher_app_id
PUSHER_APP_KEY=your_pusher_app_key
PUSHER_APP_SECRET=your_pusher_app_secret
PUSHER_APP_CLUSTER=eu

# Broadcasting Driver
BROADCAST_DRIVER=pusher

# Frontend Configuration
VITE_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
VITE_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"
```

### 4. Frontend Konfigürasyonu
`frontend/nazliyavuz_app/lib/services/real_time_chat_service.dart` dosyasında:

```dart
// Configuration
static const String _pusherKey = 'your_actual_pusher_key';
static const String _pusherCluster = 'eu';
```

### 5. Test Etme
Konfigürasyon tamamlandıktan sonra:
1. Backend'i yeniden başlatın
2. Frontend'i yeniden başlatın
3. Chat ekranında real-time özellikler aktif olacak

## Özellikler

✅ **Anlık Mesajlaşma**: Mesajlar anında gönderilir ve alınır
✅ **Typing Indicator**: Kullanıcı yazarken "yazıyor" göstergesi
✅ **Mesaj Okundu**: Mesajlar okundu olarak işaretlenir
✅ **Real-time Bildirimler**: Yeni mesajlar için anlık bildirimler

## Troubleshooting

### Pusher Bağlantı Sorunları
- Pusher bilgilerini kontrol edin
- Internet bağlantınızı kontrol edin
- Pusher dashboard'da app'in aktif olduğundan emin olun

### Development Mode
Development sırasında Pusher olmadan da temel mesajlaşma çalışır.
Production'da Pusher konfigürasyonu gereklidir.
