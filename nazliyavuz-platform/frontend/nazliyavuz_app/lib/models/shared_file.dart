import 'package:equatable/equatable.dart';
import 'user.dart';

class SharedFile extends Equatable {
  final int id;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final String description;
  final String category;
  final User uploadedBy;
  final User receiver;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SharedFile({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.description,
    required this.category,
    required this.uploadedBy,
    required this.receiver,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SharedFile.fromJson(Map<String, dynamic> json) {
    return SharedFile(
      id: json['id'],
      fileName: json['file_name'],
      fileUrl: json['file_url'],
      fileType: json['file_type'],
      fileSize: json['file_size'],
      description: json['description'] ?? '',
      category: json['category'],
      uploadedBy: User.fromJson(json['uploaded_by']),
      receiver: User.fromJson(json['receiver']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'description': description,
      'category': category,
      'uploaded_by': uploadedBy.toJson(),
      'receiver': receiver.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String get categoryInTurkish {
    const categories = {
      'document': 'Döküman',
      'homework': 'Ödev',
      'notes': 'Notlar',
      'resource': 'Kaynak',
      'other': 'Diğer',
    };
    return categories[category] ?? category;
  }

  String get fileIcon {
    if (fileType.startsWith('image/')) {
      return 'image';
    } else if (fileType.startsWith('video/')) {
      return 'video';
    } else if (fileType.startsWith('audio/')) {
      return 'audio';
    } else if (fileType == 'application/pdf') {
      return 'picture_as_pdf';
    } else if (fileType.startsWith('application/')) {
      return 'description';
    } else if (fileType.startsWith('text/')) {
      return 'text_snippet';
    } else {
      return 'insert_drive_file';
    }
  }

  bool get isImage => fileType.startsWith('image/');
  bool get isVideo => fileType.startsWith('video/');
  bool get isAudio => fileType.startsWith('audio/');
  bool get isPdf => fileType == 'application/pdf';
  bool get isDocument => fileType.startsWith('application/') && !isPdf;

  String get fileExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  String get fileNameWithoutExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.sublist(0, parts.length - 1).join('.') : fileName;
  }

  @override
  List<Object?> get props => [
        id,
        fileName,
        fileUrl,
        fileType,
        fileSize,
        description,
        category,
        uploadedBy,
        receiver,
        createdAt,
        updatedAt,
      ];
}
