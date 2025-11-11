import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class ModernChatStatisticsScreen extends StatefulWidget {
  final User teacher;
  final int chatId;

  const ModernChatStatisticsScreen({
    Key? key,
    required this.teacher,
    required this.chatId,
  }) : super(key: key);

  @override
  State<ModernChatStatisticsScreen> createState() => _ModernChatStatisticsScreenState();
}

class _ModernChatStatisticsScreenState extends State<ModernChatStatisticsScreen>
    with TickerProviderStateMixin {
  final _apiService = ApiService();
  
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = '30d';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadStatistics();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);
      
      final stats = await _apiService.getChatStatistics(widget.chatId);
      
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
      
      _animationController.forward();
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Chat İstatistikleri'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
              _loadStatistics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '7d', child: Text('Son 7 Gün')),
              const PopupMenuItem(value: '30d', child: Text('Son 30 Gün')),
              const PopupMenuItem(value: '90d', child: Text('Son 90 Gün')),
              const PopupMenuItem(value: '1y', child: Text('Son 1 Yıl')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getPeriodText(_selectedPeriod)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'İstatistikler yüklenemedi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStatistics,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Cards
                  _buildOverviewCards(),
                  const SizedBox(height: 24),
                  
                  // Message Types Chart
                  _buildMessageTypesChart(),
                  const SizedBox(height: 24),
                  
                  // Activity Chart
                  _buildActivityChart(),
                  const SizedBox(height: 24),
                  
                  // User Activity
                  _buildUserActivity(),
                  const SizedBox(height: 24),
                  
                  // Response Time
                  _buildResponseTime(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewCards() {
    final totalMessages = _statistics?['total_messages'] ?? 0;
    final messagesByType = _statistics?['messages_by_type'] ?? {};
    final averageResponseTime = _statistics?['average_response_time_minutes'] ?? 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genel Bakış',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Toplam Mesaj',
                value: totalMessages.toString(),
                icon: Icons.chat_bubble_outline,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Ortalama Yanıt',
                value: '${averageResponseTime.toStringAsFixed(1)} dk',
                icon: Icons.timer,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Metin Mesaj',
                value: (messagesByType['text'] ?? 0).toString(),
                icon: Icons.text_fields,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Medya',
                value: ((messagesByType['image'] ?? 0) + (messagesByType['file'] ?? 0)).toString(),
                icon: Icons.attach_file,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.trending_up, color: Colors.green[400], size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTypesChart() {
    final messagesByType = _statistics?['messages_by_type'] ?? {};
    final total = messagesByType.values.fold(0, (sum, count) => sum + count);
    
    if (total == 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mesaj Türleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          ...messagesByType.entries.map((entry) {
            final percentage = (entry.value / total * 100);
            final color = _getMessageTypeColor(entry.key);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getMessageTypeName(entry.key),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityChart() {
    final dailyActivity = _statistics?['daily_activity'] ?? {};
    
    if (dailyActivity.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Günlük Aktivite',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _buildActivityChartContent(dailyActivity),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChartContent(Map<String, dynamic> dailyActivity) {
    final entries = dailyActivity.entries.toList();
    final maxValue = entries.isNotEmpty 
        ? entries.map((e) => e.value as int).reduce((a, b) => a > b ? a : b)
        : 1;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: entries.take(7).map((entry) {
        final value = entry.value as int;
        final height = (value / maxValue * 150).clamp(10.0, 150.0);
        
        return Expanded(
          child: Column(
            children: [
              Container(
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[400],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(entry.key),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserActivity() {
    final messagesByUser = _statistics?['messages_by_user'] ?? {};
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kullanıcı Aktivitesi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          ...messagesByUser.entries.map((entry) {
            final userId = entry.key;
            final count = entry.value;
            final isCurrentUser = userId == '0'; // Assuming 0 is current user
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isCurrentUser ? Colors.blue[500] : Colors.grey[400],
                    child: Text(
                      isCurrentUser ? 'S' : 'T',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCurrentUser ? 'Sen' : widget.teacher.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          '$count mesaj',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrentUser ? Colors.blue[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${((count / (messagesByUser.values.fold(0, (sum, c) => sum + c))) * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isCurrentUser ? Colors.blue[700] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildResponseTime() {
    final averageResponseTime = _statistics?['average_response_time_minutes'] ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yanıt Süreleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.timer, color: Colors.green[600], size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ortalama Yanıt Süresi',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${averageResponseTime.toStringAsFixed(1)} dakika',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getResponseTimeColor(averageResponseTime),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getResponseTimeLabel(averageResponseTime),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPeriodText(String period) {
    switch (period) {
      case '7d':
        return 'Son 7 Gün';
      case '30d':
        return 'Son 30 Gün';
      case '90d':
        return 'Son 90 Gün';
      case '1y':
        return 'Son 1 Yıl';
      default:
        return 'Son 30 Gün';
    }
  }

  Color _getMessageTypeColor(String type) {
    switch (type) {
      case 'text':
        return Colors.blue;
      case 'image':
        return Colors.green;
      case 'file':
        return Colors.orange;
      case 'audio':
        return Colors.purple;
      case 'video':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getMessageTypeName(String type) {
    switch (type) {
      case 'text':
        return 'Metin';
      case 'image':
        return 'Resim';
      case 'file':
        return 'Dosya';
      case 'audio':
        return 'Ses';
      case 'video':
        return 'Video';
      default:
        return type.toUpperCase();
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getResponseTimeColor(double minutes) {
    if (minutes < 5) return Colors.green;
    if (minutes < 30) return Colors.orange;
    return Colors.red;
  }

  String _getResponseTimeLabel(double minutes) {
    if (minutes < 5) return 'Hızlı';
    if (minutes < 30) return 'Normal';
    return 'Yavaş';
  }
}
