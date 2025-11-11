import 'package:equatable/equatable.dart';
import 'message.dart';
import 'user.dart';

class MessageThread extends Equatable {
  final int id;
  final int chatId;
  final int rootMessageId;
  final String? threadTitle;
  final bool isActive;
  final int messageCount;
  final DateTime? lastActivityAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Message? rootMessage;
  final List<Message>? messages;

  const MessageThread({
    required this.id,
    required this.chatId,
    required this.rootMessageId,
    this.threadTitle,
    required this.isActive,
    required this.messageCount,
    this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
    this.rootMessage,
    this.messages,
  });

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    return MessageThread(
      id: json['id'] as int,
      chatId: json['chat_id'] as int,
      rootMessageId: json['root_message_id'] as int,
      threadTitle: json['thread_title'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      messageCount: json['message_count'] as int? ?? 0,
      lastActivityAt: json['last_activity_at'] != null 
          ? DateTime.parse(json['last_activity_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      rootMessage: json['root_message'] != null 
          ? Message.fromJson(json['root_message']) 
          : null,
      messages: json['messages'] != null 
          ? (json['messages'] as List)
              .map((m) => Message.fromJson(m))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'root_message_id': rootMessageId,
      'thread_title': threadTitle,
      'is_active': isActive,
      'message_count': messageCount,
      'last_activity_at': lastActivityAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (rootMessage != null) 'root_message': rootMessage!.toJson(),
      if (messages != null) 'messages': messages!.map((m) => m.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        rootMessageId,
        threadTitle,
        isActive,
        messageCount,
        lastActivityAt,
        createdAt,
        updatedAt,
        rootMessage,
        messages,
      ];
}
