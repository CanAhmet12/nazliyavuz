import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';
import 'admin_teacher_approval_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_reservations_screen.dart';
import 'admin_settings_screen.dart';

class AdminLayout extends StatefulWidget {
  final User user;

  const AdminLayout({super.key, required this.user});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSidebarExpanded = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<AdminMenuItem> _menuItems = [
    AdminMenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
      screen: const AdminDashboardScreen(),
    ),
    AdminMenuItem(
      title: 'Kullanıcı Yönetimi',
      icon: Icons.people_rounded,
      screen: const AdminUserManagementScreen(),
    ),
    AdminMenuItem(
      title: 'Öğretmen Onayları',
      icon: Icons.school_rounded,
      screen: const AdminTeacherApprovalScreen(),
    ),
    AdminMenuItem(
      title: 'Rezervasyonlar',
      icon: Icons.calendar_today_rounded,
      screen: const AdminReservationsScreen(),
    ),
    AdminMenuItem(
      title: 'Analitikler',
      icon: Icons.analytics_rounded,
      screen: const AdminAnalyticsScreen(),
    ),
    AdminMenuItem(
      title: 'Sistem Ayarları',
      icon: Icons.settings_rounded,
      screen: const AdminSettingsScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          children: [
            // Modern Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isMobile 
                  ? (_isSidebarExpanded ? screenWidth * 0.7 : 0)
                  : (_isSidebarExpanded ? 280 : 80),
              child: _buildModernSidebar(isMobile),
            ),
            
            // Main Content
            Expanded(
              child: Column(
                children: [
                  // Top Bar
                  _buildTopBar(isMobile),
                  
                  // Content Area
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _menuItems[_currentIndex].screen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSidebar(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_isSidebarExpanded) ...[
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      backgroundImage: widget.user.profilePhotoUrl != null
                          ? NetworkImage(widget.user.profilePhotoUrl!)
                          : null,
                      child: widget.user.profilePhotoUrl == null
                          ? Text(
                              widget.user.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Yönetici',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ] else ...[
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        widget.user.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Menu Items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = _currentIndex == index;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _currentIndex = index;
                          });
                          if (isMobile) {
                            setState(() {
                              _isSidebarExpanded = false;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.white.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                color: Colors.white,
                                size: 24,
                              ),
                              if (_isSidebarExpanded) ...[
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected 
                                          ? FontWeight.w700 
                                          : FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Footer
            if (_isSidebarExpanded)
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Divider(color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text(
                      'TERENCE EĞİTİM',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile || !_isSidebarExpanded)
            IconButton(
              onPressed: () {
                setState(() {
                  _isSidebarExpanded = !_isSidebarExpanded;
                });
              },
              icon: Icon(
                Icons.menu_rounded,
                color: AppTheme.primaryBlue,
              ),
            ),
          
          const SizedBox(width: 16),
          
          Text(
            _menuItems[_currentIndex].title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          
          const Spacer(),
          
          // Quick Actions
          Row(
            children: [
              _buildQuickActionButton(
                icon: Icons.notifications_rounded,
                onPressed: () {
                  // Show notifications
                },
              ),
              const SizedBox(width: 12),
              _buildQuickActionButton(
                icon: Icons.search_rounded,
                onPressed: () {
                  // Show search
                },
              ),
              const SizedBox(width: 12),
              _buildQuickActionButton(
                icon: Icons.settings_rounded,
                onPressed: () {
                  // Show settings
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: AppTheme.primaryBlue,
          size: 20,
        ),
      ),
    );
  }
}

class AdminMenuItem {
  final String title;
  final IconData icon;
  final Widget screen;

  AdminMenuItem({
    required this.title,
    required this.icon,
    required this.screen,
  });
}
