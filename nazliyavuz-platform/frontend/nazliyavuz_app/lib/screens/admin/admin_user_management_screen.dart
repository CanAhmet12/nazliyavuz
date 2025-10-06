import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/skeleton_loading.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _selectedFilter = 'all';
  String _selectedStatus = 'all';
  
  int _currentPage = 1;
  bool _hasMorePages = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
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
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterUsers();
  }

  void _filterUsers() {
    final searchQuery = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final role = user['role'] ?? '';
        
        final matchesSearch = name.contains(searchQuery) || email.contains(searchQuery);
        final matchesRole = _selectedFilter == 'all' || role == _selectedFilter;
        final matchesStatus = _selectedStatus == 'all' || 
            (_selectedStatus == 'active' && (user['status'] ?? 'active') == 'active') ||
            (_selectedStatus == 'suspended' && (user['status'] ?? 'active') == 'suspended');
        
        return matchesSearch && matchesRole && matchesStatus;
      }).toList();
    });
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          _currentPage = 1;
          _hasMorePages = true;
          _isLoading = true;
          _error = null;
        });
      } else if (_currentPage == 1) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      } else {
        setState(() {
          _isLoadingMore = true;
        });
      }

      final response = await _apiService.getAdminUsers(
        page: _currentPage,
        role: _selectedFilter == 'all' ? null : _selectedFilter,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      if (mounted) {
        setState(() {
          if (refresh || _currentPage == 1) {
            _users = (response['users'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          } else {
            _users.addAll((response['users'] as List?)?.cast<Map<String, dynamic>>() ?? []);
          }
          
          final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
          _hasMorePages = (pagination['current_page'] as int? ?? 0) < (pagination['last_page'] as int? ?? 0);
          _isLoading = false;
          _isLoadingMore = false;
        });

        _filterUsers();
        
        if (_currentPage == 1) {
          _animationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMorePages) return;
    
    _currentPage++;
    await _loadUsers();
  }

  Future<void> _suspendUser(int userId) async {
    try {
      await _apiService.suspendUser(userId, 'Admin tarafından askıya alındı');
      _showSnackBar('Kullanıcı askıya alındı', isSuccess: true);
      _loadUsers(refresh: true);
    } catch (e) {
      _showSnackBar('Kullanıcı askıya alınamadı: $e', isSuccess: false);
    }
  }

  Future<void> _unsuspendUser(int userId) async {
    try {
      await _apiService.unsuspendUser(userId);
      _showSnackBar('Kullanıcı askıdan kaldırıldı', isSuccess: true);
      _loadUsers(refresh: true);
    } catch (e) {
      _showSnackBar('Kullanıcı askıdan kaldırılamadı: $e', isSuccess: false);
    }
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          'Kullanıcı Yönetimi',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.grey800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _loadUsers(refresh: true),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Search and Filters
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.grey100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Kullanıcı ara...',
                              prefixIcon: const Icon(Icons.search),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildFilterChip('Rol', _selectedFilter, [
                        {'value': 'all', 'label': 'Tümü'},
                        {'value': 'student', 'label': 'Öğrenci'},
                        {'value': 'teacher', 'label': 'Öğretmen'},
                        {'value': 'admin', 'label': 'Admin'},
                      ], (value) {
                        setState(() {
                          _selectedFilter = value;
                        });
                        _filterUsers();
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Durum', _selectedStatus, [
                        {'value': 'all', 'label': 'Tümü'},
                        {'value': 'active', 'label': 'Aktif'},
                        {'value': 'suspended', 'label': 'Askıda'},
                      ], (value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                        _filterUsers();
                      }),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const SkeletonList(
                      itemCount: 10,
                      padding: EdgeInsets.all(16),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : _filteredUsers.isEmpty
                          ? _buildEmptyState()
                          : _buildUsersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String selectedValue, List<Map<String, String>> options, Function(String) onChanged) {
    return PopupMenuButton<String>(
      initialValue: selectedValue,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.grey300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.grey600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: AppTheme.grey600,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => options.map((option) => PopupMenuItem(
        value: option['value'],
        child: Row(
          children: [
            Icon(
              selectedValue == option['value'] ? Icons.check : null,
              size: 16,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(width: 8),
            Text(option['label']!),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Veri yüklenirken hata oluştu',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Bilinmeyen hata',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.grey600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadUsers(refresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppTheme.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'Kullanıcı bulunamadı',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.grey600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Arama kriterlerinizi değiştirerek tekrar deneyin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.grey500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: () => _loadUsers(refresh: true),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _filteredUsers.length + (_hasMorePages ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _filteredUsers.length) {
              return _buildLoadMoreIndicator();
            }
            
            final user = _filteredUsers[index];
            return _buildUserCard(user);
          },
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: _isLoadingMore
          ? const Center(child: CircularProgressIndicator())
          : TextButton(
              onPressed: _loadMoreUsers,
              child: const Text('Daha Fazla Yükle'),
            ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isSuspended = (user['status'] ?? 'active') == 'suspended';
    final role = user['role'] ?? 'student';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getRoleColor(role).withOpacity(0.1),
                  child: Text(
                    (user['name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: _getRoleColor(role),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'] ?? 'İsimsiz',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.grey800,
                              ),
                            ),
                          ),
                          _buildStatusChip(isSuspended),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleUserAction(value, user),
                  itemBuilder: (context) => [
                    if (isSuspended)
                      const PopupMenuItem(
                        value: 'unsuspend',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Askıdan Kaldır'),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'suspend',
                        child: Row(
                          children: [
                            Icon(Icons.pause_circle, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Askıya Al'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, color: AppTheme.primaryBlue),
                          SizedBox(width: 8),
                          Text('Detayları Görüntüle'),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // User Info
            Row(
              children: [
                _buildInfoChip(
                  _getRoleIcon(role),
                  _getRoleLabel(role),
                  _getRoleColor(role),
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.calendar_today,
                  '${DateFormat('dd MMM yyyy').format(DateTime.parse(user['created_at'] ?? DateTime.now().toIso8601String()))}',
                  AppTheme.grey600,
                ),
                if (user['teacher_status'] != null) ...[
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.school,
                    _getTeacherStatusLabel(user['teacher_status']),
                    _getTeacherStatusColor(user['teacher_status']),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isSuspended) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSuspended ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isSuspended ? 'Askıda' : 'Aktif',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isSuspended ? Colors.red : Colors.green,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'teacher':
        return Colors.green;
      case 'student':
        return Colors.blue;
      case 'admin':
        return Colors.purple;
      default:
        return AppTheme.grey600;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'teacher':
        return Icons.school;
      case 'student':
        return Icons.person;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'teacher':
        return 'Öğretmen';
      case 'student':
        return 'Öğrenci';
      case 'admin':
        return 'Admin';
      default:
        return 'Kullanıcı';
    }
  }

  String _getTeacherStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Onay Bekliyor';
      case 'approved':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      default:
        return 'Bilinmeyen';
    }
  }

  Color _getTeacherStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return AppTheme.grey600;
    }
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    final userId = user['id'];
    
    switch (action) {
      case 'suspend':
        _showSuspendDialog(userId, user['name']);
        break;
      case 'unsuspend':
        _showUnsuspendDialog(userId, user['name']);
        break;
      case 'view':
        _showUserDetails(user);
        break;
    }
  }

  void _showSuspendDialog(int userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Askıya Al'),
        content: Text('$userName kullanıcısını askıya almak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _suspendUser(userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Askıya Al'),
          ),
        ],
      ),
    );
  }

  void _showUnsuspendDialog(int userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Askıdan Kaldır'),
        content: Text('$userName kullanıcısını askıdan kaldırmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _unsuspendUser(userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Askıdan Kaldır'),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? 'Kullanıcı Detayları'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user['email'] ?? ''),
              _buildDetailRow('Rol', _getRoleLabel(user['role'] ?? '')),
              _buildDetailRow('Durum', (user['status'] ?? 'active') == 'active' ? 'Aktif' : 'Askıda'),
              _buildDetailRow('Kayıt Tarihi', DateFormat('dd MMM yyyy HH:mm').format(
                DateTime.parse(user['created_at'] ?? DateTime.now().toIso8601String())
              )),
              if (user['teacher_status'] != null)
                _buildDetailRow('Öğretmen Durumu', _getTeacherStatusLabel(user['teacher_status'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.grey600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}