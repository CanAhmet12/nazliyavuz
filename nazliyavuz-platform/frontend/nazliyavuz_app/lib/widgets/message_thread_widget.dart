import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/message_thread.dart';

class MessageThreadWidget extends StatelessWidget {
  final MessageThread thread;
  final Function(Message)? onMessageTap;
  final Function(Message)? onReplyToMessage;

  const MessageThreadWidget({
    Key? key,
    required this.thread,
    this.onMessageTap,
    this.onReplyToMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          thread.threadTitle ?? 'Konu',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${thread.messageCount} mesaj',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Text(
          _formatLastActivity(thread.lastActivityAt),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
        children: [
          if (thread.messages != null && thread.messages!.isNotEmpty)
            ...thread.messages!.map((message) => _buildMessageTile(message)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (thread.rootMessage != null) {
                      onReplyToMessage?.call(thread.rootMessage!);
                    }
                  },
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Yanıtla'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(Message message) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.blue[100],
        child: Text(
          message.senderId.toString(),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      title: Text(
        message.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        _formatMessageTime(message.createdAt),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 11,
        ),
      ),
      onTap: () => onMessageTap?.call(message),
    );
  }

  String _formatLastActivity(DateTime? lastActivity) {
    if (lastActivity == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(lastActivity);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
