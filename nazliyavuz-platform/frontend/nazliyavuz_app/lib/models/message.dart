import 'package:equatable/equatable.dart';

class Message extends Equatable {
  final int id;
  final String content;
  final String type; // text, image, file
  final int senderId;
  final bool isRead;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.content,
    required this.type,
    required this.senderId,
    required this.isRead,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      content: json['content'] as String,
      type: json['message_type'] as String? ?? json['type'] as String? ?? 'text',
      senderId: json['sender_id'] as int,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type,
      'sender_id': senderId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Message copyWith({
    int? id,
    String? content,
    String? type,
    int? senderId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    content,
    type,
    senderId,
    isRead,
    createdAt,
  ];
}