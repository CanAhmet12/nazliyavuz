import 'package:flutter/material.dart';
import '../models/chat.dart';

class MessageForwardWidget extends StatefulWidget {
  final List<Chat> availableChats;
  final Function(int)? onForward;
  final Function()? onCancel;

  const MessageForwardWidget({
    Key? key,
    required this.availableChats,
    this.onForward,
    this.onCancel,
  }) : super(key: key);

  @override
  State<MessageForwardWidget> createState() => _MessageForwardWidgetState();
}

class _MessageForwardWidgetState extends State<MessageForwardWidget> {
  int? _selectedChatId;
  final TextEditingController _searchController = TextEditingController();
  List<Chat> _filteredChats = [];

  @override
  void initState() {
    super.initState();
    _filteredChats = widget.availableChats;
    _searchController.addListener(_filterChats);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterChats);
    _searchController.dispose();
    super.dispose();
  }

  void _filterChats() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredChats = widget.availableChats.where((chat) {
        final otherUserName = chat.otherUser?.name.toLowerCase() ?? '';
        return otherUserName.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.forward,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Text(
                'Mesajı İlet',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Kullanıcı ara...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredChats.isEmpty
                ? Center(
                    child: Text(
                      'Aranan kriterlere uygun chat bulunamadı',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredChats.length,
                    itemBuilder: (context, index) {
                      final chat = _filteredChats[index];
                      final isSelected = _selectedChatId == chat.id;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: chat.otherUser?.profilePhotoUrl != null
                              ? NetworkImage(chat.otherUser!.profilePhotoUrl!)
                              : null,
                          child: chat.otherUser?.profilePhotoUrl == null
                              ? Text(
                                  chat.otherUser?.name.substring(0, 1).toUpperCase() ?? '?',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(
                          chat.otherUser?.name ?? 'Bilinmeyen Kullanıcı',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          chat.lastMessage?.toString() ?? 'Mesaj yok',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Colors.blue[600],
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedChatId = chat.id;
                          });
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('İptal'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectedChatId != null ? _forward : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('İlet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _forward() {
    if (_selectedChatId != null) {
      widget.onForward?.call(_selectedChatId!);
    }
  }
}
