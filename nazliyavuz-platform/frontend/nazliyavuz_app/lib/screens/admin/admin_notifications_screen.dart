import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/enhanced_form_field.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  List<String> _selectedTargetUsers = ['all'];
  String _selectedType = 'info';
  bool _isSending = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> _targetUserOptions = [
    {'value': 'all', 'label': 'Tüm Kullanıcılar', 'icon': Icons.people},
    {'value': 'students', 'label': 'Öğrenciler', 'icon': Icons.person},
    {'value': 'teachers', 'label': 'Öğretmenler', 'icon': Icons.school},
  ];

  final List<Map<String, dynamic>> _typeOptions = [
    {'value': 'info', 'label': 'Bilgi', 'icon': Icons.info, 'color': Colors.blue},
    {'value': 'warning', 'label': 'Uyarı', 'icon': Icons.warning, 'color': Colors.orange},
    {'value': 'success', 'label': 'Başarı', 'icon': Icons.check_circle, 'color': Colors.green},
    {'value': 'error', 'label': 'Hata', 'icon': Icons.error, 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    try {
      final result = await _apiService.sendAdminNotification(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        targetUsers: _selectedTargetUsers,
        type: _selectedType,
      );

      if (mounted) {
        _showSnackBar(
          'Bildirim başarıyla gönderildi! ${result['sent_count']} kullanıcıya ulaştı.',
          isSuccess: true,
        );
        
        // Clear form
        _titleController.clear();
        _messageController.clear();
        setState(() {
          _selectedTargetUsers = ['all'];
          _selectedType = 'info';
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Bildirim gönderilemedi: $e', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppTheme.primaryBlue,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Bildirim Yönetimi',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryBlue,
                            AppTheme.primaryBlue.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.notifications,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Form Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Toplu Bildirim Gönder',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.grey800,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Title Field
                              EnhancedFormField(
                                controller: _titleController,
                                label: 'Başlık',
                                hintText: 'Bildirim başlığını girin',
                                prefixIcon: Icon(Icons.title),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Başlık gerekli';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Başlık en az 3 karakter olmalı';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Message Field
                              EnhancedFormField(
                                controller: _messageController,
                                label: 'Mesaj',
                                hintText: 'Bildirim mesajını girin',
                                prefixIcon: Icon(Icons.message),
                                maxLines: 4,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Mesaj gerekli';
                                  }
                                  if (value.trim().length < 10) {
                                    return 'Mesaj en az 10 karakter olmalı';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Target Users
                              Text(
                                'Hedef Kullanıcılar',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.grey800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _targetUserOptions.map((option) {
                                  final isSelected = _selectedTargetUsers.contains(option['value']);
                                  return FilterChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          option['icon'],
                                          size: 16,
                                          color: isSelected ? Colors.white : AppTheme.grey600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(option['label']),
                                      ],
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (option['value'] == 'all') {
                                          _selectedTargetUsers = ['all'];
                                        } else {
                                          _selectedTargetUsers.remove('all');
                                          if (selected) {
                                            _selectedTargetUsers.add(option['value']);
                                          } else {
                                            _selectedTargetUsers.remove(option['value']);
                                          }
                                          if (_selectedTargetUsers.isEmpty) {
                                            _selectedTargetUsers = ['all'];
                                          }
                                        }
                                      });
                                    },
                                    selectedColor: AppTheme.primaryBlue,
                                    checkmarkColor: Colors.white,
                                    backgroundColor: AppTheme.grey100,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // Notification Type
                              Text(
                                'Bildirim Türü',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.grey800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _typeOptions.map((option) {
                                  final isSelected = _selectedType == option['value'];
                                  return FilterChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          option['icon'],
                                          size: 16,
                                          color: isSelected ? Colors.white : option['color'],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(option['label']),
                                      ],
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedType = option['value'];
                                      });
                                    },
                                    selectedColor: option['color'],
                                    checkmarkColor: Colors.white,
                                    backgroundColor: AppTheme.grey100,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 32),

                              // Send Button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _isSending ? null : _sendNotification,
                                  icon: _isSending
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.send),
                                  label: Text(
                                    _isSending ? 'Gönderiliyor...' : 'Bildirim Gönder',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Preview Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.preview,
                                  color: AppTheme.primaryBlue,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Bildirim Önizlemesi',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.grey800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildNotificationPreview(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Guidelines Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.amber,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Bildirim Kuralları',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.grey800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildGuidelines(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationPreview() {
    final selectedType = _typeOptions.firstWhere(
      (type) => type['value'] == _selectedType,
      orElse: () => _typeOptions[0],
    );

    final targetCount = _selectedTargetUsers.contains('all') 
        ? 'Tüm kullanıcılar' 
        : _selectedTargetUsers.length == 1
            ? (_targetUserOptions.firstWhere((option) => option['value'] == _selectedTargetUsers[0])['label'] as String)
            : '${_selectedTargetUsers.length} kullanıcı grubu';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (selectedType['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  selectedType['icon'] as IconData,
                  color: selectedType['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleController.text.isEmpty ? 'Bildirim Başlığı' : _titleController.text,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _titleController.text.isEmpty ? AppTheme.grey500 : AppTheme.grey800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hedef: $targetCount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_messageController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.grey200),
              ),
              child: Text(
                _messageController.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grey800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuidelines() {
    final guidelines = [
      {
        'icon': Icons.info_outline,
        'title': 'Başlık ve Mesaj',
        'description': 'Başlık en az 3, mesaj en az 10 karakter olmalıdır.',
        'color': Colors.blue,
      },
      {
        'icon': Icons.people_outline,
        'title': 'Hedef Kullanıcılar',
        'description': 'Hedef kullanıcı grubunu dikkatli seçin. Tüm kullanıcılar seçildiğinde diğer seçimler iptal olur.',
        'color': Colors.green,
      },
      {
        'icon': Icons.palette_outlined,
        'title': 'Bildirim Türü',
        'description': 'Bildirim türü kullanıcıların dikkatini çekmek için önemlidir.',
        'color': Colors.orange,
      },
      {
        'icon': Icons.schedule,
        'title': 'Zamanlama',
        'description': 'Bildirimler anında gönderilir. Dikkatli olun.',
        'color': Colors.red,
      },
    ];

    return Column(
      children: guidelines.map((guideline) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (guideline['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                guideline['icon'] as IconData,
                color: guideline['color'] as Color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guideline['title'] as String,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    guideline['description'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}
