import 'package:equatable/equatable.dart';

class MessageReaction extends Equatable {
  final int id;
  final int messageId;
  final int userId;
  final String reactionType;
  final String emoji;
  final String userName;
  final String? userProfilePhoto;
  final DateTime createdAt;

  const MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.reactionType,
    required this.emoji,
    required this.userName,
    this.userProfilePhoto,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'] as int,
      messageId: json['message_id'] as int,
      userId: json['user_id'] as int,
      reactionType: json['reaction_type'] as String? ?? 'emoji',
      emoji: json['emoji'] as String,
      userName: json['user'] != null ? json['user']['name'] as String : 'Unknown',
      userProfilePhoto: json['user'] != null ? json['user']['profile_photo_url'] as String? : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'reaction_type': reactionType,
      'emoji': emoji,
      'user': {
        'name': userName,
        'profile_photo_url': userProfilePhoto,
      },
      'created_at': createdAt.toIso8601String(),
    };
  }

  MessageReaction copyWith({
    int? id,
    int? messageId,
    int? userId,
    String? reactionType,
    String? emoji,
    String? userName,
    String? userProfilePhoto,
    DateTime? createdAt,
  }) {
    return MessageReaction(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      reactionType: reactionType ?? this.reactionType,
      emoji: emoji ?? this.emoji,
      userName: userName ?? this.userName,
      userProfilePhoto: userProfilePhoto ?? this.userProfilePhoto,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    messageId,
    userId,
    reactionType,
    emoji,
    userName,
    userProfilePhoto,
    createdAt,
  ];
}
