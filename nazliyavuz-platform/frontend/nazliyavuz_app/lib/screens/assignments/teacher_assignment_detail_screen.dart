import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/assignment.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class TeacherAssignmentDetailScreen extends StatefulWidget {
  final Assignment assignment;

  const TeacherAssignmentDetailScreen({
    super.key,
    required this.assignment,
  });

  @override
  State<TeacherAssignmentDetailScreen> createState() => _TeacherAssignmentDetailScreenState();
}

class _TeacherAssignmentDetailScreenState extends State<TeacherAssignmentDetailScreen> {
  // ApiService will be used for grade submission API calls
  final _gradeController = TextEditingController();
  final _feedbackController = TextEditingController();
  
  bool _isGrading = false;
  String? _selectedGrade;
  final List<String> _gradeOptions = ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D', 'F'];

  @override
  void initState() {
    super.initState();
    if (widget.assignment.grade != null) {
      _selectedGrade = widget.assignment.grade;
    }
    if (widget.assignment.feedback != null) {
      _feedbackController.text = widget.assignment.feedback!;
    }
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.assignment.status);
    final isOverdue = widget.assignment.dueDate.isBefore(DateTime.now()) && 
                      widget.assignment.status != 'graded' && 
                      widget.assignment.status != 'submitted';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödev Detayı'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (widget.assignment.status == 'submitted')
            IconButton(
              icon: const Icon(Icons.grade_rounded),
              onPressed: _showGradingDialog,
              tooltip: 'Değerlendir',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withOpacity(0.1),
                    statusColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getStatusIcon(widget.assignment.status),
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.assignment.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.assignment.grade != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.premiumGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.assignment.grade!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.premiumGold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.person_rounded,
                        'Öğrenci: ${widget.assignment.studentName ?? "Bilinmiyor"}',
                        AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.schedule_rounded,
                        'Teslim: ${_formatDate(widget.assignment.dueDate)}',
                        isOverdue ? Colors.red : AppTheme.accentGreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoChip(
                    _getStatusIcon(widget.assignment.status),
                    _getStatusText(widget.assignment.status),
                    statusColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Assignment Description
            _buildSection(
              'Ödev Açıklaması',
              Icons.description_rounded,
              widget.assignment.description,
            ),

            const SizedBox(height: 20),

            // Difficulty Level
            _buildSection(
              'Zorluk Seviyesi',
              Icons.trending_up_rounded,
              _getDifficultyText(widget.assignment.difficulty),
            ),

            const SizedBox(height: 20),

            // Submission Details (if submitted)
            if (widget.assignment.status == 'submitted' || widget.assignment.status == 'graded')
              _buildSubmissionSection(),

            const SizedBox(height: 20),

            // Grading Section (if graded)
            if (widget.assignment.status == 'graded')
              _buildGradingSection(),

            const SizedBox(height: 20),

            // Action Buttons
            if (widget.assignment.status == 'submitted')
              _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.grey300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryBlue),
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
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.grey600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upload_rounded, size: 20, color: AppTheme.accentGreen),
              const SizedBox(width: 8),
              Text(
                'Teslim Detayları',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.assignment.submittedAt != null)
            _buildInfoChip(
              Icons.access_time_rounded,
              'Teslim Tarihi: ${_formatDateTime(widget.assignment.submittedAt!)}',
              AppTheme.accentGreen,
            ),
          if (widget.assignment.submissionFileName != null) ...[
            const SizedBox(height: 8),
            _buildInfoChip(
              Icons.attach_file_rounded,
              'Dosya: ${widget.assignment.submissionFileName}',
              AppTheme.primaryBlue,
            ),
          ],
          if (widget.assignment.submissionNotes != null) ...[
            const SizedBox(height: 12),
            Text(
              'Öğrenci Notları:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.assignment.submissionNotes!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.grey600,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.premiumGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.premiumGold.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grade_rounded, size: 20, color: AppTheme.premiumGold),
              const SizedBox(width: 8),
              Text(
                'Değerlendirme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.premiumGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.assignment.grade != null)
            _buildInfoChip(
              Icons.star_rounded,
              'Not: ${widget.assignment.grade}',
              AppTheme.premiumGold,
            ),
          if (widget.assignment.gradedAt != null) ...[
            const SizedBox(height: 8),
            _buildInfoChip(
              Icons.access_time_rounded,
              'Değerlendirme Tarihi: ${_formatDateTime(widget.assignment.gradedAt!)}',
              AppTheme.premiumGold,
            ),
          ],
          if (widget.assignment.feedback != null) ...[
            const SizedBox(height: 12),
            Text(
              'Geri Bildirim:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.assignment.feedback!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.grey600,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showGradingDialog,
            icon: const Icon(Icons.grade_rounded),
            label: const Text('Değerlendir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showGradingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ödev Değerlendir'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grade Selection
              DropdownButtonFormField<String>(
                value: _selectedGrade,
                decoration: const InputDecoration(
                  labelText: 'Not',
                  border: OutlineInputBorder(),
                ),
                items: _gradeOptions.map((grade) {
                  return DropdownMenuItem(
                    value: grade,
                    child: Text(grade),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGrade = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Feedback
              TextField(
                controller: _feedbackController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Geri Bildirim',
                  border: OutlineInputBorder(),
                  hintText: 'Öğrenciye geri bildirim yazın...',
                ),
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
            onPressed: _isGrading ? null : _submitGrade,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
            ),
            child: _isGrading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitGrade() async {
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir not seçin')),
      );
      return;
    }

    setState(() {
      _isGrading = true;
    });

    try {
      // Implement grade submission API call
      final apiService = ApiService();
      await apiService.post('/assignments/${widget.assignment.id}/grade', {
        'grade': _selectedGrade,
        'feedback': _feedbackController.text.trim().isNotEmpty ? _feedbackController.text.trim() : null,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ödev başarıyla değerlendirildi')),
        );
        
        // Assignment model is immutable, so we just show success message
        // The parent screen will refresh to show updated data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGrading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.accentOrange;
      case 'submitted':
        return AppTheme.accentGreen;
      case 'graded':
        return AppTheme.accentPurple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.assignment_rounded;
      case 'submitted':
        return Icons.upload_rounded;
      case 'graded':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Atandı';
      case 'submitted':
        return 'Değerlendirilecek';
      case 'graded':
        return 'Değerlendirildi';
      default:
        return 'Bilinmiyor';
    }
  }

  String _getDifficultyText(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Kolay';
      case 'medium':
        return 'Orta';
      case 'hard':
        return 'Zor';
      default:
        return difficulty;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }
}
