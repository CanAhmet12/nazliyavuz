import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../main.dart';
import '../home/home_screen.dart';
import '../auth/forgot_password_screen.dart';
import 'register_screen.dart';
import '../../theme/app_theme.dart';
import '../../services/social_auth_service.dart';
import '../../models/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  
  // Simplified animations for better performance
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Reduced duration
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simplified curve
    ));
    
    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (kDebugMode) {
          print('🔐 [LOGIN_SCREEN] BlocConsumer received state: ${state.runtimeType}');
        }
        
        if (state is AuthAuthenticated) {
          // Giriş başarılı, ana sayfaya yönlendir
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        } else if (state is AuthError) {
          if (kDebugMode) {
            print('🔐 [LOGIN_SCREEN] AuthError received in main listener: ${state.message}');
            print('🔐 [LOGIN_SCREEN] AuthError action: ${state.action}');
            print('🔐 [LOGIN_SCREEN] About to show SnackBar...');
          }
          
          HapticFeedback.lightImpact();
          
          // Basit SnackBar test
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          
          if (kDebugMode) {
            print('🔐 [LOGIN_SCREEN] SnackBar shown successfully');
          }
        }
      },
      builder: (context, state) {
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // Logo ve Başlık
                      RepaintBoundary(child: _buildHeader()),

                      const SizedBox(height: 32),

                      // Form
                      RepaintBoundary(child: _buildForm()),

                      const SizedBox(height: 32),

                      // Sosyal Medya Girişi
                      RepaintBoundary(child: _buildSocialLogin()),

                      const SizedBox(height: 24),

                      // Kayıt Ol Linki
                      RepaintBoundary(child: _buildRegisterLink()),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
      },
    );
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
            debugPrint('❌ [LOGIN] Logo error: $error');
            return Icon(
              Icons.school_rounded,
              size: 120,
              color: AppTheme.primaryBlue,
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Title
        Text(
          'TERENCE EĞİTİM',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF093e7d),
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 12),
        
        // Subtitle
        Text(
          'Hesabınıza giriş yapın ve öğrenmeye devam edin',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.grey700,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // E-posta Alanı
          _buildEmailField(),
          
          const SizedBox(height: 20),
          
          // Şifre Alanı
          _buildPasswordField(),
          
          const SizedBox(height: 16),
          
          // Remember Me ve Forgot Password
          _buildRememberAndForgot(),
          
          const SizedBox(height: 24),
          
          // Giriş Butonu
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.premiumGold.withOpacity( 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'E-posta Adresi',
          hintText: 'ornek@email.com',
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.premiumGold.withOpacity( 0.2), AppTheme.primaryBlue.withOpacity( 0.2)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.email_outlined,
              color: AppTheme.primaryBlue,
              size: 22,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.premiumGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: TextStyle(
          color: AppTheme.grey600,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: AppTheme.grey400,
          fontSize: 14,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'E-posta adresi gerekli';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Geçerli bir e-posta adresi girin';
        }
        return null;
      },
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.premiumGold.withOpacity( 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
        labelText: 'Şifre',
        hintText: 'Şifrenizi girin',
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity( 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.lock_outlined,
            color: AppTheme.primaryBlue,
            size: 20,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppTheme.grey500,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        filled: true,
        fillColor: AppTheme.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.premiumGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: TextStyle(
          color: AppTheme.grey600,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: AppTheme.grey400,
          fontSize: 14,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Şifre gerekli';
        }
        if (value.length < 6) {
          return 'Şifre en az 6 karakter olmalı';
        }
        return null;
      },
      ),
    );
  }

  Widget _buildRememberAndForgot() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Remember Me
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: (value) {
                setState(() {
                  _rememberMe = value ?? false;
                });
              },
              activeColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text(
              'Beni Hatırla',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.grey700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        
        // Forgot Password
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ForgotPasswordScreen(),
              ),
            );
          },
          child: Text(
            'Şifremi Unuttum',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.grey300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: state is AuthLoading ? null : () {
                  if (kDebugMode) {
                    print('🔐 [LOGIN_SCREEN] Login button pressed');
                    print('🔐 [LOGIN_SCREEN] Form validation starting...');
                  }
                  
                  if (_formKey.currentState!.validate()) {
                    if (kDebugMode) {
                      print('✅ [LOGIN_SCREEN] Form validation passed');
                      print('🔐 [LOGIN_SCREEN] Email: ${_emailController.text.trim()}');
                      print('🔐 [LOGIN_SCREEN] Password length: ${_passwordController.text.length}');
                    }
                    
                    HapticFeedback.lightImpact();
                    
                    if (kDebugMode) {
                      print('🔐 [LOGIN_SCREEN] Calling AuthBloc.login...');
                    }
                    
                    context.read<AuthBloc>().add(AuthLoginRequested(
                          email: _emailController.text.trim(),
                          password: _passwordController.text,
                        ));
                  } else {
                    if (kDebugMode) {
                      print('❌ [LOGIN_SCREEN] Form validation failed');
                    }
                  }
                },
              child: Center(
                child: state is AuthLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.grey700),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.login_rounded,
                          color: AppTheme.grey700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Giriş Yap',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.grey700,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                ),
              ),
            ),
        );
      },
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppTheme.grey300,
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'veya',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grey500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppTheme.grey300,
                thickness: 1,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Social Login Buttons
        Row(
          children: [
            Expanded(
              child: _buildSocialButton(
                icon: Icons.g_mobiledata,
                label: 'Google',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await _handleGoogleLogin();
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
                  await _handleFacebookLogin();
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
        side: BorderSide(color: AppTheme.grey300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: AppTheme.grey700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.grey700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
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
                  Expanded(child: Text('Google ile giriş başarılı!')),
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
        print('❌ [LOGIN_SCREEN] Google login error: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Google girişi başarısız: ${e.toString()}')),
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

  Future<void> _handleFacebookLogin() async {
    try {
      // Facebook login implementation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Facebook girişi yakında aktif olacak!')),
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
        print('❌ [LOGIN_SCREEN] Facebook login error: $e');
      }
    }
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Hesabınız yok mu? ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.grey600,
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const RegisterScreen(),
              ),
            );
          },
          child: Text(
            'Kayıt Ol',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
