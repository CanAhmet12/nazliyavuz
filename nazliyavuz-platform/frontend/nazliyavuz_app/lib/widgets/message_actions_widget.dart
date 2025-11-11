import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageActionsWidget extends StatelessWidget {
  final Message message;
  final Function(Message)? onReply;
  final Function(Message)? onForward;
  final Function(Message)? onPin;
  final Function(Message)? onUnpin;
  final Function(Message)? onEdit;
  final Function(Message)? onDelete;
  final Function(Message)? onTranslate;
  final Function(Message)? onCreateThread;

  const MessageActionsWidget({
    Key? key,
    required this.message,
    this.onReply,
    this.onForward,
    this.onPin,
    this.onUnpin,
    this.onEdit,
    this.onDelete,
    this.onTranslate,
    this.onCreateThread,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReply != null)
            _buildActionTile(
              icon: Icons.reply,
              title: 'Yanıtla',
              onTap: () => onReply!(message),
            ),
          if (onForward != null)
            _buildActionTile(
              icon: Icons.forward,
              title: 'İlet',
              onTap: () => onForward!(message),
            ),
          if (message.isPinned && onUnpin != null)
            _buildActionTile(
              icon: Icons.push_pin,
              title: 'Sabitlemeyi Kaldır',
              onTap: () => onUnpin!(message),
            )
          else if (!message.isPinned && onPin != null)
            _buildActionTile(
              icon: Icons.push_pin,
              title: 'Sabitle',
              onTap: () => onPin!(message),
            ),
          if (onEdit != null)
            _buildActionTile(
              icon: Icons.edit,
              title: 'Düzenle',
              onTap: () => onEdit!(message),
            ),
          if (onTranslate != null)
            _buildActionTile(
              icon: Icons.translate,
              title: 'Çevir',
              onTap: () => onTranslate!(message),
            ),
          if (onCreateThread != null)
            _buildActionTile(
              icon: Icons.forum,
              title: 'Konu Oluştur',
              onTap: () => onCreateThread!(message),
            ),
          if (onDelete != null)
            _buildActionTile(
              icon: Icons.delete,
              title: 'Sil',
              onTap: () => onDelete!(message),
              isDestructive: true,
            ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.white,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }
}
