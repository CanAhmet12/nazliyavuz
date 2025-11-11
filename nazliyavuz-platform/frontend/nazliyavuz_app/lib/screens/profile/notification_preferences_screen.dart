import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  final Map<String, dynamic> preferences;

  const NotificationPreferencesScreen({
    super.key,
    required this.preferences,
  });

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _lessonReminders = true;
  bool _marketingEmails = false;
  bool _isSaving = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadCurrentPreferences();
  }

  Future<void> _loadCurrentPreferences() async {
    try {
      final response = await _apiService.get('/user/notification-preferences');
      if (response['data'] != null) {
        setState(() {
          // Backend'den gelen int değerleri (0/1) bool'a çevir
          _emailNotifications = _convertToBool(response['data']['email_notifications']);
          _pushNotifications = _convertToBool(response['data']['push_notifications']);
          _lessonReminders = _convertToBool(response['data']['lesson_reminders']);
          _marketingEmails = _convertToBool(response['data']['marketing_emails']);
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
      // Fallback to widget preferences
      setState(() {
        _emailNotifications = _convertToBool(widget.preferences['email_notifications']) || true;
        _pushNotifications = _convertToBool(widget.preferences['push_notifications']) || true;
        _lessonReminders = _convertToBool(widget.preferences['lesson_reminders']) || true;
        _marketingEmails = _convertToBool(widget.preferences['marketing_emails']) || false;
      });
    }
  }

  // Int (0/1) değerlerini bool'a çeviren helper metod
  bool _convertToBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Tercihleri'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePreferences,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'E-posta Bildirimleri',
            children: [
              SwitchListTile(
                title: const Text('E-posta Bildirimleri'),
                subtitle: const Text('Genel e-posta bildirimleri'),
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() {
                    _emailNotifications = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Ders Hatırlatmaları'),
                subtitle: const Text('Yaklaşan dersler için hatırlatma'),
                value: _lessonReminders,
                onChanged: (value) {
                  setState(() {
                    _lessonReminders = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Pazarlama E-postaları'),
                subtitle: const Text('Promosyon ve kampanya e-postaları'),
                value: _marketingEmails,
                onChanged: (value) {
                  setState(() {
                    _marketingEmails = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Push Bildirimleri',
            children: [
              SwitchListTile(
                title: const Text('Push Bildirimleri'),
                subtitle: const Text('Mobil cihaz bildirimleri'),
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() {
                    _pushNotifications = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.grey300),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // API call to save preferences - bool değerleri backend'e gönder
      await _apiService.updateNotificationPreferences({
        'email_notifications': _emailNotifications,
        'push_notifications': _pushNotifications,
        'lesson_reminders': _lessonReminders,
        'marketing_emails': _marketingEmails,
      });

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Bildirim tercihleri başarıyla kaydedildi!'),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        
        // Return to previous screen with updated preferences
        Navigator.pop(context, {
          'email_notifications': _emailNotifications,
          'push_notifications': _pushNotifications,
          'lesson_reminders': _lessonReminders,
          'marketing_emails': _marketingEmails,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'),
              ],
            ),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
