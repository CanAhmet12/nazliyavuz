import 'package:equatable/equatable.dart';
import 'message_reaction.dart';
import 'message_thread.dart';
import 'message_mention.dart';
import 'message_translation.dart';
import 'user.dart';

class Message extends Equatable {
  final int id;
  final int chatId;
  final int senderId;
  final int receiverId;
  final String content;
  final String messageType; // text, image, file, audio, video
  
  // File fields
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? fileType;
  
  // Status fields
  final bool isRead;
  final DateTime? readAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  
  // Voice message fields
  final int? voiceDuration; // Duration in seconds for voice messages
  
  // Reaction fields
  final List<MessageReaction> reactions;
  
  // Advanced features
  final int? parentMessageId;
  final int? threadId;
  final List<int>? mentions;
  final int? replyToMessageId;
  final int? forwardedFromMessageId;
  final int? forwardedFromUserId;
  final DateTime? forwardedAt;
  final bool isPinned;
  final DateTime? pinnedAt;
  final int? pinnedBy;
  final String? originalContent;
  final DateTime? editedAt;
  final int editCount;
  final List<MessageTranslation>? translations;
  final String? originalLanguage;
  final bool isEncrypted;
  final String? encryptionKeyId;
  final String messageStatus; // sent, delivered, read, failed
  final DateTime? deliveredAt;
  final Map<String, dynamic>? metadata;
  
