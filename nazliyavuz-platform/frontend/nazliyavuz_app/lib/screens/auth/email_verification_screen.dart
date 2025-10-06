import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_service.dart';
import '../../main.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String? verificationToken;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.verificationToken,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _tokenController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    if (widget.verificationToken != null) {
      _tokenController.text = widget.verificationToken!;
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-posta Doğrulama'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            RepaintBoundary(
              child: Text(
                'E-posta Adresinizi Doğrulayın',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Açıklama
            RepaintBoundary(
              child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.email,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bu e-posta adresine doğrulama linki gönderildi. Lütfen e-postanızı kontrol edin ve aşağıdaki alana doğrulama kodunu girin.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ),
            ),
            const SizedBox(height: 24),

            // Token Girişi
            Text(
              'Doğrulama Kodu',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(
                hintText: 'Doğrulama kodunu buraya girin',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.verified_user),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 24),

            // Doğrula Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'E-postayı Doğrula',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Yeniden Gönder
            Center(
              child: TextButton(
                onPressed: _isResending ? null : _resendVerification,
                child: _isResending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Doğrulama e-postasını yeniden gönder'),
              ),
            ),
            const SizedBox(height: 16),

            // Atla (Development için)
            if (widget.verificationToken != null)
              Center(
                child: TextButton(
                  onPressed: () {
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text(
                    'Şimdilik Atla (Development)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyEmail() async {
    if (_tokenController.text.trim().isEmpty) {
      _showErrorSnackBar('Lütfen doğrulama kodunu girin');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      await _apiService.verifyEmail(widget.email, _tokenController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-posta başarıyla doğrulandı!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Email doğrulaması başarılı - AuthBloc'u güncellea
        if (mounted) {
          // AuthBloc'u güncelle
          context.read<AuthBloc>().add(const AuthEmailVerified());
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('E-posta doğrulandı! Şimdi giriş yapabilirsiniz.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // 2 saniye bekle ve login ekranına yönlendir
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // E-posta zaten doğrulanmış hatası için özel durum
        if (e.toString().contains('ALREADY_VERIFIED') || e.toString().contains('zaten doğrulanmış')) {
          // AuthBloc'u güncelle
          context.read<AuthBloc>().add(const AuthEmailVerified());
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('E-posta zaten doğrulanmış! Ana sayfaya yönlendiriliyorsunuz...'),
              backgroundColor: Colors.orange,
            ),
          );
          // 2 saniye bekle ve login ekranına git
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            }
          });
        } else {
          _showErrorSnackBar('Doğrulama hatası: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isResending = true;
    });

    try {
      await _apiService.resendVerification(widget.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doğrulama e-postası yeniden gönderildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('E-posta gönderme hatası: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
