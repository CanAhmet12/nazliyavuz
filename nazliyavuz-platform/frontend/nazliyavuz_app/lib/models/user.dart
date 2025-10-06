import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? bio;
  final String? profilePhotoUrl;
  final DateTime? verifiedAt;
  final DateTime? emailVerifiedAt;
  final String? teacherStatus;
  final String? adminNotes;
  final int? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final String? rejectionReason;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.bio,
    this.profilePhotoUrl,
    this.verifiedAt,
    this.emailVerifiedAt,
    this.teacherStatus,
    this.adminNotes,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.rejectionReason,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      phone: json['phone']?.toString(),
      bio: json['bio']?.toString(),
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      verifiedAt: json['verified_at'] != null 
          ? DateTime.tryParse(json['verified_at'].toString()) 
          : null,
      emailVerifiedAt: json['email_verified_at'] != null 
          ? DateTime.tryParse(json['email_verified_at'].toString()) 
          : null,
      teacherStatus: json['teacher_status']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'] != null 
          ? DateTime.tryParse(json['approved_at'].toString()) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
      rejectionReason: json['rejection_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'bio': bio,
      'profile_photo_url': profilePhotoUrl,
      'verified_at': verifiedAt?.toIso8601String(),
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'teacher_status': teacherStatus,
      'admin_notes': adminNotes,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? bio,
    String? profilePhotoUrl,
    DateTime? verifiedAt,
    DateTime? emailVerifiedAt,
    String? teacherStatus,
    String? adminNotes,
    int? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
    String? rejectionReason,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      teacherStatus: teacherStatus ?? this.teacherStatus,
      adminNotes: adminNotes ?? this.adminNotes,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
  bool get isAdmin => role == 'admin';
  bool get isTeacherApproved => isTeacher && teacherStatus == 'approved';
  bool get isTeacherPending => isTeacher && teacherStatus == 'pending';
  bool get isTeacherRejected => isTeacher && teacherStatus == 'rejected';


  @override
  List<Object?> get props => [
        id,
        name,
        email,
        role,
        phone,
        bio,
        profilePhotoUrl,
        verifiedAt,
        emailVerifiedAt,
        teacherStatus,
        adminNotes,
        approvedBy,
        approvedAt,
        createdAt,
        rejectionReason,
      ];
}
