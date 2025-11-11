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
    try {
      // Backend sends 'data' field but frontend expects 'payload'
      // Also backend sends 'title' and 'message' directly
      Map<String, dynamic> payload = {};
      
      if (json['payload'] != null) {
        payload = Map<String, dynamic>.from(json['payload']);
      } else if (json['data'] != null) {
        payload = Map<String, dynamic>.from(json['data']);
      }
      
      // If title and message are sent directly, add them to payload
      if (json['title'] != null) {
        payload['title'] = json['title'];
      }
      if (json['message'] != null) {
        payload['message'] = json['message'];
      }
      
      // Handle read_at field - can come from backend as null or actual datetime
      DateTime? readAtValue;
      if (json['read_at'] != null) {
        try {
          readAtValue = DateTime.parse(json['read_at']);
        } catch (e) {
          print('Error parsing read_at: $e');
          readAtValue = null;
        }
      }
      
      // Handle created_at and updated_at
      DateTime createdAtValue = DateTime.now();
      if (json['created_at'] != null) {
        try {
          createdAtValue = DateTime.parse(json['created_at']);
        } catch (e) {
          print('Error parsing created_at: $e');
          createdAtValue = DateTime.now();
        }
      }
      
      DateTime updatedAtValue = DateTime.now();
      if (json['updated_at'] != null) {
        try {
          updatedAtValue = DateTime.parse(json['updated_at']);
        } catch (e) {
          print('Error parsing updated_at: $e');
          updatedAtValue = DateTime.now();
        }
      }
      
      return Notification(
        id: json['id'] ?? 0,
        userId: json['user_id'] ?? 0,
        type: json['type'] ?? 'unknown',
        payload: payload,
        readAt: readAtValue,
        createdAt: createdAtValue,
        updatedAt: updatedAtValue,
      );
    } catch (e) {
      print('Error parsing notification JSON: $e');
      print('JSON: $json');
      // Return a default notification
      return Notification(
        id: 0,
        userId: 0,
        type: 'error',
        payload: {'title': 'Hata', 'message': 'Bildirim yüklenemedi'},
        readAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
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