  // Related objects
  final Message? parentMessage;
  final Message? repliedMessage;
  final Message? forwardedFromMessage;
  final User? forwardedFromUser;
  final User? pinnedByUser;
  final List<MessageMention>? messageMentions;
  final MessageThread? thread;
  
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.messageType,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileType,
    required this.isRead,
    this.readAt,
    this.isDeleted = false,
    this.deletedAt,
    this.voiceDuration,
    this.reactions = const [],
    // Advanced features
    this.parentMessageId,
    this.threadId,
    this.mentions,
    this.replyToMessageId,
    this.forwardedFromMessageId,
    this.forwardedFromUserId,
    this.forwardedAt,
    this.isPinned = false,
    this.pinnedAt,
    this.pinnedBy,
    this.originalContent,
    this.editedAt,
    this.editCount = 0,
    this.translations,
    this.originalLanguage,
    this.isEncrypted = false,
    this.encryptionKeyId,
    this.messageStatus = 'sent',
    this.deliveredAt,
    this.metadata,
    // Related objects
    this.parentMessage,
    this.repliedMessage,
    this.forwardedFromMessage,
    this.forwardedFromUser,
    this.pinnedByUser,
    this.messageMentions,
    this.thread,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      chatId: json['chat_id'] != null ? int.tryParse(json['chat_id'].toString()) ?? 0 : 0,
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] != null ? int.tryParse(json['receiver_id'].toString()) ?? 0 : 0,
      content: json['content'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      fileUrl: json['file_url']?.toString(),
      fileName: json['file_name']?.toString(),
      fileSize: json['file_size'] != null ? int.tryParse(json['file_size'].toString()) : null,
      fileType: json['file_type']?.toString(),
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'].toString()) : null,
      voiceDuration: json['voice_duration'] != null 
          ? int.tryParse(json['voice_duration'].toString()) 
          : (json['message_type'] == 'audio' ? json['file_size'] as int? : null),
      reactions: json['reactions'] != null 
          ? (json['reactions'] as List).map((r) => MessageReaction.fromJson(r)).toList()
          : [],
      // Advanced features
      parentMessageId: json['parent_message_id'] != null ? int.tryParse(json['parent_message_id'].toString()) : null,
      threadId: json['thread_id'] != null ? int.tryParse(json['thread_id'].toString()) : null,
      mentions: json['mentions'] != null ? List<int>.from(json['mentions']) : null,
      replyToMessageId: json['reply_to_message_id'] != null ? int.tryParse(json['reply_to_message_id'].toString()) : null,
      forwardedFromMessageId: json['forwarded_from_message_id'] != null ? int.tryParse(json['forwarded_from_message_id'].toString()) : null,
      forwardedFromUserId: json['forwarded_from_user_id'] != null ? int.tryParse(json['forwarded_from_user_id'].toString()) : null,
      forwardedAt: json['forwarded_at'] != null ? DateTime.tryParse(json['forwarded_at'].toString()) : null,
      isPinned: json['is_pinned'] as bool? ?? false,
      pinnedAt: json['pinned_at'] != null ? DateTime.tryParse(json['pinned_at'].toString()) : null,
      pinnedBy: json['pinned_by'] != null ? int.tryParse(json['pinned_by'].toString()) : null,
      originalContent: json['original_content']?.toString(),
      editedAt: json['edited_at'] != null ? DateTime.tryParse(json['edited_at'].toString()) : null,
      editCount: json['edit_count'] as int? ?? 0,
      translations: json['translations'] != null 
          ? (json['translations'] as List).map((t) => MessageTranslation.fromJson(t)).toList()
          : null,
      originalLanguage: json['original_language']?.toString(),
      isEncrypted: json['is_encrypted'] as bool? ?? false,
      encryptionKeyId: json['encryption_key_id']?.toString(),
      messageStatus: json['message_status'] as String? ?? 'sent',
      deliveredAt: json['delivered_at'] != null ? DateTime.tryParse(json['delivered_at'].toString()) : null,
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
      // Related objects
      parentMessage: json['parent_message'] != null ? Message.fromJson(json['parent_message']) : null,
      repliedMessage: json['replied_message'] != null ? Message.fromJson(json['replied_message']) : null,
      forwardedFromMessage: json['forwarded_from_message'] != null ? Message.fromJson(json['forwarded_from_message']) : null,
      forwardedFromUser: json['forwarded_from_user'] != null ? User.fromJson(json['forwarded_from_user']) : null,
      pinnedByUser: json['pinned_by_user'] != null ? User.fromJson(json['pinned_by_user']) : null,
      messageMentions: json['message_mentions'] != null 
          ? (json['message_mentions'] as List).map((m) => MessageMention.fromJson(m)).toList()
          : null,
      thread: json['thread'] != null ? MessageThread.fromJson(json['thread']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (fileType != null) 'file_type': fileType,
      'is_read': isRead,
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
      'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      if (voiceDuration != null) 'voice_duration': voiceDuration,
      'reactions': reactions.map((r) => r.toJson()).toList(),
      // Advanced features
      if (parentMessageId != null) 'parent_message_id': parentMessageId,
      if (threadId != null) 'thread_id': threadId,
      if (mentions != null) 'mentions': mentions,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (forwardedFromMessageId != null) 'forwarded_from_message_id': forwardedFromMessageId,
      if (forwardedFromUserId != null) 'forwarded_from_user_id': forwardedFromUserId,
      if (forwardedAt != null) 'forwarded_at': forwardedAt!.toIso8601String(),
      'is_pinned': isPinned,
      if (pinnedAt != null) 'pinned_at': pinnedAt!.toIso8601String(),
      if (pinnedBy != null) 'pinned_by': pinnedBy,
      if (originalContent != null) 'original_content': originalContent,
      if (editedAt != null) 'edited_at': editedAt!.toIso8601String(),
      'edit_count': editCount,
      if (translations != null) 'translations': translations!.map((t) => t.toJson()).toList(),
      if (originalLanguage != null) 'original_language': originalLanguage,
      'is_encrypted': isEncrypted,
      if (encryptionKeyId != null) 'encryption_key_id': encryptionKeyId,
      'message_status': messageStatus,
      if (deliveredAt != null) 'delivered_at': deliveredAt!.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      // Related objects
      if (parentMessage != null) 'parent_message': parentMessage!.toJson(),
      if (repliedMessage != null) 'replied_message': repliedMessage!.toJson(),
      if (forwardedFromMessage != null) 'forwarded_from_message': forwardedFromMessage!.toJson(),
      if (forwardedFromUser != null) 'forwarded_from_user': forwardedFromUser!.toJson(),
      if (pinnedByUser != null) 'pinned_by_user': pinnedByUser!.toJson(),
      if (messageMentions != null) 'message_mentions': messageMentions!.map((m) => m.toJson()).toList(),
      if (thread != null) 'thread': thread!.toJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Message copyWith({
    int? id,
    int? chatId,
    int? senderId,
    int? receiverId,
    String? content,
    String? messageType,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileType,
    bool? isRead,
    DateTime? readAt,
    bool? isDeleted,
    DateTime? deletedAt,
    int? voiceDuration,
    List<MessageReaction>? reactions,
    // Advanced features
    int? parentMessageId,
    int? threadId,
    List<int>? mentions,
    int? replyToMessageId,
    int? forwardedFromMessageId,
    int? forwardedFromUserId,
    DateTime? forwardedAt,
    bool? isPinned,
    DateTime? pinnedAt,
    int? pinnedBy,
    String? originalContent,
    DateTime? editedAt,
    int? editCount,
    List<MessageTranslation>? translations,
    String? originalLanguage,
    bool? isEncrypted,
    String? encryptionKeyId,
    String? messageStatus,
    DateTime? deliveredAt,
    Map<String, dynamic>? metadata,
    // Related objects
    Message? parentMessage,
    Message? repliedMessage,
    Message? forwardedFromMessage,
    User? forwardedFromUser,
    User? pinnedByUser,
    List<MessageMention>? messageMentions,
    MessageThread? thread,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      reactions: reactions ?? this.reactions,
      // Advanced features
      parentMessageId: parentMessageId ?? this.parentMessageId,
      threadId: threadId ?? this.threadId,
      mentions: mentions ?? this.mentions,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      forwardedFromMessageId: forwardedFromMessageId ?? this.forwardedFromMessageId,
      forwardedFromUserId: forwardedFromUserId ?? this.forwardedFromUserId,
      forwardedAt: forwardedAt ?? this.forwardedAt,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      originalContent: originalContent ?? this.originalContent,
      editedAt: editedAt ?? this.editedAt,
      editCount: editCount ?? this.editCount,
      translations: translations ?? this.translations,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptionKeyId: encryptionKeyId ?? this.encryptionKeyId,
      messageStatus: messageStatus ?? this.messageStatus,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      metadata: metadata ?? this.metadata,
      // Related objects
      parentMessage: parentMessage ?? this.parentMessage,
      repliedMessage: repliedMessage ?? this.repliedMessage,
      forwardedFromMessage: forwardedFromMessage ?? this.forwardedFromMessage,
      forwardedFromUser: forwardedFromUser ?? this.forwardedFromUser,
      pinnedByUser: pinnedByUser ?? this.pinnedByUser,
      messageMentions: messageMentions ?? this.messageMentions,
      thread: thread ?? this.thread,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods
  bool get isText => messageType == 'text';
  bool get isImage => messageType == 'image';
  bool get isFile => messageType == 'file';
  bool get isAudio => messageType == 'audio';
  bool get isVideo => messageType == 'video';
  
  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  
  String get formattedSize {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  String get durationText {
    if (messageType != 'audio' || fileSize == null) return '';
    final seconds = fileSize!;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
    id,
    chatId,
    senderId,
    receiverId,
    content,
    messageType,
    fileUrl,
    fileName,
    fileSize,
    fileType,
    isRead,
    readAt,
    isDeleted,
    deletedAt,
    voiceDuration,
    reactions,
    // Advanced features
    parentMessageId,
    threadId,
    mentions,
    replyToMessageId,
    forwardedFromMessageId,
    forwardedFromUserId,
    forwardedAt,
    isPinned,
    pinnedAt,
    pinnedBy,
    originalContent,
    editedAt,
    editCount,
    translations,
    originalLanguage,
    isEncrypted,
    encryptionKeyId,
    messageStatus,
    deliveredAt,
    metadata,
    // Related objects
    parentMessage,
    repliedMessage,
    forwardedFromMessage,
    forwardedFromUser,
    pinnedByUser,
    messageMentions,
    thread,
    createdAt,
  ];
}