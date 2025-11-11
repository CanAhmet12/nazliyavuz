import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import 'message_reaction_display.dart';
import 'message_translation_widget.dart';

class ModernMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ModernMessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<ModernMessageBubble> createState() => _ModernMessageBubbleState();
}

class _ModernMessageBubbleState extends State<ModernMessageBubble>
    with TickerProviderStateMixin {
  late AnimationController _reactionAnimationController;

  @override
  void initState() {
    super.initState();
    _reactionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _reactionAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMe && widget.showAvatar) _buildAvatar(),
          if (!widget.isMe && widget.showAvatar) const SizedBox(width: 8),
          
          Flexible(
            child: Column(
              crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Message content
                GestureDetector(
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.isMe ? Colors.black87 : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply indicator
                        if (widget.message.replyToMessageId != null) _buildReplyIndicator(),
                        
                        // Message content
                        _buildMessageContent(),
                        
                        // Message status and time
                        const SizedBox(height: 4),
                        _buildMessageFooter(),
                      ],
                    ),
                  ),
                ),
                
                // Reactions
                if (widget.message.reactions.isNotEmpty) _buildReactions(),
                
                // Translation
                if (widget.message.translations != null && widget.message.translations!.isNotEmpty)
                  _buildTranslation(),
              ],
            ),
          ),
          
          if (widget.isMe && widget.showAvatar) const SizedBox(width: 8),
          if (widget.isMe && widget.showAvatar) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundImage: widget.message.senderId == 0 
          ? null // Current user avatar
          : null, // Other user avatar
      child: widget.message.senderId == 0
          ? const Icon(Icons.person, size: 16, color: Colors.white)
          : Text(
              widget.message.senderId.toString(),
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: widget.isMe ? Colors.white : Colors.blue[500]!,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yanıt',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: widget.isMe ? Colors.white70 : Colors.blue[700],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.repliedMessage?.content ?? 'Mesaj',
            style: TextStyle(
              fontSize: 12,
              color: widget.isMe ? Colors.white70 : Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    if (widget.message.messageType == 'text') {
      return Text(
        widget.message.content,
        style: TextStyle(
          fontSize: 15,
          color: widget.isMe ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
      );
    } else if (widget.message.messageType == 'image') {
      return _buildImageMessage();
    } else if (widget.message.messageType == 'file') {
      return _buildFileMessage();
    } else if (widget.message.messageType == 'audio') {
      return _buildAudioMessage();
    } else if (widget.message.messageType == 'video') {
      return _buildVideoMessage();
    }
    
    return Text(
      widget.message.content,
      style: TextStyle(
        fontSize: 15,
        color: widget.isMe ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }

  Widget _buildImageMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.message.fileUrl != null
                ? Image.network(
                    widget.message.fileUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 40),
                      );
                    },
                  )
                : Container(
                    height: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 40),
                  ),
          ),
        ),
        if (widget.message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.message.content,
            style: TextStyle(
              fontSize: 16,
              color: widget.isMe ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(widget.message.fileType),
            color: widget.isMe ? Colors.white70 : Colors.blue[600],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.message.fileName ?? 'Dosya',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.isMe ? Colors.white : Colors.black87,
                  ),
                ),
                if (widget.message.fileSize != null)
                  Text(
                    _formatFileSize(widget.message.fileSize!),
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isMe ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.download,
            color: widget.isMe ? Colors.white70 : Colors.grey[600],
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAudioMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow,
            color: widget.isMe ? Colors.white : Colors.blue[600],
            size: 24,
          ),
          const SizedBox(width: 8),
          Container(
            width: 100,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.3,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isMe ? Colors.white : Colors.blue[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.message.voiceDuration != null
                ? _formatDuration(widget.message.voiceDuration!)
                : '0:00',
            style: TextStyle(
              fontSize: 12,
              color: widget.isMe ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: Stack(
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: widget.message.fileUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.message.fileUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.video_library, size: 40),
                            );
                          },
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.video_library, size: 40),
                      ),
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.message.content,
            style: TextStyle(
              fontSize: 16,
              color: widget.isMe ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMessageFooter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('HH:mm').format(widget.message.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: widget.isMe ? Colors.white60 : Colors.grey[400],
            fontWeight: FontWeight.w400,
          ),
        ),
        if (widget.isMe) ...[
          const SizedBox(width: 4),
          Icon(
            _getMessageStatusIcon(),
            size: 14,
            color: _getMessageStatusColor(),
          ),
        ],
      ],
    );
  }

  Widget _buildReactions() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: MessageReactionDisplay(
        reactions: widget.message.reactions,
        onReactionTap: (reaction) {
          // Handle reaction tap
        },
        isFromCurrentUser: widget.isMe,
      ),
    );
  }

  Widget _buildTranslation() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: MessageTranslationWidget(
        translation: widget.message.translations!.first,
        onShowOriginal: () {
          // Toggle between original and translation
        },
      ),
    );
  }

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.attach_file;
    
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('doc') || fileType.contains('docx')) return Icons.description;
    if (fileType.contains('xls') || fileType.contains('xlsx')) return Icons.table_chart;
    if (fileType.contains('ppt') || fileType.contains('pptx')) return Icons.slideshow;
    if (fileType.contains('zip') || fileType.contains('rar')) return Icons.archive;
    if (fileType.contains('image')) return Icons.image;
    if (fileType.contains('video')) return Icons.video_file;
    if (fileType.contains('audio')) return Icons.audio_file;
    
    return Icons.attach_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  IconData _getMessageStatusIcon() {
    switch (widget.message.messageStatus) {
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      default:
        return Icons.schedule;
    }
  }

  Color _getMessageStatusColor() {
    switch (widget.message.messageStatus) {
      case 'sent':
        return widget.isMe ? Colors.white70 : Colors.grey[500]!;
      case 'delivered':
        return widget.isMe ? Colors.white70 : Colors.grey[500]!;
      case 'read':
        return widget.isMe ? Colors.blue[300]! : Colors.blue[600]!;
      default:
        return widget.isMe ? Colors.white70 : Colors.grey[500]!;
    }
  }
}