import 'package:flutter/material.dart';
import '../../widgets/custom_widgets.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FAQItem> _filteredFAQs = [];
  List<FAQItem> _allFAQs = [];

  @override
  void initState() {
    super.initState();
    _initializeFAQs();
    _searchController.addListener(() {
      _filterFAQs(_searchController.text);
    });
  }

  void _initializeFAQs() {
    _allFAQs = [
      FAQItem(
        category: 'Hesap',
        question: 'Hesabımı nasıl oluşturabilirim?',
        answer: 'Ana sayfadaki "Kayıt Ol" butonuna tıklayarak yeni bir hesap oluşturabilirsiniz. E-posta adresinizi ve güçlü bir şifre belirleyerek kayıt işlemini tamamlayabilirsiniz.',
      ),
      FAQItem(
        category: 'Hesap',
        question: 'Şifremi unuttum, nasıl sıfırlayabilirim?',
        answer: 'Giriş ekranındaki "Şifremi Unuttum" linkine tıklayarak e-posta adresinize şifre sıfırlama bağlantısı gönderebilirsiniz.',
      ),
      FAQItem(
        category: 'Öğretmen',
        question: 'Öğretmen profili nasıl oluştururum?',
        answer: 'Kayıt olurken "Öğretmen" seçeneğini işaretleyin. Kayıt sonrası profil tamamlama ekranından detaylarınızı girebilirsiniz.',
      ),
      FAQItem(
        category: 'Öğretmen',
        question: 'Ders ücretimi nasıl belirlerim?',
        answer: 'Profil düzenleme ekranından saatlik ders ücretinizi ayarlayabilirsiniz. Ücret belirlerken piyasa fiyatlarını göz önünde bulundurun.',
      ),
      FAQItem(
        category: 'Öğrenci',
        question: 'Öğretmen nasıl bulabilirim?',
        answer: 'Ana sayfadaki arama çubuğunu kullanarak öğretmen arayabilir, kategori ve fiyat filtrelerini uygulayabilirsiniz.',
      ),
      FAQItem(
        category: 'Öğrenci',
        question: 'Rezervasyon nasıl yaparım?',
        answer: 'Öğretmen profiline giderek "Rezervasyon Yap" butonuna tıklayın. Uygun tarih ve saat seçerek rezervasyonunuzu oluşturabilirsiniz.',
      ),
      FAQItem(
        category: 'Ödeme',
        question: 'Hangi ödeme yöntemlerini kabul ediyorsunuz?',
        answer: 'Kredi kartı, banka kartı ve 3D Secure ile güvenli ödeme yapabilirsiniz. Tüm ödemeler PayTR altyapısı ile korunmaktadır.',
      ),
      FAQItem(
        category: 'Ödeme',
        question: 'Ödeme güvenliği nasıl sağlanıyor?',
        answer: 'Tüm ödemeler SSL şifreleme ve 3D Secure ile korunmaktadır. Kart bilgileriniz sistemimizde saklanmaz.',
      ),
      FAQItem(
        category: 'Ders',
        question: 'Ders nasıl işlenir?',
        answer: 'Dersler video call üzerinden gerçekleşir. Rezervasyon saatinde öğretmeninizle bağlantı kurarak derse başlayabilirsiniz.',
      ),
      FAQItem(
        category: 'Ders',
        question: 'Ders kaydı alınır mı?',
        answer: 'Ders kayıtları öğrenci ve öğretmenin onayı ile alınabilir. Kayıtlar güvenli şekilde saklanır.',
      ),
      FAQItem(
        category: 'Teknik',
        question: 'Video call çalışmıyor, ne yapmalıyım?',
        answer: 'İnternet bağlantınızı kontrol edin. Tarayıcınızın kamera ve mikrofon izinlerini verdiğinizden emin olun.',
      ),
      FAQItem(
        category: 'Teknik',
        question: 'Mobil uygulamayı nasıl güncellerim?',
        answer: 'Play Store veya App Store üzerinden uygulamayı güncelleyebilirsiniz. Otomatik güncellemeler açık olmalıdır.',
      ),
    ];
    _filteredFAQs = _allFAQs;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yardım Merkezi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomWidgets.customTextField(
              controller: _searchController,
              hintText: 'Sorunuzu arayın...',
              prefixIcon: const Icon(Icons.search),
              label: 'Arama',
            ),
          ),
          
          // FAQ Categories
          _buildCategoryFilter(),
          
          // FAQ List
          Expanded(
            child: _filteredFAQs.isEmpty
                ? CustomWidgets.emptyState(
                    message: 'Arama sonucu bulunamadı',
                    icon: Icons.search_off,
                    subtitle: 'Farklı anahtar kelimeler deneyin',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredFAQs.length,
                    itemBuilder: (context, index) {
                      return _buildFAQItem(_filteredFAQs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = _allFAQs.map((faq) => faq.category).toSet().toList();
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCategoryChip('Tümü', _searchController.text.isEmpty);
          }
          final category = categories[index - 1];
          final isSelected = _searchController.text == category;
          return _buildCategoryChip(category, isSelected);
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (selected) {
              _searchController.text = label == 'Tümü' ? '' : label;
              _filterFAQs(_searchController.text);
            }
          });
        },
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue[600],
      ),
    );
  }

  Widget _buildFAQItem(FAQItem faq) {
    return CustomWidgets.customCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          faq.category,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              faq.answer,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _filterFAQs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFAQs = _allFAQs;
      } else {
        _filteredFAQs = _allFAQs.where((faq) {
          return faq.question.toLowerCase().contains(query.toLowerCase()) ||
                 faq.answer.toLowerCase().contains(query.toLowerCase()) ||
                 faq.category.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }
}

class FAQItem {
  final String category;
  final String question;
  final String answer;

  FAQItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}
