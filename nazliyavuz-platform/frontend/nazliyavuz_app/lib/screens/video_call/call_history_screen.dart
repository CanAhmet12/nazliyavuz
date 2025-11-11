import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_service.dart';
import '../../main.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _apiService = ApiService();
  
  List<Map<String, dynamic>> _callHistory = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedFilter;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  final List<Map<String, String>> _filters = [
    {'label': 'Tümü', 'value': ''},
    {'label': 'Görüntülü', 'value': 'video'},
    {'label': 'Sesli', 'value': 'audio'},
    {'label': 'Cevaplanan', 'value': 'ended'},
    {'label': 'Kaçırılan', 'value': 'rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
  }

  Future<void> _loadCallHistory({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _callHistory.clear();
        _hasMore = true;
      });
    }

    if (_isLoading || _isLoadingMore) return;

    setState(() {
      if (_currentPage == 1) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _error = null;
    });

    try {
      final response = await _apiService.getCallHistory(
        page: _currentPage,
        limit: 20,
        callType: _selectedFilter != null && _selectedFilter!.isNotEmpty ? _selectedFilter : null,
        status: _selectedFilter == 'ended' || _selectedFilter == 'rejected' ? _selectedFilter : null,
      );

      final List<dynamic> calls = response['calls'] ?? [];
      
      setState(() {
        if (_currentPage == 1) {
          _callHistory = calls.cast<Map<String, dynamic>>();
        } else {
          _callHistory.addAll(calls.cast<Map<String, dynamic>>());
        }
        
        _hasMore = calls.length == 20;
        _currentPage++;
        _isLoading = false;
        _isLoadingMore = false;
      });

    } catch (e) {
      setState(() {
        String errorMessage = 'Arama geçmişi yüklenirken bir hata oluştu';
        
        if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'İnternet bağlantınızı kontrol edin';
        } else if (e.toString().contains('unauthorized')) {
          errorMessage = 'Oturum süreniz dolmuş, lütfen tekrar giriş yapın';
        } else if (e.toString().contains('not found')) {
          errorMessage = 'Arama geçmişi bulunamadı';
        }
        
        _error = errorMessage;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadCallHistory(refresh: true);
  }

  void _onFilterChanged(String? value) {
    setState(() {
      _selectedFilter = value;
    });
    _loadCallHistory(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5), // WhatsApp background
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54), // WhatsApp green
        foregroundColor: Colors.white,
        title: const Text(
          'Arama Geçmişi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        _onFilterChanged(selected ? filter['value'] : null);
                      },
                      selectedColor: const Color(0xFF25D366),
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _callHistory.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
        ),
      );
    }

    if (_error != null && _callHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_callHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.call_made,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz arama geçmişi yok',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yaptığınız aramalar burada görünecek',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF25D366),
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _callHistory.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _callHistory.length) {
            if (_hasMore && !_isLoadingMore) {
              _loadCallHistory();
            }
            return _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }

          final call = _callHistory[index];
          return _buildCallHistoryItem(call);
        },
      ),
    );
  }

  Widget _buildCallHistoryItem(Map<String, dynamic> call) {
    final callType = call['call_type'] as String;
    final status = call['status'] as String;
    final duration = call['duration_seconds'] as int?;
    final createdAt = DateTime.parse(call['created_at'] as String);
    final caller = call['caller'] as Map<String, dynamic>?;
    final receiver = call['receiver'] as Map<String, dynamic>?;
    
    // Get current user ID from auth state
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const SizedBox.shrink();
        }
        
        final currentUserId = state.user.id;
        final isOutgoing = call['caller_id'] == currentUserId;
        final otherUser = isOutgoing ? receiver : caller;
        final otherUserName = otherUser?['name'] ?? 'Bilinmeyen Kullanıcı';
    
    // Determine call status icon and color
    IconData statusIcon;
    Color statusColor;
    String statusText;
    
    switch (status) {
      case 'ended':
        statusIcon = Icons.call;
        statusColor = const Color(0xFF25D366);
        statusText = duration != null ? _formatDuration(duration) : 'Cevaplandı';
        break;
      case 'rejected':
        statusIcon = Icons.call_end;
        statusColor = Colors.red;
        statusText = 'Reddedildi';
        break;
      case 'cancelled':
        statusIcon = Icons.call_made;
        statusColor = Colors.orange;
        statusText = 'İptal edildi';
        break;
      default:
        statusIcon = Icons.call_missed;
        statusColor = Colors.grey;
        statusText = 'Kaçırıldı';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            callType == 'video' ? Icons.videocam : Icons.call,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          otherUserName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(
              statusIcon,
              size: 16,
              color: statusColor,
            ),
            const SizedBox(width: 4),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd.MM.yyyy HH:mm').format(createdAt),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (callType == 'video')
              Icon(
                Icons.videocam,
                color: Colors.grey[600],
                size: 18,
              ),
            const SizedBox(width: 8),
            Icon(
              isOutgoing ? Icons.call_made : Icons.call_received,
              color: Colors.grey[600],
              size: 18,
            ),
          ],
        ),
        onTap: () {
          _showCallDetailsDialog(call);
        },
      ),
    );
      },
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arama Geçmişinde Ara'),
        content: const Text('Arama özelliği yakında eklenecek!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showCallDetailsDialog(Map<String, dynamic> call) {
    final callType = call['call_type'] as String;
    final status = call['status'] as String;
    final duration = call['duration_seconds'] as int?;
    final createdAt = DateTime.parse(call['created_at'] as String);
    final caller = call['caller'] as Map<String, dynamic>?;
    final receiver = call['receiver'] as Map<String, dynamic>?;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${callType == 'video' ? 'Görüntülü' : 'Sesli'} Arama Detayları'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Durum: ${status == 'ended' ? 'Cevaplandı' : status == 'rejected' ? 'Reddedildi' : 'Kaçırıldı'}'),
            const SizedBox(height: 8),
            Text('Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(createdAt)}'),
            if (duration != null) ...[
              const SizedBox(height: 8),
              Text('Süre: ${_formatDuration(duration)}'),
            ],
            const SizedBox(height: 8),
            Text('Arayan: ${caller?['name'] ?? 'Bilinmeyen'}'),
            const SizedBox(height: 8),
            Text('Aranan: ${receiver?['name'] ?? 'Bilinmeyen'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
