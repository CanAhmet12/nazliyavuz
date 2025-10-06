import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/enhanced_features_service.dart';
import '../../services/api_service.dart';
import '../profile/profile_edit_screen.dart';
import '../profile/password_change_screen.dart';
import 'help_center_screen.dart';
import 'contact_support_screen.dart';
import '../content/content_page_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  
  bool _isDarkMode = false;
  String _selectedLanguage = 'tr';
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _isDarkMode = ThemeService.themeMode == ThemeMode.dark;
      _selectedLanguage = ThemeService.languageCode;
      _fontScale = AccessibilityService.fontScale;
      _highContrast = AccessibilityService.highContrast;
      _reduceMotion = AccessibilityService.reduceMotion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSectionTitle('Görünüm'),
            _buildAppearanceSection(),
            
            const SizedBox(height: 24),
            
            // Language Section
            _buildSectionTitle('Dil'),
            _buildLanguageSection(),
            
            const SizedBox(height: 24),
            
            // Notifications Section
            _buildSectionTitle('Bildirimler'),
            _buildNotificationsSection(),
            
            const SizedBox(height: 24),
            
            // Accessibility Section
            _buildSectionTitle('Erişilebilirlik'),
            _buildAccessibilitySection(),
            
            const SizedBox(height: 24),
            
            // Account Section
            _buildSectionTitle('Hesap'),
            _buildAccountSection(),
            
            const SizedBox(height: 24),
            
            // Support Section
            _buildSectionTitle('Destek'),
            _buildSupportSection(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.grey900,
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return CustomWidgets.customCard(
      child: Column(
        children: [
          _buildSwitchTile(
            title: 'Karanlık Mod',
            subtitle: 'Uygulamayı karanlık temada kullan',
            value: _isDarkMode,
            onChanged: (value) async {
              setState(() {
                _isDarkMode = value;
              });
              await ThemeService.setThemeMode(
                value ? ThemeMode.dark : ThemeMode.light,
              );
              HapticFeedback.lightImpact();
            },
            icon: Icons.dark_mode_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    return CustomWidgets.customCard(
      child: Column(
        children: [
          _buildLanguageTile('Türkçe', 'tr', Icons.flag_rounded),
          const Divider(),
          _buildLanguageTile('English', 'en', Icons.flag_rounded),
          const Divider(),
          _buildLanguageTile('Deutsch', 'de', Icons.flag_rounded),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(String name, String code, IconData icon) {
    final isSelected = _selectedLanguage == code;
    
    return ListTile(
      leading: Icon(
        icon,
        color: AppTheme.primaryBlue,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? AppTheme.primaryBlue : AppTheme.grey900,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_rounded,
              color: AppTheme.primaryBlue,
            )
          : null,
      onTap: () async {
        setState(() {
          _selectedLanguage = code;
        });
        await ThemeService.setLanguage(code);
        HapticFeedback.lightImpact();
      },
    );
  }

  Widget _buildNotificationsSection() {
    return CustomWidgets.customCard(
      child: Column(
        children: [
          _buildSwitchTile(
            title: 'Bildirimler',
            subtitle: 'Genel bildirimleri aç/kapat',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
                if (!value) {
                  _emailNotifications = false;
                  _pushNotifications = false;
                }
              });
              HapticFeedback.lightImpact();
            },
            icon: Icons.notifications_rounded,
          ),
          if (_notificationsEnabled) ...[
            const Divider(),
            _buildSwitchTile(
              title: 'E-posta Bildirimleri',
              subtitle: 'E-posta ile bildirim al',
              value: _emailNotifications,
              onChanged: (value) {
                setState(() {
                  _emailNotifications = value;
                });
                HapticFeedback.lightImpact();
              },
              icon: Icons.email_rounded,
            ),
            const Divider(),
            _buildSwitchTile(
              title: 'Push Bildirimleri',
              subtitle: 'Anlık bildirimler al',
              value: _pushNotifications,
              onChanged: (value) {
                setState(() {
                  _pushNotifications = value;
                });
                HapticFeedback.lightImpact();
              },
              icon: Icons.notifications_active_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccessibilitySection() {
    return CustomWidgets.customCard(
      child: Column(
        children: [
          _buildSliderTile(
            title: 'Yazı Boyutu',
            subtitle: 'Metin boyutunu ayarla',
            value: _fontScale,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            onChanged: (value) async {
              setState(() {
                _fontScale = value;
              });
              await AccessibilityService.setFontScale(value);
              HapticFeedback.lightImpact();
            },
            icon: Icons.text_fields_rounded,
          ),
          const Divider(),
          _buildSwitchTile(
            title: 'Yüksek Kontrast',
            subtitle: 'Daha belirgin renkler kullan',
            value: _highContrast,
            onChanged: (value) async {
              setState(() {
                _highContrast = value;
              });
              await AccessibilityService.setHighContrast(value);
              HapticFeedback.lightImpact();
            },
            icon: Icons.contrast_rounded,
          ),
          const Divider(),
          _buildSwitchTile(
            title: 'Animasyonları Azalt',
            subtitle: 'Daha az animasyon kullan',
            value: _reduceMotion,
            onChanged: (value) async {
              setState(() {
                _reduceMotion = value;
              });
              await AccessibilityService.setReduceMotion(value);
              HapticFeedback.lightImpact();
            },
            icon: Icons.motion_photos_off_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return CustomWidgets.customCard(
      child: Column(
        children: [
          _buildActionTile(
            title: 'Profil Düzenle',
            subtitle: 'Kişisel bilgilerini güncelle',
            icon: Icons.person_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileEditScreen(userProfile: {})),
              );
            },
          ),
          const Divider(),
          _buildActionTile(
            title: 'Şifre Değiştir',
            subtitle: 'Hesap şifreni güncelle',
            icon: Icons.lock_reset_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PasswordChangeScreen()),
              );
            },
          ),
          const Divider(),
          _buildActionTile(
            title: 'İki Faktörlü Kimlik Doğrulama',
            subtitle: 'Hesap güvenliğini artır',
            icon: Icons.security_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              _show2FASetup();
            },
          ),
          const Divider(),
          _buildActionTile(
            title: 'Hesabı Sil',
            subtitle: 'Hesabını kalıcı olarak sil',
            icon: Icons.delete_forever_rounded,
            textColor: AppTheme.error,
            onTap: () {
              HapticFeedback.mediumImpact();
              _showDeleteAccountDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return CustomWidgets.customCard(
      child: Column(
        children: [
          _buildActionTile(
            title: 'Yardım Merkezi',
            subtitle: 'Sık sorulan sorular ve rehberler',
            icon: Icons.help_center_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpCenterScreen()),
              );
            },
          ),
          const Divider(),
          _buildActionTile(
            title: 'İletişim',
            subtitle: 'Destek ekibi ile iletişime geç',
            icon: Icons.contact_support_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
              );
            },
          ),
          const Divider(),
          _buildActionTile(
            title: 'Gizlilik Politikası',
            subtitle: 'Veri kullanımı ve gizlilik',
            icon: Icons.privacy_tip_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContentPageScreen(slug: 'privacy-policy')),
              );
            },
          ),
          const Divider(),
          _buildActionTile(
            title: 'Kullanım Şartları',
            subtitle: 'Hizmet şartları ve koşullar',
            icon: Icons.description_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContentPageScreen(slug: 'terms-of-service')),
              );
            },
          ),
          const Divider(),
          _buildActionTile(
            title: 'Uygulama Hakkında',
            subtitle: 'Sürüm 1.0.0',
            icon: Icons.info_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppTheme.primaryBlue,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.grey900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.grey600,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryBlue,
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppTheme.primaryBlue,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.grey900,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: AppTheme.primaryBlue,
            inactiveColor: AppTheme.grey300,
          ),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? AppTheme.primaryBlue,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor ?? AppTheme.grey900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.grey600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppTheme.grey400,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  void _showDeleteAccountDialog() {
    CustomWidgets.showCustomDialog(
      context: context,
      title: 'Hesabı Sil',
      content: 'Hesabınızı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
      confirmText: 'Sil',
      cancelText: 'İptal',
      isDestructive: true,
      onConfirm: () {
        _deleteAccount();
        CustomWidgets.showSnackbar(
          context: context,
          message: 'Hesap silme işlemi başlatıldı',
          icon: Icons.info_rounded,
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Rota Akademi',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlueDark,
            ],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(
          Icons.school_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
      children: [
        const Text(
          'Eğitimde yeni nesil platform. Öğrenciler ve öğretmenleri buluşturan modern bir eğitim deneyimi.',
        ),
        const SizedBox(height: 16),
        const Text(
          '© 2025 Rota Akademi. Tüm hakları saklıdır.',
        ),
      ],
    );
  }

  void _show2FASetup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İki Faktörlü Kimlik Doğrulama'),
        content: const Text(
          'İki faktörlü kimlik doğrulama hesabınızın güvenliğini artırır. '
          'Bu özellik henüz geliştirilme aşamasındadır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesap Silme'),
        content: const Text(
          'Hesabınızı silmek için lütfen şifrenizi girin:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService.deleteUserAccount(
                  password: 'user_confirmation',
                  confirmation: 'DELETE',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hesabınız başarıyla silindi'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Navigate to login or home
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hesap silme hatası: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
