import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';

class ModernChatBackupScreen extends StatefulWidget {
  final User teacher;
  final int chatId;

  const ModernChatBackupScreen({
    Key? key,
    required this.teacher,
    required this.chatId,
  }) : super(key: key);

  @override
  State<ModernChatBackupScreen> createState() => _ModernChatBackupScreenState();
}

class _ModernChatBackupScreenState extends State<ModernChatBackupScreen>
    with TickerProviderStateMixin {
  final _apiService = ApiService();
  
  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = false;
  String? _error;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBackups();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    
    try {
      // Simulate loading backups
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _backups = [
          {
            'id': '1',
            'name': 'Chat Backup - ${DateTime.now().subtract(const Duration(days: 1)).toString().split(' ')[0]}',
            'date': DateTime.now().subtract(const Duration(days: 1)),
            'size': '2.3 MB',
            'type': 'full',
            'status': 'completed',
          },
          {
            'id': '2',
            'name': 'Messages Only - ${DateTime.now().subtract(const Duration(days: 3)).toString().split(' ')[0]}',
            'date': DateTime.now().subtract(const Duration(days: 3)),
            'size': '1.1 MB',
            'type': 'messages',
            'status': 'completed',
          },
        ];
        _isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Chat Yedekleme'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _createBackup,
            icon: const Icon(Icons.add),
            tooltip: 'Yeni Yedek Oluştur',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  
                  // Backup Options
                  _buildBackupOptions(),
                  const SizedBox(height: 24),
                  
                  // Existing Backups
                  _buildExistingBackups(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hızlı İşlemler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.backup,
                  title: 'Tam Yedek',
                  subtitle: 'Tüm mesajlar ve dosyalar',
                  color: Colors.blue,
                  onTap: () => _createFullBackup(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.chat_bubble_outline,
                  title: 'Sadece Mesajlar',
                  subtitle: 'Metin mesajları',
                  color: Colors.green,
                  onTap: () => _createMessagesBackup(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupOptions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yedekleme Seçenekleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          
          _buildBackupOption(
            icon: Icons.cloud_upload,
            title: 'Bulut Yedekleme',
            subtitle: 'Google Drive, iCloud, OneDrive',
            onTap: () => _showCloudBackupOptions(),
          ),
          
          _buildBackupOption(
            icon: Icons.sd_card,
            title: 'Yerel Yedekleme',
            subtitle: 'Cihazınıza kaydet',
            onTap: () => _createLocalBackup(),
          ),
          
          _buildBackupOption(
            icon: Icons.email,
            title: 'E-posta Gönder',
            subtitle: 'Yedek dosyasını e-posta ile gönder',
            onTap: () => _sendBackupViaEmail(),
          ),
          
          _buildBackupOption(
            icon: Icons.schedule,
            title: 'Otomatik Yedekleme',
            subtitle: 'Düzenli yedekleme ayarları',
            onTap: () => _showAutoBackupSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[600], size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildExistingBackups() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mevcut Yedekler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        
        if (_backups.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.backup_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Henüz yedek yok',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'İlk yedeğinizi oluşturun',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
        else
          ..._backups.map((backup) => _buildBackupItem(backup)).toList(),
      ],
    );
  }

  Widget _buildBackupItem(Map<String, dynamic> backup) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getBackupTypeColor(backup['type']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getBackupTypeIcon(backup['type']),
              color: _getBackupTypeColor(backup['type']),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup['name'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(backup['date']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.storage, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      backup['size'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleBackupAction(value, backup),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 16),
                    SizedBox(width: 8),
                    Text('Geri Yükle'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 16),
                    SizedBox(width: 8),
                    Text('İndir'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 16),
                    SizedBox(width: 8),
                    Text('Paylaş'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sil', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: const Icon(Icons.more_vert, size: 20),
          ),
        ],
      ),
    );
  }

  Color _getBackupTypeColor(String type) {
    switch (type) {
      case 'full':
        return Colors.blue;
      case 'messages':
        return Colors.green;
      case 'media':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getBackupTypeIcon(String type) {
    switch (type) {
      case 'full':
        return Icons.backup;
      case 'messages':
        return Icons.chat_bubble_outline;
      case 'media':
        return Icons.attach_file;
      default:
        return Icons.backup;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _createBackup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Yedek Oluştur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildBackupTypeOption('full', 'Tam Yedek', 'Tüm mesajlar ve dosyalar'),
                  _buildBackupTypeOption('messages', 'Sadece Mesajlar', 'Metin mesajları'),
                  _buildBackupTypeOption('media', 'Sadece Medya', 'Resim, video, ses dosyaları'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupTypeOption(String type, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getBackupTypeColor(type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getBackupTypeIcon(type),
            color: _getBackupTypeColor(type),
            size: 20,
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.pop(context);
          _createBackupOfType(type);
        },
      ),
    );
  }

  void _createBackupOfType(String type) {
    // Implement backup creation
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type yedekleme başlatıldı'),
        backgroundColor: Colors.green[600],
      ),
    );
  }

  void _createFullBackup() {
    _createBackupOfType('full');
  }

  void _createMessagesBackup() {
    _createBackupOfType('messages');
  }

  void _showCloudBackupOptions() {
    // Implement cloud backup options
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulut yedekleme seçenekleri yakında eklenecek')),
    );
  }

  void _createLocalBackup() {
    // Implement local backup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yerel yedekleme başlatıldı')),
    );
  }

  void _sendBackupViaEmail() {
    // Implement email backup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('E-posta yedekleme yakında eklenecek')),
    );
  }

  void _showAutoBackupSettings() {
    // Implement auto backup settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Otomatik yedekleme ayarları yakında eklenecek')),
    );
  }

  void _handleBackupAction(String action, Map<String, dynamic> backup) {
    switch (action) {
      case 'restore':
        _restoreBackup(backup);
        break;
      case 'download':
        _downloadBackup(backup);
        break;
      case 'share':
        _shareBackup(backup);
        break;
      case 'delete':
        _deleteBackup(backup);
        break;
    }
  }

  void _restoreBackup(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedek Geri Yükle'),
        content: Text('${backup['name']} yedeğini geri yüklemek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yedek geri yüklendi')),
              );
            },
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
    );
  }

  void _downloadBackup(Map<String, dynamic> backup) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${backup['name']} indiriliyor...')),
    );
  }

  void _shareBackup(Map<String, dynamic> backup) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${backup['name']} paylaşılıyor...')),
    );
  }

  void _deleteBackup(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedek Sil'),
        content: Text('${backup['name']} yedeğini silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _backups.removeWhere((b) => b['id'] == backup['id']);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yedek silindi')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
