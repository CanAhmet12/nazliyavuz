import 'package:equatable/equatable.dart';

class Assignment extends Equatable {
  final int id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String difficulty;
  final String status;
  final String? grade;
  final String? feedback;
  final String? submissionNotes;
  final String? submissionFileName;
  final String? submissionFilePath;
  final DateTime? submittedAt;
  final DateTime? gradedAt;
  final String? teacherName;
  final String? studentName;
  final int? studentId;
  final int? teacherId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.difficulty,
    required this.status,
    this.grade,
    this.feedback,
    this.submissionNotes,
    this.submissionFileName,
    this.submissionFilePath,
    this.submittedAt,
    this.gradedAt,
    this.teacherName,
    this.studentName,
    this.studentId,
    this.teacherId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    try {
      // Safe string extraction with null checks
      String safeString(dynamic value, String defaultValue) {
        if (value == null) return defaultValue;
        final str = value.toString();
        return str.isEmpty ? defaultValue : str;
      }
      
      // Safe int extraction
      int safeInt(dynamic value, int defaultValue) {
        if (value == null) return defaultValue;
        if (value is int) return value;
        return int.tryParse(value.toString()) ?? defaultValue;
      }
      
      // Safe DateTime extraction
      DateTime safeDateTime(dynamic value, DateTime defaultValue) {
        if (value == null) return defaultValue;
        return DateTime.tryParse(value.toString()) ?? defaultValue;
      }
      
      // Safe string extraction for nested objects
      String? _safeString(dynamic value) {
        if (value == null) return null;
        final str = value.toString();
        return str.isEmpty ? null : str;
      }
      
      return Assignment(
        id: safeInt(json['id'], 0),
        title: safeString(json['title'], 'Başlık Yok'),
        description: safeString(json['description'], 'Açıklama Yok'),
        dueDate: safeDateTime(json['due_date'], DateTime.now().add(const Duration(days: 7))),
        difficulty: safeString(json['difficulty'], 'medium'),
        status: safeString(json['status'], 'pending'),
        grade: _safeString(json['grade']),
        feedback: _safeString(json['feedback']),
        submissionNotes: _safeString(json['submission_notes']),
        submissionFileName: _safeString(json['submission_file_name']),
        submissionFilePath: _safeString(json['submission_file_path']),
        submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at'].toString()) : null,
        gradedAt: json['graded_at'] != null ? DateTime.tryParse(json['graded_at'].toString()) : null,
        teacherName: _safeString(json['teacher']?['name']) ?? _safeString(json['teacher_name']),
        studentName: _safeString(json['student']?['name']) ?? _safeString(json['student_name']),
        studentId: json['student_id'] != null ? safeInt(json['student_id'], 0) : null,
        teacherId: json['teacher_id'] != null ? safeInt(json['teacher_id'], 0) : null,
        createdAt: safeDateTime(json['created_at'], DateTime.now()),
        updatedAt: safeDateTime(json['updated_at'], DateTime.now()),
      );
    } catch (e) {
      print('Assignment.fromJson error: $e');
      print('JSON: $json');
      // Fallback assignment with safe defaults
      return Assignment(
        id: 0,
        title: 'Hatalı Ödev',
        description: 'Bu ödev yüklenirken hata oluştu',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        difficulty: 'medium',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'difficulty': difficulty,
      'status': status,
      'grade': grade,
      'feedback': feedback,
      'submission_notes': submissionNotes,
      'submission_file_name': submissionFileName,
      'submission_file_path': submissionFilePath,
      'submitted_at': submittedAt?.toIso8601String(),
      'graded_at': gradedAt?.toIso8601String(),
      'teacher_name': teacherName,
      'student_name': studentName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get difficultyInTurkish {
    const difficulties = {
      'easy': 'Kolay',
      'medium': 'Orta',
      'hard': 'Zor',
    };
    return difficulties[difficulty] ?? difficulty;
  }

  String get statusInTurkish {
    const statuses = {
      'pending': 'Bekliyor',
      'submitted': 'Teslim Edildi',
      'graded': 'Değerlendirildi',
      'overdue': 'Gecikti',
    };
    return statuses[status] ?? status;
  }

  String get statusText => statusInTurkish;

  String get formattedDueDate {
    return '${dueDate.day}/${dueDate.month}/${dueDate.year} ${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}';
  }

  bool get isOverdue {
    return status == 'pending' && dueDate.isBefore(DateTime.now());
  }

  bool get isSubmitted {
    return status == 'submitted' || status == 'graded';
  }

  bool get isGraded {
    return status == 'graded' && grade != null;
  }

  String get timeUntilDue {
    if (isSubmitted || isGraded) {
      return '';
    }

    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.isNegative) {
      return 'Gecikti';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays} gün kaldı';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat kaldı';
    } else {
      return '${difference.inMinutes} dakika kaldı';
    }
  }

  String get gradeColor {
    if (grade == null) return 'grey';
    
    switch (grade) {
      case 'A+':
      case 'A':
        return 'green';
      case 'B+':
      case 'B':
        return 'lightgreen';
      case 'C+':
      case 'C':
        return 'orange';
      case 'D+':
      case 'D':
        return 'red';
      case 'F':
        return 'darkred';
      default:
        return 'grey';
    }
  }

  String get timeSinceCreated {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  String get timeSinceSubmitted {
    if (submittedAt == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(submittedAt!);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  String get timeSinceGraded {
    if (gradedAt == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(gradedAt!);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    dueDate,
    difficulty,
    status,
    grade,
    feedback,
    submissionNotes,
    submissionFileName,
    submissionFilePath,
    submittedAt,
    gradedAt,
    teacherName,
    studentName,
    studentId,
    teacherId,
    createdAt,
    updatedAt,
  ];
}