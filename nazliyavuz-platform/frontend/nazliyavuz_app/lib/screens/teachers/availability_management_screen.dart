import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AvailabilityManagementScreen extends StatefulWidget {
  const AvailabilityManagementScreen({super.key});

  @override
  State<AvailabilityManagementScreen> createState() => _AvailabilityManagementScreenState();
}

class _AvailabilityManagementScreenState extends State<AvailabilityManagementScreen> {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _availabilities = [];
  bool _isLoading = false;

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
    _loadAvailabilities();
  }

  Future<void> _loadAvailabilities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // API call to get availabilities
      final availabilities = await _apiService.getTeacherAvailabilities(1); // Teacher ID should be dynamic
      setState(() {
        _availabilities.clear();
        _availabilities.addAll(availabilities);
      });
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uygunluk Takvimi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddAvailabilityDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availabilities.isEmpty
              ? _buildEmptyState()
              : _buildAvailabilitiesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz uygunluk kaydı yok',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Öğrencilerin sizi rezerve edebilmesi için\nuygunluk saatlerinizi ekleyin',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddAvailabilityDialog,
            icon: const Icon(Icons.add),
            label: const Text('Uygunluk Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilitiesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availabilities.length,
      itemBuilder: (context, index) {
        final availability = _availabilities[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                _dayNames[availability['day_of_week']]?.substring(0, 1) ?? '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              _dayNames[availability['day_of_week']] ?? availability['day_of_week'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              availability['formatted_time_range'] ?? 
              '${availability['start_time']} - ${availability['end_time']}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditAvailabilityDialog(availability);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(availability);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Düzenle'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sil', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  void _showEditAvailabilityDialog(Map<String, dynamic> availability) {
    showDialog(
      context: context,
      builder: (context) => _AvailabilityDialog(
        initialDayOfWeek: availability['day_of_week'],
        initialStartTime: availability['start_time'],
        initialEndTime: availability['end_time'],
        onSave: (dayOfWeek, startTime, endTime) {
          _updateAvailability(availability['id'], dayOfWeek, startTime, endTime);
        },
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> availability) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uygunluk Kaydını Sil'),
        content: Text(
          '${_dayNames[availability['day_of_week']]} günü '
          '${availability['start_time']} - ${availability['end_time']} '
          'saatleri arasındaki uygunluk kaydını silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAvailability(availability['id']);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _addAvailability(String dayOfWeek, String startTime, String endTime) async {
    try {
      // API call to add availability
      await _apiService.addTeacherAvailability(dayOfWeek, startTime, endTime);
      _loadAvailabilities();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uygunluk kaydı başarıyla eklendi'),
            backgroundColor: Colors.green,
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
    }
  }

  Future<void> _updateAvailability(int id, String dayOfWeek, String startTime, String endTime) async {
    try {
      // API call to update availability
      await _apiService.updateTeacherAvailability(id, dayOfWeek, startTime, endTime);
      _loadAvailabilities();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uygunluk kaydı başarıyla güncellendi'),
            backgroundColor: Colors.green,
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
    }
  }

  Future<void> _deleteAvailability(int id) async {
    try {
      // API call to delete availability
      await _apiService.deleteTeacherAvailability(id);
      _loadAvailabilities();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uygunluk kaydı başarıyla silindi'),
            backgroundColor: Colors.green,
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
    }
  }
}

class _AvailabilityDialog extends StatefulWidget {
  final String? initialDayOfWeek;
  final String? initialStartTime;
  final String? initialEndTime;
  final Function(String dayOfWeek, String startTime, String endTime) onSave;

  const _AvailabilityDialog({
    this.initialDayOfWeek,
    this.initialStartTime,
    this.initialEndTime,
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

  final List<String> _daysOfWeek = [
    'monday',
    'tuesday', 
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

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
    
    if (widget.initialStartTime != null) {
      final parts = widget.initialStartTime!.split(':');
      _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    
    if (widget.initialEndTime != null) {
      final parts = widget.initialEndTime!.split(':');
      _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialDayOfWeek == null ? 'Uygunluk Ekle' : 'Uygunluk Düzenle'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedDay,
              decoration: const InputDecoration(
                labelText: 'Gün',
                border: OutlineInputBorder(),
              ),
              items: _daysOfWeek.map((day) {
                return DropdownMenuItem(
                  value: day,
                  child: Text(_dayNames[day]!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDay = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen bir gün seçin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Başlangıç Saati'),
              subtitle: Text(_startTime?.format(context) ?? 'Saat seçin'),
              trailing: const Icon(Icons.access_time),
              onTap: _selectStartTime,
            ),
            ListTile(
              title: const Text('Bitiş Saati'),
              subtitle: Text(_endTime?.format(context) ?? 'Saat seçin'),
              trailing: const Icon(Icons.access_time),
              onTap: _selectEndTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Kaydet'),
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

  void _save() {
    if (_formKey.currentState!.validate() && 
        _selectedDay != null && 
        _startTime != null && 
        _endTime != null) {
      
      if (_startTime!.hour >= _endTime!.hour) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitiş saati başlangıç saatinden sonra olmalıdır'),
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
