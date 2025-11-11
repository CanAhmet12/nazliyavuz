import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'email_verification_screen.dart';
import '../home/home_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final User user;
  final String token;

  const RoleSelectionScreen({
    Key? key,
    required this.user,
    required this.token,
  }) : super(key: key);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final ApiService _apiService = ApiService();
  String? _selectedRole;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.grey50,
              AppTheme.white,
              AppTheme.grey50,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Welcome message
                Text(
                  'Hoş geldiniz!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Merhaba ${widget.user.name}, hesabınızı tamamlamak için rolünüzü seçin.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.grey600,
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Role selection cards
                Expanded(
                  child: Column(
                    children: [
                      _buildRoleCard(
                        role: 'student',
                        title: 'Öğrenci',
                        subtitle: 'Öğretmenlerden ders almak istiyorum',
                        icon: Icons.school,
                        color: AppTheme.primary,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildRoleCard(
                        role: 'teacher',
                        title: 'Öğretmen',
                        subtitle: 'Öğrencilere ders vermek istiyorum',
                        icon: Icons.person_outline,
                        color: AppTheme.secondary,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedRole != null && !_isLoading
                        ? _handleRoleSelection
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Devam Et',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.grey300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected ? color : AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.white : AppTheme.grey600,
              ),
            ),
            
            const SizedBox(width: 20),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : AppTheme.grey900,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRoleSelection() async {
    if (_selectedRole == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        print('🎭 [ROLE_SELECTION] Setting role: $_selectedRole');
      }

      final response = await _apiService.setUserRole(_selectedRole!);
      
      if (kDebugMode) {
        print('✅ [ROLE_SELECTION] Role set successfully');
        print('✅ [ROLE_SELECTION] Next step: ${response['next_step']}');
      }

      if (mounted) {
        final nextStep = response['next_step'];
        
        if (nextStep == 'verify_email') {
          // Go to email verification
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                email: widget.user.email,
                fromSocialAuth: true,
              ),
            ),
          );
        } else if (nextStep == 'complete_teacher_profile') {
          // TODO: Go to teacher profile completion screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Öğretmen profili tamamlama ekranı yakında eklenecek'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          // Go to home screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ [ROLE_SELECTION] Role selection failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol seçimi başarısız: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
