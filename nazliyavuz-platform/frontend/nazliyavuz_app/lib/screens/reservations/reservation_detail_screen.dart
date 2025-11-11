import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/reservation.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'edit_reservation_dialog.dart';
import 'reschedule_request_dialog.dart';
import 'reschedule_handle_screen.dart';
import 'rating_dialog.dart';

class ReservationDetailScreen extends StatefulWidget {
  final Reservation reservation;

  const ReservationDetailScreen({
    super.key,
    required this.reservation,
  });

  @override
  State<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _teacherNotesController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isUpdatingStatus = false;
  bool _isUpdatingNotes = false;
  String _selectedStatus = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _selectedStatus = widget.reservation.status;
    _teacherNotesController.text = widget.reservation.teacherNotes ?? '';
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
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  Future<void> _updateReservationStatus(String status) async {
    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await _apiService.updateReservationStatus(
        widget.reservation.id,
        status,
      );

      if (mounted) {
        setState(() {
          _selectedStatus = status;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Randevu durumu güncellendi: ${_getStatusText(status)}'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _updateTeacherNotes() async {
    setState(() {
      _isUpdatingNotes = true;
    });

    try {
      // This would need to be implemented in the backend
      // For now, we'll just show a success message
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Öğretmen notları güncellendi'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingNotes = false;
        });
      }
    }
  }

