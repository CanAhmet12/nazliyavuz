import 'package:equatable/equatable.dart';
import 'dart:convert';
import 'user.dart';
import 'category.dart';

class Teacher extends Equatable {
  final int userId;
  final int? id; // Teacher ID
  final String? bio;
  final List<String>? education;
  final List<String>? certifications;
  final double? priceHour;
  final List<String>? languages;
  final double ratingAvg;
  final int ratingCount;
  final User? user;
  final List<Category>? categories;
  final bool onlineAvailable;
  final bool isApproved;
  final DateTime? approvedAt;
  final int? approvedBy;
  
  // Additional properties for enhanced UI
  final String? name;
  final String? specialization;
  final double? rating;
  final int? totalStudents;
  final int? totalLessons;
  final int? experienceYears;
  final String? profilePhotoUrl;
  final bool? isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Teacher({
    required this.userId,
    this.id,
    this.bio,
    this.education,
    this.certifications,
    this.priceHour,
    this.languages,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.user,
    this.categories,
    this.onlineAvailable = false,
    this.isApproved = false,
    this.approvedAt,
    this.approvedBy,
    // Additional properties
    this.name,
    this.specialization,
    this.rating,
    this.totalStudents,
    this.totalLessons,
    this.experienceYears,
    this.profilePhotoUrl,
    this.isAvailable,
    this.createdAt,
    this.updatedAt,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      userId: json['user_id'] ?? json['id'] ?? 0,
      id: json['id'],
      bio: json['bio']?.toString(),
      education: _parseStringList(json['education']),
      certifications: _parseStringList(json['certifications']),
      priceHour: _parseDouble(json['price_hour']),
      languages: _parseStringList(json['languages']),
      ratingAvg: _parseDouble(json['rating_avg']) ?? 0.0,
      ratingCount: json['rating_count'] ?? 0,
      user: json['user'] != null ? User.fromJson(json['user']) : 
            (json['name'] != null ? User.fromJson({
              'id': json['id'] ?? 0,
              'name': json['name'] ?? '',
              'email': json['email'] ?? '',
              'profile_photo_url': json['profile_photo_url']?.toString(),
            }) : null),
      categories: json['categories'] != null 
          ? (json['categories'] as List?)
              ?.map((category) => Category.fromJson(category))
              .toList()
          : null,
      onlineAvailable: json['online_available'] ?? false,
      isApproved: json['is_approved'] ?? false,
      approvedAt: json['approved_at'] != null 
          ? DateTime.tryParse(json['approved_at'].toString()) 
          : null,
      approvedBy: json['approved_by'],
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    
    // Eğer zaten List ise
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    
    // Eğer String ise (JSON string olabilir)
    if (value is String) {
      try {
        // JSON string'i parse et
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
        // Eğer tek bir string ise
        return [value];
      } catch (e) {
        // JSON değilse, virgülle ayrılmış string olabilir
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'bio': bio,
      'education': education,
      'certifications': certifications,
      'price_hour': priceHour,
      'languages': languages,
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
      'user': user?.toJson(),
      'categories': categories?.map((category) => category.toJson()).toList(),
      'online_available': onlineAvailable,
      'is_approved': isApproved,
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
    };
  }

  Teacher copyWith({
    int? userId,
    String? bio,
    List<String>? education,
    List<String>? certifications,
    double? priceHour,
    List<String>? languages,
    double? ratingAvg,
    int? ratingCount,
    User? user,
    List<Category>? categories,
    bool? onlineAvailable,
    bool? isApproved,
    DateTime? approvedAt,
    int? approvedBy,
  }) {
    return Teacher(
      userId: userId ?? this.userId,
      bio: bio ?? this.bio,
      education: education ?? this.education,
      certifications: certifications ?? this.certifications,
      priceHour: priceHour ?? this.priceHour,
      languages: languages ?? this.languages,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      user: user ?? this.user,
      categories: categories ?? this.categories,
      onlineAvailable: onlineAvailable ?? this.onlineAvailable,
      isApproved: isApproved ?? this.isApproved,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }

  String get formattedPrice {
    if (priceHour == null) return 'Fiyat belirtilmemiş';
    return '${priceHour!.toStringAsFixed(2)} TL/saat';
  }

  String get shortBio {
    if (bio == null || bio!.isEmpty) return 'Açıklama bulunmuyor';
    return bio!.length > 100 ? '${bio!.substring(0, 100)}...' : bio!;
  }

  String get displayName => name ?? user?.name ?? 'Bilinmeyen Öğretmen';

  @override
  List<Object?> get props => [
    userId,
    id,
    bio,
    education,
    certifications,
    priceHour,
    languages,
    ratingAvg,
    ratingCount,
    user,
    categories,
    onlineAvailable,
    isApproved,
    approvedAt,
    approvedBy,
    name,
    specialization,
    rating,
    totalStudents,
    totalLessons,
    experienceYears,
    profilePhotoUrl,
    isAvailable,
    createdAt,
    updatedAt,
  ];
}
