import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/category.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../main.dart';

class TeacherProfileCompletionScreen extends StatefulWidget {
  final String name;
  final String email;

  const TeacherProfileCompletionScreen({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  State<TeacherProfileCompletionScreen> createState() => _TeacherProfileCompletionScreenState();
}

class _TeacherProfileCompletionScreenState extends State<TeacherProfileCompletionScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  int _currentStep = 0;
  final int _totalSteps = 4;
  
  // Form Controllers
  final _bioController = TextEditingController();
  final _priceController = TextEditingController();
  final _experienceController = TextEditingController();
  final _specializationController = TextEditingController();
  final _educationController = TextEditingController();
  final _certificationController = TextEditingController();
  final _languagesController = TextEditingController();
  
  // Form Data
  List<Category> _selectedCategories = [];
  List<String> _educationList = [];
  List<String> _certificationsList = [];
  List<String> _languagesList = [];
  bool _isOnlineAvailable = true;
  String _searchQuery = '';

  // API Data
  List<Category> _availableCategories = [];
  List<Category> _mainCategories = [];
  bool _isLoadingCategories = true;

  // Autocomplete Data
  final List<String> _subjectSuggestions = [
    'Matematik', 'Fizik', 'Kimya', 'Biyoloji', 'Türkçe', 'İngilizce', 'Almanca', 'Fransızca',
    'Tarih', 'Coğrafya', 'Felsefe', 'Sosyoloji', 'Psikoloji', 'Ekonomi', 'Muhasebe',
    'Bilgisayar Programlama', 'Web Tasarım', 'Grafik Tasarım', 'Müzik', 'Resim',
    'Spor', 'Yoga', 'Pilates', 'Dil Öğretimi', 'IELTS', 'TOEFL', 'YDS', 'KPSS',
    'ALES', 'DGS', 'TYT', 'AYT', 'LGS', 'OKS', 'ÖSS', 'YKS'
  ];

  final List<String> _educationSuggestions = [
    'İstanbul Üniversitesi', 'Boğaziçi Üniversitesi', 'Orta Doğu Teknik Üniversitesi',
    'Ankara Üniversitesi', 'Hacettepe Üniversitesi', 'Galatasaray Üniversitesi',
    'Sabancı Üniversitesi', 'Koç Üniversitesi', 'Bilkent Üniversitesi',
    'İstanbul Teknik Üniversitesi', 'Yıldız Teknik Üniversitesi', 'Marmara Üniversitesi',
    'Ege Üniversitesi', 'Dokuz Eylül Üniversitesi', 'Çukurova Üniversitesi',
    'Gazi Üniversitesi', 'Selçuk Üniversitesi', 'Erciyes Üniversitesi',
    'Karadeniz Teknik Üniversitesi', 'Atatürk Üniversitesi', 'MIT', 'Harvard',
    'Stanford', 'Oxford', 'Cambridge', 'Sorbonne', 'Heidelberg'
  ];

  final List<String> _certificationSuggestions = [
    'Öğretmenlik Sertifikası', 'Pedagojik Formasyon', 'TEFL', 'TESOL', 'CELTA',
    'IELTS Examiner', 'TOEFL Examiner', 'Microsoft Sertifikası', 'Google Sertifikası',
    'Adobe Sertifikası', 'Oracle Sertifikası', 'Cisco Sertifikası', 'CompTIA',
    'AWS Sertifikası', 'Azure Sertifikası', 'PMP Sertifikası', 'Six Sigma',
    'ISO 9001', 'ISO 27001', 'ITIL', 'Prince2', 'Scrum Master', 'Product Owner'
  ];

  final List<String> _languageSuggestions = [
    'Türkçe', 'İngilizce', 'Almanca', 'Fransızca', 'İspanyolca', 'İtalyanca',
    'Rusça', 'Arapça', 'Çince', 'Japonca', 'Korece', 'Portekizce', 'Hollandaca',
    'İsveççe', 'Norveççe', 'Danca', 'Fince', 'Lehçe', 'Çekçe', 'Macarca',
    'Rumence', 'Bulgarca', 'Sırpça', 'Hırvatça', 'Yunanca', 'İbranice'
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Reduced for better performance
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simplified curve for better performance
    ));
    _animationController.forward();
    _loadCategories();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _bioController.dispose();
    _priceController.dispose();
    _experienceController.dispose();
    _specializationController.dispose();
    _educationController.dispose();
    _certificationController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final apiService = ApiService();
      final categories = await apiService.getCategories();
      
