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
  
  // Payment fields (P0)
  final String? paymentStatus;
  final String? paymentMethod;
  final String? paymentTransactionId;
  final DateTime? paidAt;
  final double? refundAmount;
  final String? refundReason;
  final DateTime? refundedAt;
  
  // Cancellation fields (P0)
  final int? cancelledById;
  final String? cancelledReason;
  final DateTime? cancelledAt;
  final double? cancellationFee;
  
  // Reminder fields (P0)
  final bool? reminderSent;
  final DateTime? reminderSentAt;
  final int? reminderCount;
  
  // Rating fields (P0)
  final int? ratingId;
  final DateTime? ratedAt;
  final DateTime? ratingRequestedAt;

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
    // Payment
    this.paymentStatus,
    this.paymentMethod,
    this.paymentTransactionId,
    this.paidAt,
    this.refundAmount,
    this.refundReason,
    this.refundedAt,
    // Cancellation
    this.cancelledById,
    this.cancelledReason,
    this.cancelledAt,
    this.cancellationFee,
    // Reminder
    this.reminderSent,
    this.reminderSentAt,
    this.reminderCount,
    // Rating
    this.ratingId,
    this.ratedAt,
    this.ratingRequestedAt,
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
      // Payment
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      paymentTransactionId: json['payment_transaction_id']?.toString(),
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'].toString()) : null,
      refundAmount: json['refund_amount'] != null ? double.tryParse(json['refund_amount'].toString()) : null,
      refundReason: json['refund_reason']?.toString(),
      refundedAt: json['refunded_at'] != null ? DateTime.tryParse(json['refunded_at'].toString()) : null,
      // Cancellation
      cancelledById: json['cancelled_by_id'] != null ? int.tryParse(json['cancelled_by_id'].toString()) : null,
      cancelledReason: json['cancelled_reason']?.toString(),
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'].toString()) : null,
      cancellationFee: json['cancellation_fee'] != null ? double.tryParse(json['cancellation_fee'].toString()) : null,
      // Reminder
      reminderSent: json['reminder_sent'] == 1 || json['reminder_sent'] == true,
      reminderSentAt: json['reminder_sent_at'] != null ? DateTime.tryParse(json['reminder_sent_at'].toString()) : null,
      reminderCount: json['reminder_count'] != null ? int.tryParse(json['reminder_count'].toString()) : null,
      // Rating
      ratingId: json['rating_id'] != null ? int.tryParse(json['rating_id'].toString()) : null,
      ratedAt: json['rated_at'] != null ? DateTime.tryParse(json['rated_at'].toString()) : null,
      ratingRequestedAt: json['rating_requested_at'] != null ? DateTime.tryParse(json['rating_requested_at'].toString()) : null,
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
      // Payment
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paymentTransactionId != null) 'payment_transaction_id': paymentTransactionId,
      if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
      if (refundAmount != null) 'refund_amount': refundAmount,
      if (refundReason != null) 'refund_reason': refundReason,
      if (refundedAt != null) 'refunded_at': refundedAt!.toIso8601String(),
      // Cancellation
      if (cancelledById != null) 'cancelled_by_id': cancelledById,
      if (cancelledReason != null) 'cancelled_reason': cancelledReason,
      if (cancelledAt != null) 'cancelled_at': cancelledAt!.toIso8601String(),
      if (cancellationFee != null) 'cancellation_fee': cancellationFee,
      // Reminder
      if (reminderSent != null) 'reminder_sent': reminderSent,
      if (reminderSentAt != null) 'reminder_sent_at': reminderSentAt!.toIso8601String(),
      if (reminderCount != null) 'reminder_count': reminderCount,
      // Rating
      if (ratingId != null) 'rating_id': ratingId,
      if (ratedAt != null) 'rated_at': ratedAt!.toIso8601String(),
      if (ratingRequestedAt != null) 'rating_requested_at': ratingRequestedAt!.toIso8601String(),
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
    String? paymentStatus,
    String? paymentMethod,
    String? paymentTransactionId,
    DateTime? paidAt,
    double? refundAmount,
    String? refundReason,
    DateTime? refundedAt,
    int? cancelledById,
    String? cancelledReason,
    DateTime? cancelledAt,
    double? cancellationFee,
    bool? reminderSent,
    DateTime? reminderSentAt,
    int? reminderCount,
    int? ratingId,
    DateTime? ratedAt,
    DateTime? ratingRequestedAt,
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
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      paidAt: paidAt ?? this.paidAt,
      refundAmount: refundAmount ?? this.refundAmount,
      refundReason: refundReason ?? this.refundReason,
      refundedAt: refundedAt ?? this.refundedAt,
      cancelledById: cancelledById ?? this.cancelledById,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      reminderSent: reminderSent ?? this.reminderSent,
      reminderSentAt: reminderSentAt ?? this.reminderSentAt,
      reminderCount: reminderCount ?? this.reminderCount,
      ratingId: ratingId ?? this.ratingId,
      ratedAt: ratedAt ?? this.ratedAt,
      ratingRequestedAt: ratingRequestedAt ?? this.ratingRequestedAt,
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

  // New P1 helper methods
  bool get canBeEdited => isPending && isUpcoming;
  bool get canBeRescheduled => isAccepted && isUpcoming;
  bool get canBeCompleted => isAccepted && isPast;
  bool get canBeRated => isCompleted && ratingId == null;
  
  // Payment helpers
  bool get isPaid => paymentStatus == 'paid';
  bool get isRefunded => refundedAt != null;
  
  // Rating helper
  bool get isRated => ratingId != null;

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
  
  String get paymentStatusText {
    switch (paymentStatus) {
      case 'paid':
        return 'Ödendi';
      case 'unpaid':
        return 'Ödenmedi';
      case 'refunded':
        return 'İade Edildi';
      case 'pending':
        return 'Beklemede';
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
        // Payment
        paymentStatus,
        paymentMethod,
        paymentTransactionId,
        paidAt,
        refundAmount,
        refundReason,
        refundedAt,
        // Cancellation
        cancelledById,
        cancelledReason,
        cancelledAt,
        cancellationFee,
        // Reminder
        reminderSent,
        reminderSentAt,
        reminderCount,
        // Rating
        ratingId,
        ratedAt,
        ratingRequestedAt,
      ];
}