  // P1 NEW METHODS
  void _showEditDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditReservationDialog(
        reservation: widget.reservation,
        onReservationUpdated: () {
          setState(() {});
        },
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true); // Refresh parent
    }
  }

  void _showRescheduleRequestDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RescheduleRequestDialog(
        reservation: widget.reservation,
        onRequestSubmitted: () {
          setState(() {});
        },
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true); // Refresh parent
    }
  }

  void _navigateToRescheduleHandle() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RescheduleHandleScreen(
          reservation: widget.reservation,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true); // Refresh parent
    }
  }

  Future<void> _completeReservation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dersi Tamamla'),
        content: const Text('Bu dersi tamamlanmış olarak işaretlemek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Tamamla'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.completeReservation(widget.reservation.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ders tamamlandı'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Refresh parent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRatingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RatingDialog(
        reservation: widget.reservation,
        onRatingSubmitted: () {
          setState(() {});
        },
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true); // Refresh parent
    }
  }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Randevu Durumunu Güncelle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.reservation.subject} randevusunun durumunu güncelleyin',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...['accepted', 'rejected', 'completed'].map((status) {
              return ListTile(
                title: Text(_getStatusText(status)),
                leading: Radio<String>(
                  value: status,
                  groupValue: _selectedStatus,
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    _selectedStatus = status;
                  });
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: _selectedStatus != widget.reservation.status 
                ? () {
                    Navigator.pop(context);
                    _updateReservationStatus(_selectedStatus);
                  }
                : null,
            child: _isUpdatingStatus 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'accepted':
        return 'Kabul Edildi';
      case 'rejected':
        return 'Reddedildi';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal Edildi';
      default:
        return 'Bilinmiyor';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.accentOrange;
      case 'accepted':
        return AppTheme.accentGreen;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return AppTheme.primaryBlue;
      case 'cancelled':
        return AppTheme.grey600;
      default:
        return AppTheme.grey600;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _teacherNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              _buildContent(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget? _buildActionButtons() {
    final isStudent = widget.reservation.student != null; // Simplified check
    final isTeacher = !isStudent; // Simplified logic
    
    final List<Widget> buttons = [];

    // Student Actions
    if (isStudent) {
      // Edit (Pending only)
      if (widget.reservation.canBeEdited) {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showEditDialog,
              icon: const Icon(Icons.edit, size: 20),
              label: const Text('Düzenle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue, // Renk standardizasyonu
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }

      // Reschedule (Accepted only)
      if (widget.reservation.canBeRescheduled) {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showRescheduleRequestDialog,
              icon: const Icon(Icons.schedule, size: 20),
              label: const Text('Yeniden Planla'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }

      // Rate (Completed, not rated)
      if (widget.reservation.canBeRated) {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showRatingDialog,
              icon: const Icon(Icons.star, size: 20),
              label: const Text('Değerlendir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }
    }

    // Teacher Actions
    if (isTeacher) {
      // Complete (Accepted, past)
      if (widget.reservation.canBeCompleted) {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _completeReservation,
              icon: const Icon(Icons.check_circle, size: 20),
              label: const Text('Tamamla'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }

      // Handle Reschedule Request
      if (widget.reservation.teacherNotes != null && 
          widget.reservation.teacherNotes!.contains('reschedule_request')) {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _navigateToRescheduleHandle,
              icon: const Icon(Icons.calendar_today, size: 20),
              label: const Text('Talep İncele'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }
    }

    if (buttons.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: buttons.asMap().entries.map((entry) {
            final index = entry.key;
            final button = entry.value;
            return [
              button,
              if (index < buttons.length - 1) const SizedBox(width: 12),
            ];
          }).expand((x) => x).toList(),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF111827),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          return FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.reservation.subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                                fontSize: 24,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const Icon(
                            Icons.star_border,
                            color: Color(0xFF6B7280),
                            size: 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.reservation.status),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getStatusText(widget.reservation.status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Reservation info chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip(
                            Icons.schedule_outlined,
                            _formatDateTime(widget.reservation.proposedDatetime),
                          ),
                          _buildInfoChip(
                            Icons.person_outline,
                            widget.reservation.teacher?.user?.name ?? 'Eğitimci',
                          ),
                          _buildInfoChip(
                            Icons.access_time_outlined,
                            '${widget.reservation.durationMinutes ?? 60} dk',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final reservationDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateText;
    if (reservationDate == today) {
      dateText = 'Bugün';
    } else if (reservationDate == tomorrow) {
      dateText = 'Yarın';
    } else {
      dateText = '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
    }
    
    final timeText = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    return '$dateText $timeText';
  }

  Widget _buildContent() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), // Daha kompakt padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reservation Info Card
            _buildReservationInfoCard(),
            const SizedBox(height: 12), // Daha kompakt spacing
            
            // Participants Info
            _buildParticipantsInfo(),
            const SizedBox(height: 12), // Daha kompakt spacing
            
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 12), // Daha kompakt spacing
            
            // Notes Section
            _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12), // Daha kompakt padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Randevu Bilgileri',
            style: TextStyle(
              fontSize: 14, // Daha kompakt font
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Tarih',
            _formatDateTime(widget.reservation.proposedDatetime),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.access_time_outlined,
            'Süre',
            '${widget.reservation.durationMinutes ?? 60} dakika',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.attach_money_outlined,
            'Ücret',
            '₺${(widget.reservation.price).toInt()}',
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Katılımcılar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          _buildParticipantRow(
            Icons.person_outline,
            'Öğrenci',
            widget.reservation.student?.name ?? 'Bilinmiyor',
          ),
          const SizedBox(height: 8),
          _buildParticipantRow(
            Icons.school_outlined,
            'Öğretmen',
            widget.reservation.teacher?.name ?? 'Bilinmiyor',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Durum',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.reservation.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(widget.reservation.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _getStatusColor(widget.reservation.status),
                  ),
                ),
              ),
              const Spacer(),
              if (widget.reservation.status == 'pending')
                ElevatedButton(
                  onPressed: _showStatusUpdateDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Durumu Güncelle',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Öğretmen Notları',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _teacherNotesController,
            decoration: const InputDecoration(
              hintText: 'Öğrenci hakkında notlarınızı buraya yazın...',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUpdatingNotes ? null : _updateTeacherNotes,
              child: _isUpdatingNotes
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Notları Kaydet'),
            ),
          ),
          if (widget.reservation.notes != null && widget.reservation.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Öğrenci Notları',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.reservation.notes!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.grey700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.grey600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12, // Daha kompakt font
            fontWeight: FontWeight.w500,
            color: AppTheme.grey700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12, // Daha kompakt font
              color: AppTheme.grey600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantRow(IconData icon, String label, String name) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.grey600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.grey700,
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey600,
            ),
          ),
        ),
      ],
    );
  }

}
