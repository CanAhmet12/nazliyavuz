import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_widgets.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedCategory = 'Genel';
  bool _isLoading = false;

  final List<String> _categories = [
    'Genel',
    'Teknik Sorun',
    'Hesap Sorunu',
    'Ödeme Sorunu',
    'Ders Sorunu',
    'Öğretmen Sorunu',
    'Öğrenci Sorunu',
    'Diğer',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İletişim'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Info Cards
            _buildContactInfoCards(),
            
            const SizedBox(height: 32),
            
            // Contact Form
            _buildContactForm(),
            
            const SizedBox(height: 32),
            
            // FAQ Link
            _buildFAQLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'İletişim Bilgileri',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Email Card
        _buildContactCard(
          icon: Icons.email,
          title: 'E-posta',
          subtitle: 'support@rotaakademi.com',
          color: Colors.blue,
          onTap: () => _launchEmail(),
        ),
        
        const SizedBox(height: 12),
        
        // Phone Card
        _buildContactCard(
          icon: Icons.phone,
          title: 'Telefon',
          subtitle: '+90 (212) 555 0123',
          color: Colors.green,
          onTap: () => _launchPhone(),
        ),
        
        const SizedBox(height: 12),
        
        // WhatsApp Card
        _buildContactCard(
          icon: Icons.chat,
          title: 'WhatsApp',
          subtitle: '+90 (212) 555 0123',
          color: Colors.green[600]!,
          onTap: () => _launchWhatsApp(),
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return CustomWidgets.customCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildContactForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mesaj Gönder',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        Form(
          key: _formKey,
          child: Column(
            children: [
              // Name Field
              CustomWidgets.customTextField(
                controller: _nameController,
                hintText: 'Ad Soyad',
                prefixIcon: const Icon(Icons.person),
                label: 'Ad Soyad',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ad soyad gereklidir';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Email Field
              CustomWidgets.customTextField(
                controller: _emailController,
                hintText: 'E-posta',
                prefixIcon: const Icon(Icons.email),
                label: 'E-posta',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'E-posta gereklidir';
                  }
                  if (!value.contains('@')) {
                    return 'Geçerli bir e-posta adresi girin';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Category Dropdown
              _buildCategoryDropdown(),
              
              const SizedBox(height: 16),
              
              // Subject Field
              CustomWidgets.customTextField(
                controller: _subjectController,
                hintText: 'Konu',
                prefixIcon: const Icon(Icons.subject),
                label: 'Konu',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Konu gereklidir';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Message Field
              CustomWidgets.customTextField(
                controller: _messageController,
                hintText: 'Mesajınız...',
                prefixIcon: const Icon(Icons.message),
                label: 'Mesaj',
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mesaj gereklidir';
                  }
                  if (value.length < 10) {
                    return 'Mesaj en az 10 karakter olmalıdır';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Send Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Mesaj Gönder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        hintText: 'Kategori Seçin',
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value!;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Kategori seçimi gereklidir';
        }
        return null;
      },
    );
  }

  Widget _buildFAQLink() {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/help-center');
        },
        icon: const Icon(Icons.help),
        label: const Text('Sık Sorulan Sorular'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue[600],
        ),
      ),
    );
  }

  Future<void> _launchEmail() async {
    // Fallback: Copy email to clipboard
    await Clipboard.setData(const ClipboardData(text: 'support@rotaakademi.com'));
    if (mounted) {
      CustomWidgets.showSnackbar(
        context: context,
        message: 'E-posta adresi panoya kopyalandı',
      );
    }
  }

  Future<void> _launchPhone() async {
    await Clipboard.setData(const ClipboardData(text: '+90 (212) 555 0123'));
    if (mounted) {
      CustomWidgets.showSnackbar(
        context: context,
        message: 'Telefon numarası panoya kopyalandı',
      );
    }
  }

  Future<void> _launchWhatsApp() async {
    CustomWidgets.showSnackbar(
      context: context,
      message: 'WhatsApp özelliği yakında aktif olacak',
    );
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        CustomWidgets.showSnackbar(
          context: context,
          message: 'Mesajınız başarıyla gönderildi. En kısa sürede dönüş yapacağız.',
        );
        
        // Clear form
        _nameController.clear();
        _emailController.clear();
        _subjectController.clear();
        _messageController.clear();
        setState(() {
          _selectedCategory = 'Genel';
        });
      }
    } catch (e) {
      if (mounted) {
        CustomWidgets.showSnackbar(
          context: context,
          message: 'Mesaj gönderilirken hata oluştu: ${e.toString()}',
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
