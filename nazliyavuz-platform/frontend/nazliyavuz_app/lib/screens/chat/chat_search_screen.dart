import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ChatSearchScreen extends StatefulWidget {
  final int chatId;
  final User otherUser;

  const ChatSearchScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _searchController = TextEditingController();
  final _apiService = ApiService();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedType;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final List<String> _messageTypes = [
    'Tümü',
    'Metin',
    'Resim',
    'Dosya',
    'Sesli Mesaj',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _apiService.searchMessages(
        widget.chatId,
        _searchController.text.trim(),
        type: _selectedType,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Arama yapılırken bir sorun oluştu. Lütfen tekrar deneyin.';
        _isLoading = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _dateFrom = null;
      _dateTo = null;
    });
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.otherUser.name} ile Arama'),
        backgroundColor: const Color(0xFF075E54), // WhatsApp green
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // WhatsApp-style search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF075E54), // WhatsApp green
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Mesajlarda ara...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.primaryBlue,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults.clear();
                          });
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                  if (value.trim().isNotEmpty) {
                    _performSearch();
                  } else {
                    setState(() {
                      _searchResults.clear();
                    });
                  }
                },
                onSubmitted: (_) => _performSearch(),
              ),
            ),
          ),
          
          // Filters
          if (_selectedType != null || _dateFrom != null || _dateTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_selectedType != null)
                          Chip(
                            label: Text(_selectedType!),
                            onDeleted: () {
                              setState(() {
                                _selectedType = null;
                              });
                              _performSearch();
                            },
                          ),
                        if (_dateFrom != null)
                          Chip(
                            label: Text('Başlangıç: ${DateFormat('dd.MM.yyyy').format(_dateFrom!)}'),
                            onDeleted: () {
                              setState(() {
                                _dateFrom = null;
                              });
                              _performSearch();
                            },
                          ),
                        if (_dateTo != null)
                          Chip(
                            label: Text('Bitiş: ${DateFormat('dd.MM.yyyy').format(_dateTo!)}'),
                            onDeleted: () {
                              setState(() {
                                _dateTo = null;
                              });
                              _performSearch();
                            },
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Temizle'),
                  ),
                ],
              ),
            ),
          
          // Results
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
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
              'Arama sırasında hata oluştu',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                ? 'Arama yapmak için bir kelime yazın'
                : 'Sonuç bulunamadı',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSearchResult(result);
      },
    );
  }

  Widget _buildSearchResult(Map<String, dynamic> result) {
    final messageType = result['message_type'] as String;
    final content = result['content'] as String;
    final fileName = result['file_name'] as String?;
    final senderId = result['sender_id'] as int;
    final createdAt = DateTime.parse(result['created_at'] as String);
    final isMe = senderId == 1; // Assuming current user ID is 1

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8),
                  ],
                ),
              ),
              child: Text(
                widget.otherUser.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryBlue : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getMessageIcon(messageType),
                        size: 16,
                        color: isMe ? Colors.white : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getMessageTypeText(messageType),
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('HH:mm').format(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (fileName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? Colors.white70 : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentGreen,
                    AppTheme.accentGreen.withOpacity(0.8),
                  ],
                ),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getMessageIcon(String type) {
    switch (type) {
      case 'text': return Icons.message;
      case 'image': return Icons.image;
      case 'file': return Icons.attach_file;
      case 'audio': return Icons.mic;
      default: return Icons.message;
    }
  }

  String _getMessageTypeText(String type) {
    switch (type) {
      case 'text': return 'Metin';
      case 'image': return 'Resim';
      case 'file': return 'Dosya';
      case 'audio': return 'Sesli Mesaj';
      default: return 'Mesaj';
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Filtreler',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Message type filter
            const Text(
              'Mesaj Türü',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _messageTypes.map((type) {
                final isSelected = _selectedType == type;
                return FilterChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? type : null;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // Date range filters
            const Text(
              'Tarih Aralığı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dateFrom ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _dateFrom = date;
                        });
                      }
                    },
                    child: Text(
                      _dateFrom != null
                        ? DateFormat('dd.MM.yyyy').format(_dateFrom!)
                        : 'Başlangıç Tarihi',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dateTo ?? DateTime.now(),
                        firstDate: _dateFrom ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _dateTo = date;
                        });
                      }
                    },
                    child: Text(
                      _dateTo != null
                        ? DateFormat('dd.MM.yyyy').format(_dateTo!)
                        : 'Bitiş Tarihi',
                    ),
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performSearch();
                },
                child: const Text('Filtreleri Uygula'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
