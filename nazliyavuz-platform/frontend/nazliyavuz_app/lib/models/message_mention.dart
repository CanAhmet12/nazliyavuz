import 'package:equatable/equatable.dart';
import 'user.dart';

class MessageMention extends Equatable {
  final int id;
  final int messageId;
  final int mentionedUserId;
  final int? position;
  final DateTime createdAt;
  final User? mentionedUser;

  const MessageMention({
    required this.id,
    required this.messageId,
    required this.mentionedUserId,
    this.position,
    required this.createdAt,
    this.mentionedUser,
  });

  factory MessageMention.fromJson(Map<String, dynamic> json) {
    return MessageMention(
      id: json['id'] as int,
      messageId: json['message_id'] as int,
      mentionedUserId: json['mentioned_user_id'] as int,
      position: json['position'] as int?,
      createdAt: DateTime.parse(json['created_at']),
      mentionedUser: json['mentioned_user'] != null 
          ? User.fromJson(json['mentioned_user']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'mentioned_user_id': mentionedUserId,
      'position': position,
      'created_at': createdAt.toIso8601String(),
      if (mentionedUser != null) 'mentioned_user': mentionedUser!.toJson(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        messageId,
        mentionedUserId,
        position,
        createdAt,
        mentionedUser,
      ];
}
