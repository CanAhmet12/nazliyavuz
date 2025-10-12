import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import 'email_verification_screen.dart';
import 'teacher_profile_completion_screen.dart';
import '../../services/social_auth_service.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'student';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Field bazında hata gösterimi
  void _showFieldErrors(Map<String, String> fieldErrors) {
    setState(() {
      // Form state'ini güncelle - field error'ları göster
      _formKey.currentState?.validate();
    });
    
    // Field error'larını logla
    if (kDebugMode) {
      print('📝 [REGISTER_SCREEN] Field errors: $fieldErrors');
    }
  }

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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),

                          // Logo ve Başlık
                          RepaintBoundary(child: _buildHeader()),

                          const SizedBox(height: 32),

                        // Ad Soyad Alanı
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.premiumGold.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Ad Soyad',
                              prefixIcon: Icon(Icons.person_outlined, color: AppTheme.premiumGold),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.grey300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.premiumGold, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ad soyad gerekli';
                              }
                              if (value.length < 2) {
                                return 'Ad soyad en az 2 karakter olmalı';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // E-posta Alanı
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.premiumGold.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'E-posta',
                              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.premiumGold),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.grey300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.premiumGold, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'E-posta adresi gerekli';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Geçerli bir e-posta adresi girin';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Rol Seçimi
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.premiumGold.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Rol',
                              prefixIcon: Icon(Icons.work_outlined, color: AppTheme.premiumGold),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.grey300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.premiumGold, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          items: const [
                            DropdownMenuItem(
                              value: 'student',
                              child: Text('Öğrenci'),
                            ),
                            DropdownMenuItem(
                              value: 'teacher',
                              child: Text('Öğretmen'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                        ),
                        ),
                        const SizedBox(height: 16),

                        // Şifre Alanı
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.premiumGold.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              prefixIcon: Icon(Icons.lock_outlined, color: AppTheme.premiumGold),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppTheme.premiumGold,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.grey300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.premiumGold, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Şifre gerekli';
                            }
                            if (value.length < 8) {
                              return 'Şifre en az 8 karakter olmalı';
                            }
                            return null;
                          },
                        ),
                        ),
                        const SizedBox(height: 16),

                        // Şifre Tekrar Alanı
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.premiumGold.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Şifre Tekrar',
                              prefixIcon: Icon(Icons.lock_outlined, color: AppTheme.premiumGold),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppTheme.premiumGold,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.grey300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.premiumGold, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Şifre tekrarı gerekli';
                            }
                            if (value != _passwordController.text) {
                              return 'Şifreler eşleşmiyor';
                            }
                            return null;
                          },
                        ),
                        ),
                        const SizedBox(height: 24),

                        // Kayıt Butonu
                        BlocConsumer<AuthBloc, AuthState>(
                          listener: (context, state) {
                            if (state is AuthRegistrationError) {
                              // Field bazında hata gösterimi
                              if (state.fieldErrors != null) {
                                _showFieldErrors(state.fieldErrors!);
                              }
                              
                              // Ana hata mesajı
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              state.message,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (state.action != null) ...[
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () {
                                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                            if (state.action!.contains('Giriş')) {
                                              Navigator.of(context).pop(); // Login sayfasına dön
                                            } else if (state.action!.contains('Tekrar')) {
                                              // Retry registration
                                              if (_formKey.currentState!.validate()) {
                                                context.read<AuthBloc>().add(AuthRegisterRequested(
                                                  name: _nameController.text.trim(),
                                                  email: _emailController.text.trim(),
                                                  password: _passwordController.text,
                                                  passwordConfirmation: _confirmPasswordController.text,
                                                  role: _selectedRole,
                                                ));
                                              }
                                            }
                                          },
                                          child: Text(
                                            state.action!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            } else if (state is AuthError) {
                              // Genel hatalar için AuthError dinle
                              if (kDebugMode) {
                                print('📝 [REGISTER_SCREEN] AuthError received: ${state.message}');
                              }
                              
                              HapticFeedback.lightImpact();
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              state.message,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (state.action != null) ...[
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () {
                                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                            if (state.action!.contains('Giriş')) {
                                              Navigator.of(context).pop(); // Login sayfasına dön
                                            } else if (state.action!.contains('Tekrar')) {
                                              // Retry registration
                                              if (_formKey.currentState!.validate()) {
                                                context.read<AuthBloc>().add(AuthRegisterRequested(
                                                  name: _nameController.text.trim(),
                                                  email: _emailController.text.trim(),
                                                  password: _passwordController.text,
                                                  passwordConfirmation: _confirmPasswordController.text,
                                                  role: _selectedRole,
                                                ));
                                              }
                                            }
                                          },
                                          child: Text(
                                            state.action!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            } else if (state is AuthUnauthenticated) {
                              // Registration successful, show email verification info
                              final authBloc = context.read<AuthBloc>();
                              final emailVerificationInfo = authBloc.emailVerificationInfo;
                              
                              if (emailVerificationInfo != null) {
                                final mailSent = emailVerificationInfo['mail_sent'] ?? false;
                                final message = emailVerificationInfo['message'] ?? '';
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      backgroundColor: mailSent ? Colors.green : Colors.orange,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          builder: (context, state) {
                            return Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF2D3748),
                                    const Color(0xFF4A5568),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2D3748).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: state is AuthLoading ? null : () async {
                                      if (kDebugMode) {
                                        print('📝 [REGISTER_SCREEN] Register button pressed');
                                        print('📝 [REGISTER_SCREEN] Form validation starting...');
                                      }
                                      
                                      if (_formKey.currentState!.validate()) {
                                        if (kDebugMode) {
                                          print('✅ [REGISTER_SCREEN] Form validation passed');
                                          print('📝 [REGISTER_SCREEN] Name: ${_nameController.text.trim()}');
                                          print('📝 [REGISTER_SCREEN] Email: ${_emailController.text.trim()}');
                                          print('📝 [REGISTER_SCREEN] Role: $_selectedRole');
                                          print('📝 [REGISTER_SCREEN] Password length: ${_passwordController.text.length}');
                                          print('📝 [REGISTER_SCREEN] Password confirmation length: ${_confirmPasswordController.text.length}');
                                        }
                                        
                                        try {
                                          if (kDebugMode) {
                                            print('📝 [REGISTER_SCREEN] Calling AuthBloc.register...');
                                          }
                                          
                                          context.read<AuthBloc>().add(AuthRegisterRequested(
                                                name: _nameController.text.trim(),
                                                email: _emailController.text.trim(),
                                                password: _passwordController.text,
                                                passwordConfirmation:
                                                    _confirmPasswordController.text,
                                                role: _selectedRole,
                                              ));

                                          if (kDebugMode) {
                                            print('✅ [REGISTER_SCREEN] Registration successful!');
                                          }

                                          if (mounted) {
                                            if (kDebugMode) {
                                              print('📱 [REGISTER_SCREEN] Navigating based on role...');
                                            }
                                            
                                            if (_selectedRole == 'teacher') {
                                              // Öğretmen için profil tamamlama sayfasına yönlendir
                                              Navigator.of(context).pushReplacement(
                                                MaterialPageRoute(
                                                  builder: (context) => TeacherProfileCompletionScreen(
                                                    name: _nameController.text.trim(),
                                                    email: _emailController.text.trim(),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              // Öğrenci için e-posta doğrulama ekranına yönlendir
                                              Navigator.of(context).pushReplacement(
                                                MaterialPageRoute(
                                                  builder: (context) => EmailVerificationScreen(
                                                    email: _emailController.text.trim(),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (kDebugMode) {
                                            print('❌ [REGISTER_SCREEN] Registration failed: $e');
                                          }
                                          // Hata durumunda AuthBloc zaten AuthError state'ini emit edecek
                                        }
                                      } else {
                                        if (kDebugMode) {
                                          print('❌ [REGISTER_SCREEN] Form validation failed');
                                        }
                                      }
                                    },
                                  child: Center(
                                    child: state is AuthLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            'Kayıt Ol',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Sosyal Medya Kayıt
                        RepaintBoundary(child: _buildSocialRegister()),

                        const SizedBox(height: 16),

                        // Giriş Yap Linki
                        RepaintBoundary(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Zaten hesabınız var mı? ',
                                style: TextStyle(color: AppTheme.grey600),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text(
                                  'Giriş Yap',
                                  style: TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialRegister() {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.grey[300],
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'veya',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.grey[300],
                thickness: 1,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Social Register Buttons
        Row(
          children: [
            Expanded(
              child: _buildSocialButton(
                icon: Icons.g_mobiledata,
                label: 'Google',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await _handleGoogleRegister();
                },
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: _buildSocialButton(
                icon: Icons.facebook,
                label: 'Facebook',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await _handleFacebookRegister();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        minimumSize: const Size(double.infinity, 48),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.grey[700],
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleRegister() async {
    try {
      final result = await SocialAuthService.signInWithGoogle();
      
      if (result != null && mounted) {
        final user = result['user'];
        if (user != null) {
          context.read<AuthBloc>().add(AuthUserChanged(User.fromJson(user)));
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Google ile kayıt başarılı!')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REGISTER_SCREEN] Google register error: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Google kaydı başarısız: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      }
    }
  }

  Future<void> _handleFacebookRegister() async {
    try {
      // Facebook register implementation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Facebook kaydı yakında aktif olacak!')),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REGISTER_SCREEN] Facebook register error: $e');
      }
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo - Sadece resim, çerçevesiz
        Image.asset(
          'assets/images/logo.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ [REGISTER] Logo error: $error');
            return Icon(
              Icons.school_rounded,
              size: 120,
              color: AppTheme.primaryBlue,
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Title
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [AppTheme.premiumGold, AppTheme.primaryBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
            child: Text(
              'TERENCE EĞİTİM',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
        ),
        
        const SizedBox(height: 8),
        
        // Subtitle
        Text(
          'Yeni hesabınızı oluşturun ve öğrenmeye başlayın',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.grey700,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

