import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../models/teacher.dart';
import '../../models/category.dart';
import '../../theme/app_theme.dart';

class TeacherProfileFormScreen extends StatefulWidget {
  final Teacher? existingTeacher;

  const TeacherProfileFormScreen({
    super.key,
    this.existingTeacher,
  });

  @override
  State<TeacherProfileFormScreen> createState() => _TeacherProfileFormScreenState();
}

class _TeacherProfileFormScreenState extends State<TeacherProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Form controllers
  final _bioController = TextEditingController();
  final _priceController = TextEditingController();
  final _educationController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _languagesController = TextEditingController();
  
  // Form state
  List<Category> _categories = [];
  List<Category> _selectedCategories = [];
  List<String> _educationList = [];
  List<String> _certificationsList = [];
  List<String> _languagesList = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeForm();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _priceController.dispose();
    _educationController.dispose();
    _certificationsController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Kategoriler yüklenirken hata oluştu: $e');
    }
  }

  void _initializeForm() {
    if (widget.existingTeacher != null) {
      final teacher = widget.existingTeacher!;
      _bioController.text = teacher.bio ?? '';
      _priceController.text = teacher.priceHour?.toString() ?? '';
      _selectedCategories = teacher.categories ?? [];
      _educationList = List.from(teacher.education ?? []);
      _certificationsList = List.from(teacher.certifications ?? []);
      _languagesList = List.from(teacher.languages ?? []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.existingTeacher != null ? 'Profil Düzenle' : 'Öğretmen Profili',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        toolbarHeight: 50,
        centerTitle: true,
        actions: [
          if (widget.existingTeacher != null)
            IconButton(
              icon: const Icon(Icons.save_rounded, size: 20),
              onPressed: _isSubmitting ? null : _submitForm,
              padding: const EdgeInsets.all(8),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profil Bilgileri
                    _buildSectionCard(
                      'Profil Bilgileri',
                      [
                        _buildTextField(
                          controller: _bioController,
                          label: 'Hakkında',
                          hint: 'Kendinizi ve deneyimlerinizi kısaca anlatın',
                          maxLines: 4,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Hakkında bilgisi gerekli';
                            }
                            if (value.trim().length < 50) {
                              return 'En az 50 karakter olmalı';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _priceController,
                          label: 'Saatlik Ücret (TL)',
                          hint: 'Örn: 150',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Saatlik ücret gerekli';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Geçerli bir ücret girin';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kategoriler
                    _buildSectionCard(
                      'Uzmanlık Alanları',
                      [
                        Text(
                          'Hangi konularda ders verebiliyorsunuz?',
                          style: TextStyle(
                            color: AppTheme.grey600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _categories.map((category) {
                            final isSelected = _selectedCategories.any((c) => c.id == category.id);
                            return FilterChip(
                              label: Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
                              checkmarkColor: AppTheme.primaryBlue,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected ? AppTheme.primaryBlue : AppTheme.grey300,
                                width: 1,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.removeWhere((c) => c.id == category.id);
                                  }
                                });
                                HapticFeedback.lightImpact();
                              },
                            );
                          }).toList(),
                        ),
                        if (_selectedCategories.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'En az bir kategori seçmelisiniz',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Eğitim
                    _buildSectionCard(
                      'Eğitim Geçmişi',
                      [
                        Text(
                          'Aldığınız eğitimleri ve derecelerinizi ekleyin',
                          style: TextStyle(
                            color: AppTheme.grey600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildListInput(
                          controller: _educationController,
                          label: 'Eğitim',
                          hint: 'Örn: İstanbul Üniversitesi - Matematik Bölümü',
                          list: _educationList,
                          onAdd: (item) {
                            setState(() {
                              _educationList.add(item);
                            });
                          },
                          onRemove: (index) {
                            setState(() {
                              _educationList.removeAt(index);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        ..._educationList.asMap().entries.map((entry) {
                          return _buildListItem(
                            entry.value,
                            () => _educationList.removeAt(entry.key),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sertifikalar
                    _buildSectionCard(
                      'Sertifikalar',
                      [
                        Text(
                          'Sahip olduğunuz sertifikaları ekleyin',
                          style: TextStyle(
                            color: AppTheme.grey600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildListInput(
                          controller: _certificationsController,
                          label: 'Sertifika',
                          hint: 'Örn: Cambridge CELTA Sertifikası',
                          list: _certificationsList,
                          onAdd: (item) {
                            setState(() {
                              _certificationsList.add(item);
                            });
                          },
                          onRemove: (index) {
                            setState(() {
                              _certificationsList.removeAt(index);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        ..._certificationsList.asMap().entries.map((entry) {
                          return _buildListItem(
                            entry.value,
                            () => _certificationsList.removeAt(entry.key),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Diller
                    _buildSectionCard(
                      'Konuştuğu Diller',
                      [
                        Text(
                          'Hangi dillerde ders verebiliyorsunuz?',
                          style: TextStyle(
                            color: AppTheme.grey600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildListInput(
                          controller: _languagesController,
                          label: 'Dil',
                          hint: 'Örn: Türkçe, İngilizce',
                          list: _languagesList,
                          onAdd: (item) {
                            setState(() {
                              _languagesList.add(item);
                            });
                          },
                          onRemove: (index) {
                            setState(() {
                              _languagesList.removeAt(index);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        ..._languagesList.asMap().entries.map((entry) {
                          return _buildListItem(
                            entry.value,
                            () => _languagesList.removeAt(entry.key),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Kaydet Butonu
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                widget.existingTeacher != null ? 'Güncelle' : 'Profil Oluştur',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.grey500, fontSize: 14),
        labelStyle: TextStyle(color: AppTheme.grey600, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildListInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> list,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.grey500, fontSize: 14),
              labelStyle: TextStyle(color: AppTheme.grey600, fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.grey300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.grey300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 14),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                onAdd(value.trim());
                controller.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onAdd(controller.text.trim());
                controller.clear();
                HapticFeedback.lightImpact();
              }
            },
            padding: const EdgeInsets.all(8),
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(String text, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppTheme.grey900),
            ),
          ),
          GestureDetector(
            onTap: () {
              onRemove();
              HapticFeedback.lightImpact();
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red[600]!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.red[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      _showErrorSnackBar('En az bir kategori seçmelisiniz');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final data = {
        'bio': _bioController.text.trim(),
        'price_hour': double.parse(_priceController.text.trim()),
        'category_ids': _selectedCategories.map((c) => c.id).toList(),
        'education': _educationList,
        'certifications': _certificationsList,
        'languages': _languagesList,
      };

      if (widget.existingTeacher != null) {
        await _apiService.updateTeacherProfile(data);
      } else {
        await _apiService.createTeacherProfile(data);
      }

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar(
          widget.existingTeacher != null 
              ? 'Profil başarıyla güncellendi' 
              : 'Öğretmen profili başarıyla oluşturuldu'
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Hata: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
