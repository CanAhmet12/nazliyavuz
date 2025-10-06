import 'package:equatable/equatable.dart';
import 'user.dart';
import 'teacher.dart';
import 'category.dart';

class Reservation extends Equatable {
  final int id;
  final int studentId;
  final int teacherId;
  final int categoryId;
  final String subject;
  final DateTime proposedDatetime;
  final int? durationMinutes;
  final double price;
  final String status;
  final String? notes;
  final String? teacherNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? student;
  final Teacher? teacher;
  final Category? category;

  const Reservation({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.categoryId,
    required this.subject,
    required this.proposedDatetime,
    this.durationMinutes,
    required this.price,
    required this.status,
    this.notes,
    this.teacherNotes,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.teacher,
    this.category,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      teacherId: json['teacher_id'] ?? 0,
      categoryId: json['category_id'] ?? 0,
      subject: json['subject'] ?? '',
      proposedDatetime: json['proposed_datetime'] != null 
          ? DateTime.tryParse(json['proposed_datetime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      durationMinutes: json['duration_minutes'] != null ? int.tryParse(json['duration_minutes'].toString()) : null,
      price: json['price'] != null ? double.tryParse(json['price'].toString()) ?? 0.0 : 0.0,
      status: json['status'] ?? 'pending',
      notes: json['notes']?.toString(),
      teacherNotes: json['teacher_notes']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      student: json['student'] != null ? User.fromJson(json['student']) : null,
      teacher: json['teacher'] != null ? Teacher.fromJson(json['teacher']) : null,
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'teacher_id': teacherId,
      'category_id': categoryId,
      'subject': subject,
      'proposed_datetime': proposedDatetime.toIso8601String(),
      'duration_minutes': durationMinutes,
      'price': price,
      'status': status,
      'notes': notes,
      'teacher_notes': teacherNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'student': student?.toJson(),
      'teacher': teacher?.toJson(),
      'category': category?.toJson(),
    };
  }

  Reservation copyWith({
    int? id,
    int? studentId,
    int? teacherId,
    int? categoryId,
    String? subject,
    DateTime? proposedDatetime,
    int? durationMinutes,
    double? price,
    String? status,
    String? notes,
    String? teacherNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? student,
    Teacher? teacher,
    Category? category,
  }) {
    return Reservation(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      categoryId: categoryId ?? this.categoryId,
      subject: subject ?? this.subject,
      proposedDatetime: proposedDatetime ?? this.proposedDatetime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      price: price ?? this.price,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      teacherNotes: teacherNotes ?? this.teacherNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      student: student ?? this.student,
      teacher: teacher ?? this.teacher,
      category: category ?? this.category,
    );
  }

  String get formattedDuration {
    if (durationMinutes == null) return '60dk';
    
    final hours = durationMinutes! ~/ 60;
    final minutes = durationMinutes! % 60;
    
    if (hours > 0) {
      return minutes > 0 ? '${hours}sa ${minutes}dk' : '${hours}sa';
    }
    
    return '${minutes}dk';
  }

  String get formattedPrice => '${price.toStringAsFixed(2)} TL';

  bool get isUpcoming => proposedDatetime.isAfter(DateTime.now());
  bool get isPast => proposedDatetime.isBefore(DateTime.now());
  
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  bool get canBeCancelled => 
      (isPending || isAccepted) && isUpcoming;

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'accepted':
        return 'Kabul Edildi';
      case 'rejected':
        return 'Reddedildi';
      case 'cancelled':
        return 'İptal Edildi';
      case 'completed':
        return 'Tamamlandı';
      default:
        return 'Bilinmeyen';
    }
  }

  @override
  List<Object?> get props => [
        id,
        studentId,
        teacherId,
        categoryId,
        subject,
        proposedDatetime,
        durationMinutes,
        price,
        status,
        notes,
        teacherNotes,
        createdAt,
        updatedAt,
        student,
        teacher,
        category,
      ];
}
