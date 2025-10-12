import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/teacher.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
// import '../../widgets/custom_widgets.dart'; // Temporarily unused

class CreateReservationScreen extends StatefulWidget {
  final Teacher teacher;
  final Category? preselectedCategory;

  const CreateReservationScreen({
    super.key,
    required this.teacher,
    this.preselectedCategory,
  });

  @override
  State<CreateReservationScreen> createState() => _CreateReservationScreenState();
}

class _CreateReservationScreenState extends State<CreateReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController();
  
  final ApiService _apiService = ApiService();
  
  Category? _selectedCategory;
  DateTime? _selectedDateTime;
  int _selectedDuration = 60; // Default 1 hour
  bool _isLoading = false;
  
  final List<int> _durationOptions = [30, 40, 60, 90, 120, 180, 240]; // 30 min to 4 hours

  // All subject suggestions by category
  final Map<String, List<String>> _allSubjectSuggestions = {
    'Matematik': [
      'Fonksiyonlar', 'Türev', 'İntegral', 'Trigonometri', 'Logaritma', 'Limit',
      'Analitik Geometri', 'Olasılık', 'İstatistik', 'Lineer Cebir', 'Diferansiyel Denklemler'
    ],
    'Fizik': [
      'Mekanik', 'Elektrik', 'Manyetizma', 'Optik', 'Termodinamik', 'Dalgalar',
      'Modern Fizik', 'Atom Fiziği', 'Nükleer Fizik', 'Katıhal Fiziği'
    ],
    'Kimya': [
      'Organik Kimya', 'İnorganik Kimya', 'Fizikokimya', 'Analitik Kimya', 'Biyokimya',
      'Polimer Kimyası', 'Çevre Kimyası', 'Endüstriyel Kimya'
    ],
    'Biyoloji': [
      'Hücre Biyolojisi', 'Genetik', 'Ekoloji', 'Anatomi', 'Fizyoloji',
      'Mikrobiyoloji', 'Botanik', 'Zooloji', 'Evrim', 'Moleküler Biyoloji'
    ],
    'Türkçe': [
      'Dil Bilgisi', 'Kompozisyon', 'Edebiyat', 'Türk Dili', 'Yazım Kuralları',
      'Noktalama', 'Kelime Bilgisi', 'Cümle Bilgisi'
    ],
    'İngilizce': [
      'Grammar', 'Speaking', 'Writing', 'Reading', 'Listening', 'IELTS',
      'TOEFL', 'YDS', 'Vocabulary', 'Pronunciation', 'Business English'
    ],
    'Almanca': [
      'Grammatik', 'Konversation', 'Schreiben', 'Lesen', 'Hören', 'Goethe-Zertifikat',
      'TestDaF', 'Wortschatz', 'Aussprache'
    ],
    'Fransızca': [
      'Grammaire', 'Conversation', 'Écriture', 'Lecture', 'Écoute', 'DELF',
      'DALF', 'Vocabulaire', 'Prononciation'
    ],
    'Tarih': [
      'Osmanlı Tarihi', 'Cumhuriyet Tarihi', 'Dünya Tarihi', 'Türk Tarihi',
      'Avrupa Tarihi', 'Orta Çağ Tarihi', 'Yakın Çağ Tarihi'
    ],
    'Coğrafya': [
      'Fiziki Coğrafya', 'Beşeri Coğrafya', 'Türkiye Coğrafyası', 'Dünya Coğrafyası',
      'Ekonomik Coğrafya', 'Siyasi Coğrafya', 'Çevre Coğrafyası'
    ],
    'Felsefe': [
      'Mantık', 'Etik', 'Metafizik', 'Epistemoloji', 'Estetik', 'Siyaset Felsefesi',
      'Din Felsefesi', 'Bilim Felsefesi'
    ],
    'Ekonomi': [
      'Mikroekonomi', 'Makroekonomi', 'İktisat Teorisi', 'Para ve Banka',
      'Uluslararası Ekonomi', 'Kalkınma Ekonomisi', 'Endüstriyel Ekonomi'
    ],
    'Programlama': [
      'Python', 'Java', 'C++', 'JavaScript', 'React', 'Flutter', 'Dart',
      'HTML/CSS', 'SQL', 'Node.js', 'Vue.js', 'Angular'
    ],
    'Müzik': [
      'Piyano', 'Gitar', 'Keman', 'Çello', 'Flüt', 'Saksafon', 'Davul',
      'Vokal', 'Kompozisyon', 'Müzik Teorisi', 'Armoni', 'Solfej'
    ],
    'Resim': [
      'Yağlı Boya', 'Sulu Boya', 'Karakalem', 'Pastel', 'Akrilik', 'Dijital Sanat',
      'Portre', 'Manzara', 'Soyut Sanat', 'Çizim Teknikleri'
    ],
    'Dans': [
      'Bale', 'Modern Dans', 'Hip-Hop', 'Latin Dansları', 'Salsa', 'Bachata',
      'Tango', 'Vals', 'Halk Dansları', 'Jazz Dans'
    ],
    'Spor': [
      'Futbol', 'Basketbol', 'Voleybol', 'Tenis', 'Yüzme', 'Koşu',
      'Fitness', 'Yoga', 'Pilates', 'Savunma Sanatları'
    ]
  };

  // Get filtered subject suggestions based on selected category
  List<String> get _subjectSuggestions {
    if (_selectedCategory == null) return [];
    
    final categoryName = _selectedCategory!.name;
    final subjects = _allSubjectSuggestions[categoryName] ?? [];
    
    // Return subjects with category prefix
    return subjects.map((subject) => '$categoryName - $subject').toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.preselectedCategory;
    _durationController.text = _selectedDuration.toString();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ders Rezervasyonu'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Teacher Info Card
              _buildTeacherInfoCard(),
              const SizedBox(height: 24),
              
              // Category Selection
              _buildSectionHeader('Ders Kategorisi', Icons.category_rounded),
              const SizedBox(height: 12),
              _buildCategorySelector(),
              const SizedBox(height: 24),
              
              // Subject Field
              _buildSectionHeader('Ders Konusu', Icons.book_rounded),
              const SizedBox(height: 12),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty || _selectedCategory == null) {
                    return const Iterable<String>.empty();
                  }
                  return _subjectSuggestions.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _subjectController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: _subjectController,
                    focusNode: focusNode,
                    enabled: _selectedCategory != null, // Only enable when category is selected
                    decoration: InputDecoration(
                      hintText: _selectedCategory == null 
                          ? 'Önce ders kategorisi seçin'
                          : 'Örn: ${_selectedCategory!.name} - ${_allSubjectSuggestions[_selectedCategory!.name]?.first ?? 'Konu'}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.book_rounded),
                      suffixIcon: _selectedCategory == null 
                          ? const Icon(Icons.lock_rounded, color: Colors.grey)
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ders konusu gerekli';
                      }
                      return null;
                    },
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
                        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
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
              const SizedBox(height: 24),
              
              // Date & Time Selection
              _buildSectionHeader('Tarih ve Saat', Icons.calendar_today_rounded),
              const SizedBox(height: 12),
              _buildDateTimeSelector(),
              const SizedBox(height: 24),
              
              // Duration Selection
              _buildSectionHeader('Ders Süresi', Icons.access_time_rounded),
              const SizedBox(height: 12),
              _buildDurationSelector(),
              const SizedBox(height: 24),
              
              // Notes (Optional)
              _buildSectionHeader('Notlar (İsteğe Bağlı)', Icons.note_rounded),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Öğretmene iletmek istediğiniz özel notlar...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.note_rounded),
                ),
              ),
              const SizedBox(height: 32),
              
              // Price Summary
              _buildPriceSummary(),
              const SizedBox(height: 24),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReservation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Rezervasyon Gönder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withValues(alpha: 0.1),
            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Profile Photo
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6),
                  const Color(0xFF8B5CF6),
                ],
              ),
            ),
            child: widget.teacher.user?.profilePhotoUrl == null
                ? Text(
                    (widget.teacher.displayName)[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.network(
                      widget.teacher.user!.profilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          (widget.teacher.displayName)[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          
          // Teacher Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teacher.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.teacher.specialization ?? 'Genel Eğitim',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFF3B82F6),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (widget.teacher.rating ?? widget.teacher.ratingAvg).toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₺${(widget.teacher.priceHour ?? 50).toStringAsFixed(0)}/sa',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF3B82F6),
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (widget.teacher.categories != null && widget.teacher.categories!.isNotEmpty)
            ...widget.teacher.categories!.map((category) {
              final isSelected = _selectedCategory?.id == category.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      // Clear subject when category changes
                      _subjectController.clear();
                    });
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected 
                            ? const Color(0xFF3B82F6)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList()
          else
            const Text(
              'Bu öğretmen için kategori bulunamadı',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedDateTime != null 
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedDateTime != null 
                            ? const Color(0xFF3B82F6)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: _selectedDateTime != null 
                              ? const Color(0xFF3B82F6)
                              : Colors.grey[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedDateTime != null
                                ? DateFormat('dd MMMM yyyy', 'tr').format(_selectedDateTime!)
                                : 'Tarih seçin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _selectedDateTime != null 
                                  ? const Color(0xFF3B82F6)
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _selectedDateTime != null ? _selectTime : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedDateTime != null 
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedDateTime != null 
                            ? const Color(0xFF3B82F6)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: _selectedDateTime != null 
                              ? const Color(0xFF3B82F6)
                              : Colors.grey[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedDateTime != null
                                ? DateFormat('HH:mm').format(_selectedDateTime!)
                                : 'Saat seçin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _selectedDateTime != null 
                                  ? const Color(0xFF3B82F6)
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedDateTime == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Önce tarih seçmelisiniz',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ders süresi: $_selectedDuration dakika',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durationOptions.map((duration) {
              final isSelected = _selectedDuration == duration;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDuration = duration;
                    _durationController.text = duration.toString();
                  });
                  HapticFeedback.lightImpact();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF3B82F6)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFF3B82F6)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    '${duration}dk',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary() {
    final price = (widget.teacher.priceHour ?? 50) * (_selectedDuration / 60);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.1),
            const Color(0xFF059669).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calculate_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Toplam Ücret',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '₺${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₺${(widget.teacher.priceHour ?? 50).toStringAsFixed(0)}/sa × ${(_selectedDuration / 60).toStringAsFixed(1)}sa',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = now;
    final lastDate = now.add(const Duration(days: 30)); // Max 30 days ahead

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now.add(const Duration(days: 1)),
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('tr', 'TR'),
    );

    if (selectedDate != null) {
      setState(() {
        _selectedDateTime = selectedDate;
      });
    }
  }

  Future<void> _selectTime() async {
    if (_selectedDateTime == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime!.year,
          _selectedDateTime!.month,
          _selectedDateTime!.day,
          selectedTime.hour,
          selectedTime.minute,
        );
      });
    }
  }

  Future<void> _submitReservation() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategory == null) {
      _showErrorSnackBar('Lütfen bir ders kategorisi seçin');
      return;
    }
    
    if (_selectedDateTime == null) {
      _showErrorSnackBar('Lütfen tarih ve saat seçin');
      return;
    }
    
    // Check if selected time is in the future
    if (_selectedDateTime!.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      _showErrorSnackBar('Rezervasyon en az 30 dakika sonra olmalıdır');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final reservationData = {
        'teacher_id': widget.teacher.userId,
        'category_id': _selectedCategory!.id,
        'subject': _subjectController.text.trim(),
        'proposed_datetime': _selectedDateTime!.toIso8601String(),
        'duration_minutes': _selectedDuration,
        'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      };

      await _apiService.createReservation(reservationData);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Rezervasyon oluşturulurken hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rezervasyon Gönderildi!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rezervasyon talebiniz öğretmene gönderildi. Onay bekliyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Dialog'u kapat
                  Navigator.of(context).pop(true); // Bu sayfayı kapat ve success döndür
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Tamam',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
