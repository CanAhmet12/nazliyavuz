import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// Öğretmen için izin/tatil yönetim ekranı
/// Özel günler, tatil dönemleri, izinli günler
class ExceptionManagementScreen extends StatefulWidget {
  const ExceptionManagementScreen({super.key});

  @override
  State<ExceptionManagementScreen> createState() => _ExceptionManagementScreenState();
}

class _ExceptionManagementScreenState extends State<ExceptionManagementScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _exceptions = [];
  bool _isLoading = false;
  String? _error;
  String _selectedFilter = 'future'; // future, past, all
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadExceptions();
  }

  void _initializeAnimations() {
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadExceptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final exceptions = await _apiService.getTeacherExceptions(filter: _selectedFilter);
      if (mounted) {
        setState(() {
          _exceptions = exceptions;
          _isLoading = false;
        });
        
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İzin verileri yüklenirken bir sorun oluştu.\nLütfen tekrar deneyin.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: _loadExceptions,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildModernAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _isLoading
              ? _buildModernLoadingState()
              : _error != null
                  ? _buildModernErrorState()
                  : _buildModernBody(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showAddExceptionDialog();
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      title: const Text(
        'İzin ve Tatil Yönetimi',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppTheme.grey900,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: AppTheme.grey900,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.2),
            ),
          ),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, color: AppTheme.primaryBlue),
            onSelected: (value) {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedFilter = value;
              });
              _loadExceptions();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'future',
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: AppTheme.primaryBlue, size: 18),
                    SizedBox(width: 8),
                    Text('Gelecek'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'past',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppTheme.grey600, size: 18),
                    SizedBox(width: 8),
                    Text('Geçmiş'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list_rounded, color: AppTheme.grey600, size: 18),
                    SizedBox(width: 8),
                    Text('Tümü'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.premiumGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'İzin verileri yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen bekleyin',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bağlantı Sorunu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İzin verileri yüklenirken bir sorun oluştu.\nLütfen tekrar deneyin.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.grey600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadExceptions,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tekrar Dene'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.help_outline_rounded, size: 18),
                  label: const Text('Yardım'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBody() {
    if (_exceptions.isEmpty) {
      return _buildModernEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exceptions.length,
      itemBuilder: (context, index) {
        final exception = _exceptions[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 100)),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: _buildExceptionCard(exception),
            );
          },
        );
      },
    );
  }

  Widget _buildModernEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentOrange.withOpacity(0.1),
                    AppTheme.accentPurple.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.beach_access_rounded,
                size: 50,
                color: AppTheme.accentOrange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Henüz izin/tatil kaydı yok',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tatil veya izinli olduğunuz günleri ekleyin',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExceptionCard(Map<String, dynamic> exception) {
    final type = exception['type'] as String;
    final isUnavailable = type == 'unavailable';
    
    final icon = isUnavailable ? Icons.event_busy_rounded : Icons.schedule_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            _showEditExceptionDialog(exception);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppTheme.premiumGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exception['formatted_date'] ?? exception['date'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isUnavailable)
                        Text(
                          exception['reason'] ?? 'Müsait değil',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.grey600,
                          ),
                        )
                      else
                        Text(
                          'Özel saatler: ${exception['start_time']} - ${exception['end_time']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.grey600,
                          ),
                        ),
                      if (exception['notes'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            exception['notes'],
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey500,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    HapticFeedback.lightImpact();
                    if (value == 'edit') {
                      _showEditExceptionDialog(exception);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(exception);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: AppTheme.primaryBlue),
                          SizedBox(width: 8),
                          Text('Düzenle'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Sil', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddExceptionDialog() {
    String exceptionType = 'unavailable';
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final reasonController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('İzin/Tatil Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type selection
                const Text('Tür', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'unavailable',
                      label: Text('Tam Gün İzin', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.event_busy, size: 16),
                    ),
                    ButtonSegment(
                      value: 'custom_hours',
                      label: Text('Özel Saatler', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.schedule, size: 16),
                    ),
                  ],
                  selected: {exceptionType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setDialogState(() {
                      exceptionType = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Date selection
                ListTile(
                  title: const Text('Tarih'),
                  subtitle: Text(selectedDate != null 
                      ? DateFormat('dd MMMM yyyy EEEE', 'tr').format(selectedDate!) 
                      : 'Tarih seçin'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                ),
                
                // Custom hours time selection
                if (exceptionType == 'custom_hours') ...[
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Başlangıç Saati'),
                    subtitle: Text(startTime?.format(context) ?? 'Saat seçin'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startTime = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Bitiş Saati'),
                    subtitle: Text(endTime?.format(context) ?? 'Saat seçin'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 17, minute: 0),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endTime = picked;
                        });
                      }
                    },
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Reason
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Sebep',
                    hintText: 'Örn: Tatilde, Hasta, Özel toplantı',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 255,
                ),
                const SizedBox(height: 8),
                
                // Notes
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notlar (Opsiyonel)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  maxLength: 500,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: selectedDate == null || 
                         (exceptionType == 'custom_hours' && (startTime == null || endTime == null))
                  ? null
                  : () {
                      Navigator.pop(context);
                      _addException(
                        exceptionType: exceptionType,
                        date: selectedDate!,
                        startTime: startTime,
                        endTime: endTime,
                        reason: reasonController.text.trim(),
                        notes: notesController.text.trim(),
                      );
                    },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }


  void _showEditExceptionDialog(Map<String, dynamic> exception) {
    // Implementation for editing
    // Similar to add dialog but with pre-filled data
  }

  void _showDeleteConfirmation(Map<String, dynamic> exception) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İzin Kaydını Sil'),
        content: Text(
          '${exception['formatted_date']} tarihli izin kaydını silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteException(exception['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _addException({
    required String exceptionType,
    required DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? reason,
    String? notes,
  }) async {
    if (date == null) return;
    
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      String? startTimeStr;
      String? endTimeStr;
      
      if (exceptionType == 'custom_hours' && startTime != null && endTime != null) {
        startTimeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
      }
      
      await _apiService.addTeacherException(
        exceptionDate: dateStr,
        type: exceptionType,
        startTime: startTimeStr,
        endTime: endTimeStr,
        reason: reason,
        notes: notes,
      );
      
      await _loadExceptions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İzin kaydı eklendi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  Future<void> _deleteException(int id) async {
    try {
      await _apiService.deleteTeacherException(id);
      await _loadExceptions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İzin kaydı silindi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

