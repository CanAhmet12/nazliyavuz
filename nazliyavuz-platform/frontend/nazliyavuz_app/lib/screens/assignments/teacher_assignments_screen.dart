import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../models/assignment.dart';
import '../../theme/app_theme.dart';
import 'create_assignment_screen.dart';
import 'assignment_detail_screen.dart';

class TeacherAssignmentsScreen extends StatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  State<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends State<TeacherAssignmentsScreen> 
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  List<Assignment> _allAssignments = [];
  List<Assignment> _pendingAssignments = [];
  List<Assignment> _submittedAssignments = [];
  List<Assignment> _gradedAssignments = [];
  
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAssignments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getTeacherAssignments();

      setState(() {
        _allAssignments = (response['assignments'] as List)
            .map((json) => Assignment.fromJson(json))
            .toList();
        
        _pendingAssignments = _allAssignments
            .where((a) => a.status == 'pending')
            .toList();
        _submittedAssignments = _allAssignments
            .where((a) => a.status == 'submitted')
            .toList();
        _gradedAssignments = _allAssignments
            .where((a) => a.status == 'graded')
            .toList();
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ödev Yönetimi'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateAssignmentScreen(),
                ),
              ).then((_) => _loadAssignments());
            },
            tooltip: 'Yeni Ödev Oluştur',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryBlue,
          tabs: [
            Tab(
              text: 'Tümü',
              icon: Badge(
                label: Text('${_allAssignments.length}'),
                child: const Icon(Icons.assignment),
              ),
            ),
            Tab(
              text: 'Bekleyen',
              icon: Badge(
                label: Text('${_pendingAssignments.length}'),
                child: const Icon(Icons.pending_actions),
              ),
            ),
            Tab(
              text: 'Teslim Edildi',
              icon: Badge(
                label: Text('${_submittedAssignments.length}'),
                child: const Icon(Icons.check_circle_outline),
              ),
            ),
            Tab(
              text: 'Değerlendirildi',
              icon: Badge(
                label: Text('${_gradedAssignments.length}'),
                child: const Icon(Icons.grade),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? CustomWidgets.customLoading(message: 'Ödevler yükleniyor...')
          : _error != null
              ? CustomWidgets.errorWidget(
                  errorMessage: _error!,
                  onRetry: _loadAssignments,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAssignmentsList(_allAssignments, 'Henüz hiç ödev oluşturmadınız'),
                    _buildAssignmentsList(_pendingAssignments, 'Bekleyen ödev yok'),
                    _buildAssignmentsList(_submittedAssignments, 'Teslim edilmiş ödev yok'),
                    _buildAssignmentsList(_gradedAssignments, 'Değerlendirilmiş ödev yok'),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateAssignmentScreen(),
            ),
          ).then((_) => _loadAssignments());
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAssignmentsList(List<Assignment> assignments, String emptyMessage) {
    if (assignments.isEmpty) {
      return CustomWidgets.emptyState(
        message: emptyMessage,
        icon: Icons.assignment_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAssignments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          return _buildAssignmentCard(assignment);
        },
      ),
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AssignmentDetailScreen(
                assignment: assignment,
              ),
            ),
          ).then((_) => _loadAssignments());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      assignment.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(assignment.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Öğrenci: ${assignment.studentName}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              if (assignment.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  assignment.description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Son Teslim: ${_formatDate(assignment.dueDate)}',
                    style: TextStyle(
                      color: _isOverdue(assignment.dueDate) ? Colors.red : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: _isOverdue(assignment.dueDate) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  _buildDifficultyChip(assignment.difficulty),
                ],
              ),
              if (assignment.grade != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.grade,
                      size: 16,
                      color: _getGradeColor(assignment.grade!),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verilen Not: ${assignment.grade}',
                      style: TextStyle(
                        color: _getGradeColor(assignment.grade!),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              if (assignment.status == 'submitted') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notification_important,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Değerlendirme bekliyor',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Bekliyor';
        icon = Icons.pending_actions;
        break;
      case 'submitted':
        color = Colors.blue;
        text = 'Teslim Edildi';
        icon = Icons.check_circle;
        break;
      case 'graded':
        color = Colors.green;
        text = 'Değerlendirildi';
        icon = Icons.grade;
        break;
      default:
        color = Colors.grey;
        text = 'Bilinmeyen';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color color;
    String text;

    switch (difficulty) {
      case 'easy':
        color = Colors.green;
        text = 'Kolay';
        break;
      case 'medium':
        color = Colors.orange;
        text = 'Orta';
        break;
      case 'hard':
        color = Colors.red;
        text = 'Zor';
        break;
      default:
        color = Colors.grey;
        text = 'Bilinmeyen';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün kaldı';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat kaldı';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika kaldı';
    } else {
      return 'Süresi doldu';
    }
  }

  bool _isOverdue(DateTime dueDate) {
    return DateTime.now().isAfter(dueDate);
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B+':
      case 'B':
        return Colors.blue;
      case 'C+':
      case 'C':
        return Colors.orange;
      case 'D+':
      case 'D':
        return Colors.red;
      case 'F':
        return Colors.red[800]!;
      default:
        return Colors.grey;
    }
  }
}
