import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

class AdminTeacherApprovalScreen extends StatefulWidget {
  const AdminTeacherApprovalScreen({super.key});

  @override
  State<AdminTeacherApprovalScreen> createState() => _AdminTeacherApprovalScreenState();
}

class _AdminTeacherApprovalScreenState extends State<AdminTeacherApprovalScreen> {
  final ApiService _apiService = ApiService();
  List<User> _pendingTeachers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPendingTeachers();
  }

  Future<void> _loadPendingTeachers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final teachers = await _apiService.getPendingTeachers();
      if (mounted) {
        setState(() {
          _pendingTeachers = teachers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveTeacher(User teacher) async {
    try {
      await _apiService.approveTeacher(teacher.id);
      
      if (mounted) {
        setState(() {
          _pendingTeachers.removeWhere((t) => t.id == teacher.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${teacher.name} onaylandı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Onaylama hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectTeacher(User teacher) async {
    String? rejectionReason;
    String? adminNotes;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _RejectTeacherDialog(teacher: teacher),
    );

    if (result != null) {
      rejectionReason = result['reason'];
      adminNotes = result['notes'];

      try {
        await _apiService.rejectTeacher(teacher.id, rejectionReason!, adminNotes: adminNotes);
        
        if (mounted) {
          setState(() {
            _pendingTeachers.removeWhere((t) => t.id == teacher.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${teacher.name} reddedildi'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reddetme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğretmen Onayları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingTeachers,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Hata: $_error',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPendingTeachers,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_pendingTeachers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Bekleyen öğretmen bulunmuyor',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tüm öğretmenler onaylanmış',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _pendingTeachers[index];
        return _buildTeacherCard(teacher);
      },
    );
  }

  Widget _buildTeacherCard(User teacher) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Öğretmen Bilgileri
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    teacher.name.isNotEmpty ? teacher.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.orange[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Beklemede',
                            style: TextStyle(
                              color: Colors.orange[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Teacher Detayları (eğer varsa)
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Profil Bilgileri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Öğretmen profili bekleniyor...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Aksiyon Butonları
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectTeacher(teacher),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reddet', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveTeacher(teacher),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Onayla', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
}

class _RejectTeacherDialog extends StatefulWidget {
  final User teacher;

  const _RejectTeacherDialog({required this.teacher});

  @override
  State<_RejectTeacherDialog> createState() => _RejectTeacherDialogState();
}

class _RejectTeacherDialogState extends State<_RejectTeacherDialog> {
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.teacher.name} Reddet'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Red Sebebi *',
                hintText: 'Öğretmeni neden reddediyorsunuz?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Red sebebi gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Admin Notları',
                hintText: 'Ek notlar (opsiyonel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'reason': _reasonController.text.trim(),
                'notes': _notesController.text.trim(),
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Reddet', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
