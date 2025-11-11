import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

/// 🎯 PROFESYONEL MÜSAİDLİK YÖNETİM SİSTEMİ
/// Modern, kullanıcı dostu ve görsel takvim arayüzü
class WeeklyAvailabilityScreen extends StatefulWidget {
  const WeeklyAvailabilityScreen({super.key});

  @override
  State<WeeklyAvailabilityScreen> createState() => _WeeklyAvailabilityScreenState();
}

class _WeeklyAvailabilityScreenState extends State<WeeklyAvailabilityScreen> 
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  // 📊 Veri yapıları
  Map<String, List<Map<String, dynamic>>> _weeklyAvailability = {};
  bool _isLoading = false;
  String? _error;

  // 🎨 Animasyonlar
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // 📅 Gün isimleri ve sıralama
  final Map<String, String> _dayNames = {
    'monday': 'Pazartesi',
    'tuesday': 'Salı',
    'wednesday': 'Çarşamba',
    'thursday': 'Perşembe',
    'friday': 'Cuma',
    'saturday': 'Cumartesi',
    'sunday': 'Pazar',
  };


  final List<String> _daysOrder = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];

  // 🎨 Renkler
  final Map<String, Color> _dayColors = {
    'monday': Colors.blue,
    'tuesday': Colors.green,
    'wednesday': Colors.orange,
    'thursday': Colors.purple,
    'friday': Colors.red,
    'saturday': Colors.teal,
    'sunday': Colors.pink,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadWeeklyAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyAvailability() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.get('/teacher/availabilities');
      if (response['success'] == true && mounted) {
        // Backend'den gelen düz listeyi haftalık formata dönüştür
        final List<dynamic> availabilities = response['data'] ?? [];
        final Map<String, List<Map<String, dynamic>>> weeklyData = {};
        
        // Günleri başlat
        for (String day in _daysOrder) {
          weeklyData[day] = [];
        }
        
        // Verileri günlere göre grupla
        for (var availability in availabilities) {
          final dayOfWeek = availability['day_of_week'];
          if (weeklyData.containsKey(dayOfWeek)) {
            weeklyData[dayOfWeek]!.add(Map<String, dynamic>.from(availability));
          }
        }
        
        setState(() {
          _weeklyAvailability = weeklyData;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Müsaidlik verileri yüklenemedi: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern light background
      appBar: _buildModernAppBar(),
      body: _buildModernBody(),
      floatingActionButton: _buildModernFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Müsaitlik Takvimi',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22, color: Colors.black87),
            onPressed: _loadWeeklyAvailability,
            tooltip: 'Yenile',
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.analytics_rounded, size: 22, color: Colors.black87),
            onPressed: _showStatistics,
            tooltip: 'İstatistikler',
          ),
        ),
      ],
    );
  }

  Widget _buildModernBody() {
    if (_isLoading) {
      return _buildModernLoadingState();
    }

    if (_error != null) {
      return _buildModernErrorState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModernHeader(),
            const SizedBox(height: 24),
            _buildModernStatisticsCards(),
            const SizedBox(height: 24),
            _buildModernWeeklyCalendar(),
            const SizedBox(height: 100), // Bottom padding for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildModernLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Müsaitlik verileri yükleniyor...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Bir Hata Oluştu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: _loadWeeklyAvailability,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text(
                    'Tekrar Dene',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6), // AppTheme.primaryBlue
            Color(0xFF8B5CF6), // AppTheme.accentPurple
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Müsaitlik Takvimi',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Haftalık çalışma saatlerinizi yönetin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _showAddAvailabilityDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatisticsCards() {
    // Gerçek saat hesaplaması yap
    double totalHours = 0;
    for (var dayEntries in _weeklyAvailability.values) {
      for (var entry in dayEntries) {
        final startTime = entry['start_time'] as String?;
        final endTime = entry['end_time'] as String?;
        if (startTime != null && endTime != null) {
          try {
            final start = _parseTime(startTime);
            final end = _parseTime(endTime);
            if (start != null && end != null) {
              final minutes = end.difference(start).inMinutes;
              final hours = minutes / 60.0;
              totalHours += hours;
              // Debug log
              print('🕐 Debug: $startTime - $endTime = $minutes dakika = $hours saat');
            }
          } catch (e) {
            print('❌ Parse hatası: $e');
          }
        }
      }
    }
    
    print('📊 Toplam saat: $totalHours');
    
    final activeDays = _weeklyAvailability.entries
        .where((entry) => entry.value.isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Müsaitlik İstatistikleri',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildModernStatCard(
                  'Toplam Saat',
                  totalHours.toStringAsFixed(1),
                  Icons.schedule_rounded,
                  const Color(0xFF10B981),
                  'Bu hafta',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildModernStatCard(
                  'Aktif Günler',
                  activeDays.toString(),
                  Icons.calendar_today_rounded,
                  const Color(0xFF3B82F6),
                  'Bu hafta',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildModernStatCard(
                  'Ortalama',
                  activeDays > 0 ? (totalHours / activeDays).toStringAsFixed(1) : '0',
                  Icons.trending_up_rounded,
                  const Color(0xFF8B5CF6),
                  'Günlük saat',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  DateTime? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(2000, 1, 1, hour, minute);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Widget _buildModernStatCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernWeeklyCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Müsaitlik Takvimi',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        ..._daysOrder.map((day) => _buildModernDayCard(day)),
      ],
    );
  }

  String _getFullDateForDay(String day) {
    // Haftanın başlangıcını bul (Pazartesi)
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1; // Pazartesi = 1, Pazar = 7
    final monday = now.subtract(Duration(days: daysFromMonday));
    
    // Gün index'ini bul
    final dayIndexMap = {
      'monday': 0,
      'tuesday': 1,
      'wednesday': 2,
      'thursday': 3,
      'friday': 4,
      'saturday': 5,
      'sunday': 6,
    };
    
    final dayIndex = dayIndexMap[day] ?? 0;
    final targetDate = monday.add(Duration(days: dayIndex));
    
    // Türkçe tarih formatı: "31 Ekim 2025 Perşembe"
    final dateFormat = DateFormat('d MMMM yyyy EEEE', 'tr_TR');
    return dateFormat.format(targetDate);
  }

  Widget _buildModernDayCard(String day) {
    final slots = _weeklyAvailability[day] ?? [];
    final hasSlots = slots.isNotEmpty;
    final dayColor = _dayColors[day]!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: dayColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDayDetails(day, slots),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Gün İkonu - Anasayfa stili
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: dayColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: dayColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Gün Bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFullDateForDay(day),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (hasSlots) ...[
                        Text(
                          '${slots.length} müsaitlik saati',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildModernTimeSlots(slots),
                      ] else ...[
                        const Text(
                          'Müsaitlik yok',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Aksiyon Butonu
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: dayColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasSlots ? Icons.edit_rounded : Icons.add_rounded,
                    color: dayColor,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTimeSlots(List<Map<String, dynamic>> slots) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: slots.take(3).map((slot) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            '${slot['start_time']}-${slot['end_time']}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        );
      }).toList(),
    );
  }


  Widget _buildModernFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddAvailabilityDialog,
      backgroundColor: const Color(0xFF10B981),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text(
        'Müsaitlik Ekle',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showDayDetails(String day, List<Map<String, dynamic>> slots) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayDetailsBottomSheet(
        day: day,
        dayName: _dayNames[day]!,
        slots: slots,
        onEdit: (slot) => _editAvailability(slot),
        onDelete: (slotId) => _deleteAvailability(slotId),
        onAdd: () => _showAddSlotDialog(day),
      ),
    );
  }

  void _showAddAvailabilityDialog() {
    showDialog(
      context: context,
      builder: (context) => _AvailabilityDialog(
        onSave: (dayOfWeek, startTime, endTime) {
          _addAvailability(dayOfWeek, startTime, endTime);
        },
      ),
    );
  }

  void _showAddSlotDialog(String day) {
    showDialog(
      context: context,
      builder: (context) => _AvailabilityDialog(
        initialDayOfWeek: day,
        onSave: (dayOfWeek, startTime, endTime) {
          _addAvailability(dayOfWeek, startTime, endTime);
        },
      ),
    );
  }

  Future<void> _addAvailability(String dayOfWeek, String startTime, String endTime) async {
    try {
      await _apiService.addTeacherAvailability(dayOfWeek, startTime, endTime);
      _loadWeeklyAvailability();
      
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Müsaidlik başarıyla eklendi'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        String errorMessage = 'Hata: $e';
        
        if (e.toString().contains('Bu saat aralığında zaten bir uygunluk kaydı bulunmaktadır')) {
          errorMessage = '⚠️ Bu gün ve saat aralığında zaten bir müsaidlik kaydı var.\n\n💡 Çözüm önerileri:\n• Farklı saat aralığı seçin\n• Mevcut kaydı düzenleyin\n• Mevcut kaydı silin';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Anladım',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  void _editAvailability(Map<String, dynamic> slot) {
    Navigator.pop(context); // Bottom sheet'i kapat
    showDialog(
      context: context,
      builder: (context) => _AvailabilityDialog(
        initialDayOfWeek: slot['day_of_week'],
        onSave: (dayOfWeek, startTime, endTime) {
          _updateAvailability(slot['id'], dayOfWeek, startTime, endTime);
        },
      ),
    );
  }

  void _deleteAvailability(int slotId) {
    Navigator.pop(context); // Bottom sheet'i kapat
    _confirmDeleteAvailability(slotId);
  }

  Future<void> _updateAvailability(int slotId, String dayOfWeek, String startTime, String endTime) async {
    try {
      await _apiService.put('/teacher/availabilities/$slotId', {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      });
      _loadWeeklyAvailability();
      
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Müsaidlik başarıyla güncellendi'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Güncelleme hatası: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _confirmDeleteAvailability(int slotId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Müsaidlik Sil'),
        content: const Text('Bu müsaidlik kaydını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteAvailability(slotId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAvailability(int slotId) async {
    try {
      await _apiService.delete('/teacher/availabilities/$slotId');
      _loadWeeklyAvailability();
      
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 8),
                Text('Müsaidlik başarıyla silindi'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silme hatası: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }


  void _showStatistics() {
    showDialog(
      context: context,
      builder: (context) => _StatisticsDialog(
        weeklyAvailability: _weeklyAvailability,
      ),
    );
  }
}

/// 📊 Gün Detayları Bottom Sheet
class _DayDetailsBottomSheet extends StatelessWidget {
  final String day;
  final String dayName;
  final List<Map<String, dynamic>> slots;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;
  final VoidCallback onAdd;

  const _DayDetailsBottomSheet({
    required this.day,
    required this.dayName,
    required this.slots,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '$dayName Müsaidlikleri',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (slots.isEmpty) ...[
                  const Text(
                    'Bu gün için müsaidlik kaydı yok',
                    style: TextStyle(color: Colors.grey),
                  ),
                ] else ...[
                  ...slots.map((slot) => _buildSlotCard(slot)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Müsaidlik Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            '${slot['start_time']} - ${slot['end_time']}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => onEdit(slot),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            onPressed: () => onDelete(slot['id']),
          ),
        ],
      ),
    );
  }
}

/// 📈 İstatistikler Dialog
class _StatisticsDialog extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> weeklyAvailability;

  const _StatisticsDialog({required this.weeklyAvailability});

  @override
  Widget build(BuildContext context) {
    // Toplam saat sayısını hesapla
    double totalHours = 0;
    for (var dayEntries in weeklyAvailability.values) {
      for (var entry in dayEntries) {
        final startTime = entry['start_time'] as String?;
        final endTime = entry['end_time'] as String?;
        if (startTime != null && endTime != null) {
          try {
            final start = _parseTime(startTime);
            final end = _parseTime(endTime);
            if (start != null && end != null) {
              final hours = end.difference(start).inMinutes / 60.0;
              totalHours += hours;
            }
          } catch (e) {
            // Parse hatası varsa atlayalım
          }
        }
      }
    }
    
    final activeDays = weeklyAvailability.entries
        .where((entry) => entry.value.isNotEmpty)
        .length;

    return AlertDialog(
      title: const Text('📊 Müsaidlik İstatistikleri'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatRow('Toplam Müsaidlik Saati', totalHours.toStringAsFixed(1)),
          _buildStatRow('Aktif Gün Sayısı', activeDays.toString()),
          _buildStatRow('Ortalama Günlük Saat', 
            activeDays > 0 ? (totalHours / activeDays).toStringAsFixed(1) : '0'),
        ],
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
  
  DateTime? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(2000, 1, 1, hour, minute);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// 🎯 Müsaidlik Ekleme/Düzenleme Dialog
class _AvailabilityDialog extends StatefulWidget {
  final String? initialDayOfWeek;
  final Function(String dayOfWeek, String startTime, String endTime) onSave;

  const _AvailabilityDialog({
    this.initialDayOfWeek,
    required this.onSave,
  });

  @override
  State<_AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends State<_AvailabilityDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final Map<String, String> _dayNames = {
    'monday': 'Pazartesi',
    'tuesday': 'Salı',
    'wednesday': 'Çarşamba',
    'thursday': 'Perşembe',
    'friday': 'Cuma',
    'saturday': 'Cumartesi',
    'sunday': 'Pazar',
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDayOfWeek;
    
    // Initial times will be set to default values
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialDayOfWeek == null ? '➕ Müsaidlik Ekle' : '✏️ Müsaidlik Düzenle',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Calendar-style date selection that maps to day of week
            InkWell(
              onTap: () => _selectDateFromCalendar(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: Text(
                    _selectedDay != null ? _dayNames[_selectedDay!]! : '📅 Gün Seçin',
                    style: TextStyle(
                      color: _selectedDay != null ? Colors.black : Colors.grey[600],
                      fontWeight: _selectedDay != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: _selectedDay != null 
                      ? Text(
                          'Haftalık tekrarlayan müsaidlik',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        )
                      : null,
                  trailing: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('🕐 Başlangıç Saati'),
              subtitle: Text(_startTime?.format(context) ?? 'Saat seçin'),
              trailing: const Icon(Icons.access_time),
              onTap: _selectStartTime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('🕕 Bitiş Saati'),
              subtitle: Text(_endTime?.format(context) ?? 'Saat seçin'),
              trailing: const Icon(Icons.access_time),
              onTap: _selectEndTime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Kaydet'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _selectDateFromCalendar(BuildContext context) async {
    // Show date picker
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
      helpText: 'Müsaidlik günü seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Map selected date to day of week
      final String dayOfWeek = _mapDateToDayOfWeek(picked.weekday);
      setState(() {
        _selectedDay = dayOfWeek;
      });
    }
  }

  String _mapDateToDayOfWeek(int weekday) {
    // weekday: 1=Monday, 2=Tuesday, ..., 7=Sunday
    switch (weekday) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  void _save() {
    if (_formKey.currentState!.validate() && 
        _selectedDay != null && 
        _startTime != null && 
        _endTime != null) {
      
      if (_startTime!.hour >= _endTime!.hour) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Bitiş saati başlangıç saatinden sonra olmalıdır'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final startTimeStr = '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';
      
      widget.onSave(_selectedDay!, startTimeStr, endTimeStr);
      Navigator.of(context).pop();
    }
  }
}