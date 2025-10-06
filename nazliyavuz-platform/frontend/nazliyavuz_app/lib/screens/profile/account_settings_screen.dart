import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesap Ayarları'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Güvenlik',
            children: [
              ListTile(
                leading: const Icon(Icons.lock_rounded),
                title: const Text('Şifre Değiştir'),
                subtitle: const Text('Hesap şifrenizi güncelleyin'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded),
                onTap: () {
                  // Navigate to password change
                },
              ),
              ListTile(
                leading: const Icon(Icons.security_rounded),
                title: const Text('İki Faktörlü Doğrulama'),
                subtitle: const Text('Ek güvenlik katmanı ekleyin'),
                trailing: Switch(
                  value: false,
                  onChanged: (value) {
                    // Enable/disable 2FA
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Veri Yönetimi',
            children: [
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Verilerimi İndir'),
                subtitle: const Text('Hesap verilerinizi dışa aktarın'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded),
                onTap: () {
                  // Export data
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Tehlikeli Bölge',
            color: AppTheme.errorColor.withValues(alpha: 0.1),
            borderColor: AppTheme.errorColor.withValues(alpha: 0.3),
            children: [
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor),
                title: Text(
                  'Hesabı Sil',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                subtitle: const Text('Hesabınızı kalıcı olarak silin'),
                trailing: Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.errorColor),
                onTap: _showDeleteAccountDialog,
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
    Color? color,
    Color? borderColor,
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
            color: color ?? Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor ?? AppTheme.grey300),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Bu işlem geri alınamaz. Tüm verileriniz kalıcı olarak silinecektir. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete account
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
