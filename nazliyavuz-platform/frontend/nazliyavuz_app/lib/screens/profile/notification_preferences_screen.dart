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
    _emailNotifications = widget.preferences['email_notifications'] ?? true;
    _pushNotifications = widget.preferences['push_notifications'] ?? true;
    _lessonReminders = widget.preferences['lesson_reminders'] ?? true;
    _marketingEmails = widget.preferences['marketing_emails'] ?? false;
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
                onChanged: null, // Tıklanamaz yap
              ),
              SwitchListTile(
                title: const Text('Pazarlama E-postaları'),
                subtitle: const Text('Promosyon ve kampanya e-postaları'),
                value: _marketingEmails,
                onChanged: null, // Tıklanamaz yap
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
                onChanged: null, // Tıklanamaz yap
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
      // API call to save preferences
      await _apiService.updateNotificationPreferences({
        'email_notifications': _emailNotifications,
        'push_notifications': _pushNotifications,
        'lesson_reminders': _lessonReminders,
        'marketing_emails': _marketingEmails,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim tercihleri kaydedildi!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
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
            content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppTheme.accentRed,
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
