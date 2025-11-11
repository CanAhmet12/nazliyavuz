import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_reaction.dart';

class MessageReactionDisplay extends StatefulWidget {
  final List<MessageReaction> reactions;
  final Function(String emoji) onReactionTap;
  final bool isFromCurrentUser;

  const MessageReactionDisplay({
    super.key,
    required this.reactions,
    required this.onReactionTap,
    required this.isFromCurrentUser,
  });

  @override
  State<MessageReactionDisplay> createState() => _MessageReactionDisplayState();
}

class _MessageReactionDisplayState extends State<MessageReactionDisplay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onReactionTap(String emoji) {
    HapticFeedback.lightImpact();
    widget.onReactionTap(emoji);
  }

  Map<String, List<MessageReaction>> _groupReactionsByEmoji() {
    final Map<String, List<MessageReaction>> grouped = {};
    
    for (final reaction in widget.reactions) {
      if (!grouped.containsKey(reaction.emoji)) {
        grouped[reaction.emoji] = [];
      }
      grouped[reaction.emoji]!.add(reaction);
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final groupedReactions = _groupReactionsByEmoji();
    final sortedEmojis = groupedReactions.keys.toList()
      ..sort((a, b) => groupedReactions[b]!.length.compareTo(groupedReactions[a]!.length));

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: sortedEmojis.map((emoji) {
                final reactions = groupedReactions[emoji]!;
                final count = reactions.length;
                final isCurrentUserReacted = reactions.any(
                  (r) => r.userName == 'Current User', // This should be replaced with actual current user check
                );

                return GestureDetector(
                  onTap: () => _onReactionTap(emoji),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentUserReacted 
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentUserReacted 
                            ? Colors.blue.withOpacity(0.3)
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (count > 1) ...[
                          const SizedBox(width: 4),
                          Text(
                            count.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCurrentUserReacted 
                                  ? Colors.blue
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
