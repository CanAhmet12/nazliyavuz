import 'package:flutter/material.dart';
import '../models/message_mention.dart';

class MessageMentionWidget extends StatelessWidget {
  final MessageMention mention;
  final Function(int)? onUserTap;

  const MessageMentionWidget({
    Key? key,
    required this.mention,
    this.onUserTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onUserTap?.call(mention.mentionedUserId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person,
              size: 14,
              color: Colors.blue[700],
            ),
            const SizedBox(width: 4),
            Text(
              mention.mentionedUser?.name ?? 'Kullanıcı',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