      setState(() {
        _mainCategories = categories.where((cat) => cat.parentId == null).toList();
        _availableCategories = [];
        
        // Tüm alt kategorileri düz listede topla
        for (final mainCategory in _mainCategories) {
          if (mainCategory.children != null) {
            _availableCategories.addAll(mainCategory.children!);
          }
        }
        
        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Kategoriler yüklenirken hata: $e');
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        toolbarHeight: 50,
        leading: _currentStep > 0
            ? IconButton(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                color: AppTheme.grey700,
                padding: const EdgeInsets.all(8),
              )
            : null,
        title: Text(
          'Öğretmen Profili',
          style: TextStyle(
            color: AppTheme.grey900,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(),
          
          // Content
          Expanded(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentStep = index;
                      });
                      _animationController.reset();
                      _animationController.forward();
                    },
                    children: [
                      _buildPersonalInfoStep(),
                      _buildCategoriesStep(),
                      _buildExperienceStep(),
                      _buildPricingStep(),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Navigation Buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 6 : 0),
                  height: 3,
                  decoration: BoxDecoration(
                    color: index <= _currentStep
                        ? AppTheme.primaryBlue
                        : AppTheme.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Adım ${_currentStep + 1} / $_totalSteps',
            style: TextStyle(
              color: AppTheme.grey600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.accentPurple,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hoş geldin ${widget.name}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Öğretmen profilinizi tamamlayalım',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Bio Section
            _buildSectionHeader('Hakkınızda', Icons.description_rounded),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Kendinizi tanıtın, deneyimlerinizi paylaşın...',
                  hintStyle: TextStyle(color: AppTheme.grey500, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Specialization Section
            _buildSectionHeader('Uzmanlık Alanınız', Icons.school_rounded),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _subjectSuggestions.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _specializationController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: _specializationController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Örn: Matematik, İngilizce, Fizik...',
                      hintStyle: TextStyle(color: AppTheme.grey500, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      prefixIcon: Icon(Icons.work_rounded, color: AppTheme.primaryBlue, size: 20),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (value) {
                      controller.value = controller.value.copyWith(text: value);
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  option,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Online Availability
            _buildSectionHeader('Müsaitlik Durumu', Icons.online_prediction_rounded),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  Icon(
                    Icons.online_prediction_rounded,
                    color: _isOnlineAvailable ? AppTheme.primaryBlue : AppTheme.grey400,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Online Ders Veriyorum',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isOnlineAvailable ? AppTheme.grey900 : AppTheme.grey500,
                          ),
                        ),
                        Text(
                          'Öğrencilerle online ders yapabilirsiniz',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isOnlineAvailable,
                    onChanged: (value) {
                      setState(() {
                        _isOnlineAvailable = value;
                      });
                      HapticFeedback.lightImpact();
                    },
                    activeColor: AppTheme.primaryBlue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Ders Kategorileri', Icons.category_rounded),
          const SizedBox(height: 8),
          Text(
            'Önce ana kategori seçin, sonra verebileceğiniz dersleri seçin (en az 1)',
            style: TextStyle(
              color: AppTheme.grey600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Kategori ara...',
                hintStyle: TextStyle(color: AppTheme.grey500),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryBlue),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: AppTheme.grey500),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Selected Categories Count
          if (_selectedCategories.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedCategories.length} kategori seçildi',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: _isLoadingCategories
                ? const Center(child: CircularProgressIndicator())
                : _searchQuery.isEmpty
                    ? _buildHierarchicalCategories()
                    : _buildFilteredCategories(_availableCategories),
          ),
        ],
      ),
    );
  }


  Widget _buildExperienceStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Deneyim Bilgileri', Icons.work_history_rounded),
            const SizedBox(height: 24),
            
            // Experience Years
            _buildInputField(
              controller: _experienceController,
              label: 'Deneyim Süresi (Yıl)',
              hint: 'Örn: 5',
              icon: Icons.calendar_today_rounded,
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 24),
            
            // Education
            _buildSectionHeader('Eğitim Bilgileri', Icons.school_rounded),
            const SizedBox(height: 16),
            _buildListInput(
              controller: _educationController,
              label: 'Eğitim',
              hint: 'Üniversite, bölüm, yıl...',
              list: _educationList,
              suggestions: _educationSuggestions,
              onAdd: (value) {
                setState(() {
                  _educationList.add(value);
                  _educationController.clear();
                });
              },
              onRemove: (index) {
                setState(() {
                  _educationList.removeAt(index);
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Certifications
            _buildSectionHeader('Sertifikalar', Icons.verified_rounded),
            const SizedBox(height: 16),
            _buildListInput(
              controller: _certificationController,
              label: 'Sertifikalar',
              hint: 'Sertifika adı ve kurum...',
              list: _certificationsList,
              suggestions: _certificationSuggestions,
              onAdd: (value) {
                setState(() {
                  _certificationsList.add(value);
                  _certificationController.clear();
                });
              },
              onRemove: (index) {
                setState(() {
                  _certificationsList.removeAt(index);
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Languages
            _buildSectionHeader('Diller', Icons.language_rounded),
            const SizedBox(height: 16),
            _buildListInput(
              controller: _languagesController,
              label: 'Konuştuğunuz Diller',
              hint: 'Türkçe, İngilizce, Almanca...',
              list: _languagesList,
              suggestions: _languageSuggestions,
              onAdd: (value) {
                setState(() {
                  _languagesList.add(value);
                  _languagesController.clear();
                });
              },
              onRemove: (index) {
                setState(() {
                  _languagesList.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Fiyatlandırma', Icons.attach_money_rounded),
            const SizedBox(height: 24),
            
            // Price per Hour
            _buildInputField(
              controller: _priceController,
              label: 'Saatlik Ücret (₺)',
              hint: 'Örn: 50',
              icon: Icons.money_rounded,
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 24),
            
            // Pricing Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_rounded,
                    color: AppTheme.primaryBlue,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fiyatlandırma Önerileri',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Yeni başlayan öğretmenler: ₺30-50/sa\n'
                    '• Deneyimli öğretmenler: ₺50-80/sa\n'
                    '• Uzman öğretmenler: ₺80-150/sa\n'
                    '• Profesörler: ₺150+/sa',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Completion Summary
            _buildSectionHeader('Özet', Icons.checklist_rounded),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSummaryItem('Seçilen Kategoriler', '${_selectedCategories.length} kategori'),
                  const SizedBox(height: 12),
                  _buildSummaryItem('Deneyim', _experienceController.text.isEmpty ? 'Belirtilmemiş' : '${_experienceController.text} yıl'),
                  const SizedBox(height: 12),
                  _buildSummaryItem('Eğitim', '${_educationList.length} kayıt'),
                  const SizedBox(height: 12),
                  _buildSummaryItem('Sertifikalar', '${_certificationsList.length} sertifika'),
                  const SizedBox(height: 12),
                  _buildSummaryItem('Diller', '${_languagesList.length} dil'),
                  const SizedBox(height: 12),
                  _buildSummaryItem('Saatlik Ücret', _priceController.text.isEmpty ? 'Belirtilmemiş' : '₺${_priceController.text}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.grey500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildListInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> list,
    required Function(String) onAdd,
    required Function(int) onRemove,
    List<String>? suggestions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: suggestions != null ? Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return suggestions.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              controller.text = selection;
              if (selection.trim().isNotEmpty) {
                onAdd(selection.trim());
              }
            },
            fieldViewBuilder: (context, autocompleteController, focusNode, onFieldSubmitted) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  hintStyle: TextStyle(color: AppTheme.grey500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: Icon(Icons.add_rounded, color: AppTheme.primaryBlue),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.add_circle_rounded, color: AppTheme.primaryBlue),
                          onPressed: () {
                            if (controller.text.trim().isNotEmpty) {
                              onAdd(controller.text.trim());
                            }
                          },
                        )
                      : null,
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (value) {
                  autocompleteController.value = autocompleteController.value.copyWith(text: value);
                },
                onFieldSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    onAdd(value.trim());
                  }
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text(
                              option,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ) : TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.grey500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              prefixIcon: Icon(Icons.add_rounded, color: AppTheme.primaryBlue),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.add_circle_rounded, color: AppTheme.primaryBlue),
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          onAdd(controller.text.trim());
                        }
                      },
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 16),
            onFieldSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                onAdd(value.trim());
              }
            },
          ),
        ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item,
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onRemove(index),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppTheme.primaryBlue,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.grey600,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(color: AppTheme.grey300),
                ),
                child: const Text(
                  'Geri',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _canProceed() ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _currentStep == _totalSteps - 1 ? 'Profili Tamamla' : 'İleri',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _bioController.text.trim().isNotEmpty &&
               _specializationController.text.trim().isNotEmpty;
      case 1:
        return _selectedCategories.isNotEmpty;
      case 2:
        return _experienceController.text.trim().isNotEmpty;
      case 3:
        final priceText = _priceController.text.trim();
        if (priceText.isEmpty) return false;
        final price = double.tryParse(priceText);
        return price != null && price > 0;
      default:
        return false;
    }
  }

  void _nextStep() {
    // Validate current step before proceeding
    if (!_validateCurrentStep()) {
      _showValidationErrors();
      return;
    }
    
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeProfile();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _bioController.text.trim().isNotEmpty &&
               _specializationController.text.trim().isNotEmpty;
      case 1:
        return _selectedCategories.isNotEmpty;
      case 2:
        return _experienceController.text.trim().isNotEmpty;
      case 3:
        final priceText = _priceController.text.trim();
        if (priceText.isEmpty) return false;
        final price = double.tryParse(priceText);
        return price != null && price > 0;
      default:
        return false;
    }
  }

  void _showValidationErrors() {
    List<String> missingFields = [];
    
    switch (_currentStep) {
      case 0:
        if (_bioController.text.trim().isEmpty) {
          missingFields.add('Hakkında bilgisi');
        }
        if (_specializationController.text.trim().isEmpty) {
          missingFields.add('Uzmanlık alanı');
        }
        break;
      case 1:
        if (_selectedCategories.isEmpty) {
          missingFields.add('En az bir kategori seçimi');
        }
        break;
      case 2:
        if (_experienceController.text.trim().isEmpty) {
          missingFields.add('Deneyim bilgisi');
        }
        break;
      case 3:
        if (_priceController.text.trim().isEmpty) {
          missingFields.add('Saatlik ücret');
        }
        break;
    }
    
    if (missingFields.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Eksik Bilgiler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Lütfen aşağıdaki alanları doldurun:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.grey600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              ...missingFields.map((field) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      field,
                      style: TextStyle(
                        color: AppTheme.grey700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Tamam'),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeProfile() async {
    HapticFeedback.mediumImpact();
    
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              const Text(
                'Profil kaydediliyor...',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
      
      // Prepare data for API
      final profileData = {
        'bio': _bioController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'education': _educationList,
        'certifications': _certificationsList,
        'price_hour': double.tryParse(_priceController.text.trim()) ?? 50.0,
        'languages': _languagesList,
        'online_available': _isOnlineAvailable,
        'categories': _selectedCategories.map((cat) => cat.id).toList(),
      };
      
          // Make API call to save teacher profile
          await ApiService().createTeacherProfile(profileData);
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show success dialog
      _showSuccessDialog();
      
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error dialog
      _showErrorDialog(e.toString());
    }
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryBlue,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profil Tamamlandı!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Öğretmen profiliniz başarıyla oluşturuldu. Onay sürecinden sonra öğrenciler sizi görebilecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Dialog'u kapat
                  Navigator.of(context).pop(); // Bu sayfayı kapat
                  
                  // AuthBloc'u yenile ve ana sayfaya yönlendir
                  try {
                    // Kullanıcı profilini yeniden al
                    final updatedUser = await ApiService().getProfile();
                    
                    // AuthBloc'u güncelle
                    if (mounted) {
                      context.read<AuthBloc>().add(AuthUserChanged(updatedUser));
                    }
                  } catch (e) {
                    // Hata durumunda login ekranına yönlendir
                    if (mounted) {
                      context.read<AuthBloc>().add(AuthLogoutRequested());
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Ana Sayfaya Git',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_rounded,
                color: Colors.red,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hata Oluştu!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Profil kaydedilirken bir hata oluştu. Lütfen tekrar deneyin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Tamam',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchicalCategories() {
    return ListView.builder(
      itemCount: _mainCategories.length,
      itemBuilder: (context, index) {
        final mainCategory = _mainCategories[index];
        return _buildMainCategoryCard(mainCategory);
      },
    );
  }

  Widget _buildMainCategoryCard(Category mainCategory) {
    final children = mainCategory.children ?? [];
    final selectedChildrenCount = children.where((child) => _selectedCategories.contains(child)).length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getCategoryColor(mainCategory.slug).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(mainCategory.name),
            color: _getCategoryColor(mainCategory.slug),
            size: 24,
          ),
        ),
        title: Text(
          mainCategory.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: selectedChildrenCount > 0 
            ? Text(
                '$selectedChildrenCount ders seçildi',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              )
            : Text(
                mainCategory.description ?? 'Kategoriye ait dersler',
                style: TextStyle(color: AppTheme.grey600),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: children.map((category) {
                final isSelected = _selectedCategories.contains(category);
                return RepaintBoundary(
                  child: FilterChip(
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategories.add(category);
                      } else {
                        _selectedCategories.remove(category);
                      }
                    });
                    HapticFeedback.lightImpact();
                  },
                  selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryBlue,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String slug) {
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Green
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEF4444), // Red
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEC4899), // Pink
      const Color(0xFF84CC16), // Lime
    ];
    return colors[slug.hashCode.abs() % colors.length];
  }


  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'okul dersleri':
        return Icons.school_rounded;
      case 'fakülte dersleri':
        return Icons.account_balance_rounded;
      case 'yazılım':
        return Icons.code_rounded;
      case 'sağlık ve meditasyon':
        return Icons.health_and_safety_rounded;
      case 'spor':
        return Icons.sports_rounded;
      case 'dans':
        return Icons.music_note_rounded;
      case 'sınava hazırlık':
        return Icons.quiz_rounded;
      case 'müzik':
        return Icons.music_note_rounded;
      case 'kişisel gelişim':
        return Icons.psychology_rounded;
      case 'sanat ve hobiler':
        return Icons.palette_rounded;
      case 'direksiyon':
        return Icons.drive_eta_rounded;
      case 'tasarım':
        return Icons.design_services_rounded;
      case 'dijital pazarlama':
        return Icons.campaign_rounded;
      case 'matematik':
        return Icons.calculate_rounded;
      case 'ingilizce':
        return Icons.chat_rounded;
      case 'fizik':
        return Icons.science_rounded;
      case 'kimya':
        return Icons.biotech_rounded;
      case 'biyoloji':
        return Icons.eco_rounded;
      case 'tarih':
        return Icons.history_rounded;
      case 'coğrafya':
        return Icons.public_rounded;
      case 'edebiyat':
        return Icons.menu_book_rounded;
      case 'felsefe':
        return Icons.psychology_rounded;
      case 'resim':
        return Icons.brush_rounded;
      case 'bilgisayar':
        return Icons.computer_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildFilteredCategories(List<Category> categories) {
    final filteredCategories = categories.where((category) =>
        category.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        final isSelected = _selectedCategories.contains(category);
        final colors = [
          const Color(0xFF3B82F6),
          const Color(0xFF10B981),
          const Color(0xFF8B5CF6),
          const Color(0xFFF59E0B),
          const Color(0xFFEF4444),
          const Color(0xFF06B6D4),
        ];
        final color = colors[index % colors.length];
        
        return RepaintBoundary(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (isSelected) {
                  _selectedCategories.remove(category);
                } else {
                  _selectedCategories.add(category);
                }
              });
            },
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : color.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? color : Colors.grey).withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getCategoryIcon(category.name),
                  color: isSelected ? Colors.white : color,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  category.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Seçildi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}
