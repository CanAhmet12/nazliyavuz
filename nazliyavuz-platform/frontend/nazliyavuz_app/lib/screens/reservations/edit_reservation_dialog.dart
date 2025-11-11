import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reservation.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class EditReservationDialog extends StatefulWidget {
  final Reservation reservation;
  final VoidCallback? onReservationUpdated;

  const EditReservationDialog({
    Key? key,
    required this.reservation,
    this.onReservationUpdated,
  }) : super(key: key);

  @override
  State<EditReservationDialog> createState() => _EditReservationDialogState();
}

class _EditReservationDialogState extends State<EditReservationDialog> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _subjectController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late int _selectedDuration;
  
  bool _isSubmitting = false;

  final List<int> _durationOptions = [30, 45, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.reservation.subject);
    _notesController = TextEditingController(text: widget.reservation.notes ?? '');
    _selectedDate = widget.reservation.proposedDatetime;
    _selectedDuration = widget.reservation.durationMinutes ?? 60;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDate.isAfter(now) ? _selectedDate : now.add(const Duration(hours: 3));
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('tr', 'TR'),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );

    if (time == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if minimum 2 hours notice
    final now = DateTime.now();
    final minimumTime = now.add(const Duration(hours: 2));
    
    if (_selectedDate.isBefore(minimumTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ Rezervasyon en az 2 saat önceden yapılmalıdır'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = <String, dynamic>{};
      
      if (_subjectController.text.trim() != widget.reservation.subject) {
        data['subject'] = _subjectController.text.trim();
      }
      
      if (_selectedDate != widget.reservation.proposedDatetime) {
        data['proposed_datetime'] = _selectedDate.toIso8601String();
      }
      
      if (_selectedDuration != widget.reservation.durationMinutes) {
        data['duration_minutes'] = _selectedDuration;
      }
      
      if (_notesController.text.trim() != (widget.reservation.notes ?? '')) {
        data['notes'] = _notesController.text.trim();
      }

      if (data.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      await _apiService.updateReservation(widget.reservation.id, data);

      if (!mounted) return;

      Navigator.pop(context, true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Rezervasyon güncellendi'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onReservationUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = e.toString();
      if (errorMessage.contains('RESERVATION_CONFLICT')) {
        errorMessage = 'Öğretmen seçtiğiniz tarihte başka bir derse sahip';
      } else if (errorMessage.contains('TOO_CLOSE')) {
        errorMessage = 'Rezervasyon en az 2 saat önceden yapılmalıdır';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teacherName = widget.reservation.teacher?.user?.name ?? 'Öğretmen';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16), // Daha kompakt padding
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8), // Daha kompakt
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.2), // Renk standardizasyonu
                          borderRadius: BorderRadius.circular(8), // Daha küçük radius
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: AppTheme.primaryBlue, // Renk standardizasyonu
                          size: 20, // Daha küçük icon
                        ),
                      ),
                      const SizedBox(width: 12), // Daha kompakt spacing
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rezervasyonu Düzenle',
                              style: theme.textTheme.titleMedium?.copyWith( // Daha küçük title
                                fontWeight: FontWeight.bold,
                                fontSize: 16, // Daha kompakt font
                              ),
                            ),
                            const SizedBox(height: 2), // Daha kompakt spacing
                            Text(
                              teacherName,
                              style: theme.textTheme.bodySmall?.copyWith( // Daha küçük body
                                color: Colors.grey[600],
                                fontSize: 12, // Daha kompakt font
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Subject Field
                  TextFormField(
                    controller: _subjectController,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'Konu',
                      prefixIcon: const Icon(Icons.book),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Konu boş olamaz';
                      }
                      if (value.trim().length < 3) {
                        return 'Konu en az 3 karakter olmalıdır';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Date & Time Selector
                  InkWell(
                    onTap: _isSubmitting ? null : _selectDateTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tarih & Saat',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(_selectedDate),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Duration Selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Süre',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _durationOptions.map((duration) {
                          final isSelected = _selectedDuration == duration;
                          return ChoiceChip(
                            label: Text(_formatDuration(duration)),
                            selected: isSelected,
                            onSelected: _isSubmitting ? null : (selected) {
                              if (selected) {
                                setState(() => _selectedDuration = duration);
                              }
                            },
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Notes Field
                  TextFormField(
                    controller: _notesController,
                    enabled: !_isSubmitting,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Notlar (Opsiyonel)',
                      prefixIcon: const Icon(Icons.notes),
                      hintText: 'Eklemek istediğiniz notlar...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Değişiklikler öğretmeninize bildirilecektir',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('İptal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitUpdate,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save, size: 20),
                                    SizedBox(width: 8),
                                    Text('Kaydet'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes dk';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours saat';
    }
    return '$hours sa $remainingMinutes dk';
  }
}

