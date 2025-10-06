import 'package:equatable/equatable.dart';

class Notification extends Equatable {
  final int id;
  final int userId;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Notification({
    required this.id,
    required this.userId,
    required this.type,
    required this.payload,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      payload: Map<String, dynamic>.from(json['payload']),
      readAt: json['read_at'] != null 
          ? DateTime.parse(json['read_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'payload': payload,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Notification copyWith({
    int? id,
    int? userId,
    String? type,
    Map<String, dynamic>? payload,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isRead => readAt != null;
  bool get isUnread => readAt == null;

  String get title => payload['title'] ?? 'Yeni Bildirim';
  String get message => payload['message'] ?? '';
  Map<String, dynamic> get data => payload['data'] ?? {};

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        payload,
        readAt,
        createdAt,
        updatedAt,
      ];
}
