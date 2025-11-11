import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/notification.dart' as app_notification;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ApiService _apiService = ApiService();
  List<app_notification.Notification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await _apiService.getNotifications();
      
      if (mounted) {
        setState(() {
          // Handle different response structures
          List<dynamic> notificationsData = [];
          if (result['notifications'] != null) {
            notificationsData = result['notifications'] as List;
          } else if (result['data'] != null) {
            notificationsData = result['data'] as List;
          } else if (result is List) {
            notificationsData = result as List;
          }
          
          _notifications = notificationsData
              .map((json) {
                try {
                  return app_notification.Notification.fromJson(json);
                } catch (e) {
                  print('Error parsing notification: $e');
                  print('JSON: $json');
                  // Return a default notification if parsing fails
                  Map<String, dynamic> fallbackPayload = {};
                  if (json['payload'] != null) {
                    fallbackPayload = json['payload'];
                  } else if (json['data'] != null) {
                    fallbackPayload = json['data'];
                  }
                  if (json['title'] != null) {
                    fallbackPayload['title'] = json['title'];
                  }
                  if (json['message'] != null) {
                    fallbackPayload['message'] = json['message'];
                  }
                  
                  DateTime? fallbackReadAt;
                  if (json['read_at'] != null) {
                    try {
                      fallbackReadAt = DateTime.parse(json['read_at']);
                    } catch (e) {
                      fallbackReadAt = null;
                    }
                  }
                  
                  DateTime fallbackCreatedAt = DateTime.now();
                  if (json['created_at'] != null) {
                    try {
                      fallbackCreatedAt = DateTime.parse(json['created_at']);
                    } catch (e) {
                      fallbackCreatedAt = DateTime.now();
                    }
                  }
                  
                  DateTime fallbackUpdatedAt = DateTime.now();
                  if (json['updated_at'] != null) {
                    try {
                      fallbackUpdatedAt = DateTime.parse(json['updated_at']);
                    } catch (e) {
                      fallbackUpdatedAt = DateTime.now();
                    }
                  }
                  
                  return app_notification.Notification(
                    id: json['id'] ?? 0,
                    userId: json['user_id'] ?? 0,
                    type: json['type'] ?? 'unknown',
                    payload: fallbackPayload,
                    readAt: fallbackReadAt,
                    createdAt: fallbackCreatedAt,
                    updatedAt: fallbackUpdatedAt,
                  );
                }
              })
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(app_notification.Notification notification) async {
    if (notification.isRead) return;

    try {
      await _apiService.markNotificationAsRead(notification.id);
      
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = notification.copyWith(readAt: DateTime.now());
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsAsRead();
      
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((notification) {
            return notification.copyWith(readAt: DateTime.now());
          }).toList();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm bildirimler okundu olarak işaretlendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B82F6), // AppTheme.primaryBlue
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 36, // 40 -> 36 daha küçük
              height: 36, // 40 -> 36 daha küçük
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18), // 20 -> 18
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: Color(0xFF3B82F6),
                size: 18, // 20 -> 18 daha küçük
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Bildirimler',
                style: TextStyle(
                  fontSize: 18, // 20 -> 18 daha küçük
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_notifications.where((n) => n.isUnread).length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_notifications.any((n) => n.isUnread))
            Container(
              width: 36, // 40 -> 36 daha küçük
              height: 36, // 40 -> 36 daha küçük
              margin: const EdgeInsets.only(right: 12), // 16 -> 12 daha kompakt
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.done_all_rounded,
                  color: Colors.white,
                  size: 18, // 20 -> 18 daha küçük
                ),
                onPressed: _markAllAsRead,
                tooltip: 'Tümünü Okundu İşaretle',
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24), // 16 -> 24 daha kompakt
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)), // AppTheme.primaryBlue -> Color(0xFF3B82F6)
              ),
              const SizedBox(height: 16),
              Text(
                'Bildirimler yükleniyor...',
                style: TextStyle(
                  color: const Color(0xFF64748B), // Colors.grey[600] -> Color(0xFF64748B)
                  fontSize: 14, // 16 -> 14 daha küçük
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16), // 32 -> 16 daha kompakt
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1), // Colors.red -> Color(0xFFEF4444)
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: Color(0xFFEF4444), // Colors.red -> Color(0xFFEF4444)
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bildirimler yüklenirken hata oluştu',
                style: const TextStyle(
                  fontSize: 16, // headlineSmall -> 16
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B), // Colors.grey[600] -> Color(0xFF64748B)
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20), // 24 -> 20 daha küçük
              ElevatedButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6), // AppTheme.primaryBlue -> Color(0xFF3B82F6)
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 24,12 -> 20,10 daha küçük
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1), // AppTheme.primaryBlue -> Color(0xFF3B82F6)
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 40,
                  color: Color(0xFF3B82F6), // AppTheme.primaryBlue -> Color(0xFF3B82F6)
                ),
              ),
              const SizedBox(height: 20), // 16 -> 20 daha büyük
              const Text(
                'Henüz bildirim yok',
                style: TextStyle(
                  fontSize: 18, // headlineSmall -> 18
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yeni bildirimler burada görünecek',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B), // Colors.grey[600] -> Color(0xFF64748B)
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: const Color(0xFF3B82F6), // AppTheme.primaryBlue -> Color(0xFF3B82F6)
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // 16 -> 8,12 daha kompakt
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildNotificationCard(app_notification.Notification notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 16,6 -> 12,4 daha kompakt
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 16 -> 12 daha küçük
        border: notification.isUnread
            ? Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.15), // AppTheme.primaryBlue -> Color(0xFF3B82F6)
                width: 1,
              )
            : Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: notification.isUnread 
                ? const Color(0xFF3B82F6).withOpacity(0.08) // AppTheme.primaryBlue -> Color(0xFF3B82F6)
                : Colors.black.withOpacity(0.03),
            blurRadius: 6, // 8 -> 6 daha küçük
            offset: const Offset(0, 2), // 4 -> 2 daha küçük
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _markAsRead(notification),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12), // 16 -> 12 daha kompakt
            child: Row(
              children: [
                // İkon
                Container(
                  width: 40, // 48 -> 40 daha küçük
                  height: 40, // 48 -> 40 daha küçük
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20), // 24 -> 20 daha küçük
                    border: Border.all(
                      color: _getNotificationColor(notification.type).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 20, // 24 -> 20 daha küçük
                  ),
                ),
                const SizedBox(width: 12), // 16 -> 12 daha kompakt

                // İçerik
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14, // 16 -> 14 daha küçük
                                fontWeight: notification.isUnread 
                                    ? FontWeight.w700 // bold -> w700
                                    : FontWeight.w600,
                                color: const Color(0xFF1E293B), // Colors.black87 -> Color(0xFF1E293B)
                              ),
                            ),
                          ),
                          if (notification.isUnread)
                            Container(
                              width: 6, // 8 -> 6 daha küçük
                              height: 6, // 8 -> 6 daha küçük
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6), // AppTheme.primaryBlue -> Color(0xFF3B82F6)
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4), // 6 -> 4 daha küçük
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 12, // 14 -> 12 daha küçük
                          color: const Color(0xFF64748B), // Colors.grey[600] -> Color(0xFF64748B)
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6), // 8 -> 6 daha küçük
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12, // 14 -> 12 daha küçük
                            color: const Color(0xFF94A3B8), // Colors.grey[500] -> Color(0xFF94A3B8)
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 11, // 12 -> 11 daha küçük
                              color: Color(0xFF94A3B8), // Colors.grey[500] -> Color(0xFF94A3B8)
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'reservation_request':
        return Icons.calendar_today;
      case 'reservation_response':
        return Icons.check_circle;
      case 'reservation_cancelled':
        return Icons.cancel;
      case 'payment_received':
        return Icons.payment;
      case 'profile_updated':
        return Icons.person;
      case 'system_announcement':
        return Icons.announcement;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'reservation_request':
        return Colors.blue;
      case 'reservation_response':
        return Colors.green;
      case 'reservation_cancelled':
        return Colors.red;
      case 'payment_received':
        return Colors.orange;
      case 'profile_updated':
        return Colors.purple;
      case 'system_announcement':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }
}
