import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';

class CreateAssignmentScreen extends StatefulWidget {
  final User? student;

  const CreateAssignmentScreen({
    super.key,
    this.student,
  });

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _selectedDueDate;
  String _selectedDifficulty = 'medium';
  List<User> _students = [];
  int? _selectedStudentId;
  bool _isLoading = false;
  
  // PDF upload
  File? _selectedPdfFile;
  String? _pdfFileName;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _selectedStudentId = widget.student!.id;
    } else {
      _loadStudents();
    }
  }

  Future<void> _loadStudents() async {
    try {
      // Load teacher's students
      final students = await _apiService.getTeacherStudents();
      setState(() {
        _students = students;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading students: $e');
      }
    }
  }

  Future<void> _selectPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedPdfFile = File(result.files.single.path!);
          _pdfFileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error selecting PDF file: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF dosyası seçilirken hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removePdfFile() {
    setState(() {
      _selectedPdfFile = null;
      _pdfFileName = null;
    });
  }

  Future<void> _createAssignment() async {
    print('🔍 [CREATE_ASSIGNMENT] Starting assignment creation...');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ [CREATE_ASSIGNMENT] Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm alanları doldurun'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDueDate == null) {
      print('❌ [CREATE_ASSIGNMENT] Due date not selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen teslim tarihi seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedStudentId == null) {
      print('❌ [CREATE_ASSIGNMENT] Student not selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen öğrenci seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('🔍 [CREATE_ASSIGNMENT] Form data:');
    print('  - Student ID: $_selectedStudentId');
    print('  - Title: ${_titleController.text}');
    print('  - Description: ${_descriptionController.text}');
    print('  - Due Date: $_selectedDueDate');
    print('  - Difficulty: $_selectedDifficulty');

    setState(() {
      _isLoading = true;
    });

    try {
      print('🚀 [CREATE_ASSIGNMENT] Calling API...');
      
      final result = await _apiService.createAssignment(
        studentId: _selectedStudentId!,
        title: _titleController.text,
        description: _descriptionController.text,
        dueDate: _selectedDueDate!,
        difficulty: _selectedDifficulty,
      );

      print('✅ [CREATE_ASSIGNMENT] API response: $result');

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Ödev başarıyla oluşturuldu'),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ [CREATE_ASSIGNMENT] Error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Hata: $e')),
              ],
            ),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildFormSection(String title, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Yeni Ödev Oluştur',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.1),
                      AppTheme.primaryBlue.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.assignment_add,
                        size: 32,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Öğrencinize yeni bir ödev atayın',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Detayları doldurun ve ödevi oluşturun',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.grey600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Form Fields
              // Title Field
              _buildFormSection(
                'Ödev Başlığı',
                Icons.title_rounded,
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Ödev başlığını girin...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.grey300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.grey300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  style: const TextStyle(fontSize: 16),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Başlık gerekli';
                    }
                    return null;
                  },
                ),
              ),
              
              const SizedBox(height: 28),
              
              // Description Field
              _buildFormSection(
                'Ödev Açıklaması',
                Icons.description_rounded,
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Ödev açıklamasını detaylı olarak yazın...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.grey300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.grey300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  maxLines: 5,
                  style: const TextStyle(fontSize: 16),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Açıklama gerekli';
                    }
                    return null;
                  },
                ),
              ),
              
              const SizedBox(height: 28),
              
              // Student Selection and Difficulty - Side by Side (if not pre-selected)
              if (widget.student == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildFormSection(
                        'Öğrenci Seçimi',
                        Icons.person_rounded,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.grey300),
                          ),
                          child: DropdownButtonFormField<int>(
                            value: _selectedStudentId,
                            decoration: const InputDecoration(
                              hintText: 'Öğrenci seçin...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.grey800,
                            ),
                            dropdownColor: Colors.white,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.grey600,
                            ),
                            items: _students.map((student) => 
                              DropdownMenuItem<int>(
                                value: student.id,
                                child: Text(
                                  student.name,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStudentId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Öğrenci seçimi gerekli';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFormSection(
                        'Zorluk Seviyesi',
                        Icons.trending_up_rounded,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.grey300),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedDifficulty,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.grey800,
                            ),
                            dropdownColor: Colors.white,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.grey600,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'easy', 
                                child: Row(
                                  children: [
                                    Icon(Icons.trending_down, color: Colors.green, size: 16),
                                    SizedBox(width: 8),
                                    Text('Kolay'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'medium', 
                                child: Row(
                                  children: [
                                    Icon(Icons.trending_flat, color: Colors.orange, size: 16),
                                    SizedBox(width: 8),
                                    Text('Orta'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'hard', 
                                child: Row(
                                  children: [
                                    Icon(Icons.trending_up, color: Colors.red, size: 16),
                                    SizedBox(width: 8),
                                    Text('Zor'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedDifficulty = value!;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ] else ...[
                // Difficulty only if student is pre-selected
                _buildFormSection(
                  'Zorluk Seviyesi',
                  Icons.trending_up_rounded,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.grey300),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedDifficulty,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'easy', 
                          child: Row(
                            children: [
                              Icon(Icons.trending_down, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Text('Kolay'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'medium', 
                          child: Row(
                            children: [
                              Icon(Icons.trending_flat, color: Colors.orange, size: 16),
                              SizedBox(width: 8),
                              Text('Orta'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'hard', 
                          child: Row(
                            children: [
                              Icon(Icons.trending_up, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text('Zor'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDifficulty = value!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              // Due Date
              _buildFormSection(
                'Teslim Tarihi',
                Icons.schedule_rounded,
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: AppTheme.primaryBlue,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: AppTheme.grey800,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 23, minute: 59),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppTheme.primaryBlue,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: AppTheme.grey800,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setState(() {
                          _selectedDueDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppTheme.grey300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: _selectedDueDate != null ? AppTheme.primaryBlue : AppTheme.grey500,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedDueDate != null
                                ? DateFormat('dd MMM yyyy, HH:mm').format(_selectedDueDate!)
                                : 'Son Teslim Tarihi Seç',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedDueDate != null ? AppTheme.grey800 : AppTheme.grey500,
                              fontWeight: _selectedDueDate != null ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_selectedDueDate != null)
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.accentGreen,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              
              
              const SizedBox(height: 28),
              
              // PDF Upload Section
              _buildFormSection(
                'PDF Dosyası (Opsiyonel)',
                Icons.picture_as_pdf_rounded,
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.grey300),
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.grey50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ödev için PDF dosyası ekleyebilirsiniz',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_selectedPdfFile == null) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _selectPdfFile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppTheme.primaryBlue,
                                style: BorderStyle.solid,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: AppTheme.primaryBlue.withOpacity(0.08),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.upload_file_rounded,
                                    color: AppTheme.primaryBlue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'PDF Dosyası Seç',
                                  style: TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.accentGreen),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: AppTheme.accentGreen,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pdfFileName ?? 'PDF Dosyası',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'PDF dosyası seçildi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _removePdfFile,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppTheme.grey500,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Create Button
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentPurple,
                      AppTheme.primaryBlue,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentPurple.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAssignment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Ödev Oluşturuluyor...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_add,
                              size: 20,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Ödev Oluştur',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}