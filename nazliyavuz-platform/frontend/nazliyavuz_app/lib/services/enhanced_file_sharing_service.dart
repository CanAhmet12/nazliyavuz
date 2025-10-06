import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'api_service.dart';

/// Enhanced File Sharing Service with advanced features
class EnhancedFileSharingService {
  static final EnhancedFileSharingService _instance = EnhancedFileSharingService._internal();
  factory EnhancedFileSharingService() => _instance;
  EnhancedFileSharingService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, StreamController<Map<String, dynamic>>> _streamControllers = {};
  final Map<String, FileUploadProgress> _uploadProgress = {};

  /// Supported file types
  static const Map<String, List<String>> supportedFileTypes = {
    'images': ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
    'documents': ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
    'videos': ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm'],
    'audio': ['mp3', 'wav', 'aac', 'ogg', 'm4a'],
    'archives': ['zip', 'rar', '7z', 'tar', 'gz'],
  };

  /// Maximum file sizes (in bytes)
  static const Map<String, int> maxFileSizes = {
    'images': 10 * 1024 * 1024, // 10MB
    'documents': 50 * 1024 * 1024, // 50MB
    'videos': 200 * 1024 * 1024, // 200MB
    'audio': 50 * 1024 * 1024, // 50MB
    'archives': 100 * 1024 * 1024, // 100MB
  };

  /// Pick image from gallery or camera
  Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      // Check permissions
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          throw Exception('Camera permission required');
        }
      } else {
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted) {
          throw Exception('Photos permission required');
        }
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality ?? 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('Pick image error: $e');
      rethrow;
    }
  }

  /// Pick multiple images
  Future<List<File>> pickMultipleImages({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    int limit = 10,
  }) async {
    try {
      final photosStatus = await Permission.photos.request();
      if (!photosStatus.isGranted) {
        throw Exception('Photos permission required');
      }

      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality ?? 85,
      );

      return pickedFiles.take(limit).map((file) => File(file.path)).toList();
    } catch (e) {
      debugPrint('Pick multiple images error: $e');
      rethrow;
    }
  }

  /// Pick file from device
  Future<File?> pickFile({
    List<String>? allowedExtensions,
    String? type,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      debugPrint('Pick file error: $e');
      rethrow;
    }
  }

  /// Pick multiple files
  Future<List<File>> pickMultipleFiles({
    List<String>? allowedExtensions,
    String? type,
    int limit = 10,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result != null) {
        return result.files
            .where((file) => file.path != null)
            .take(limit)
            .map((file) => File(file.path!))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Pick multiple files error: $e');
      rethrow;
    }
  }

  /// Validate file
  bool validateFile(File file) {
    try {
      final fileName = file.path.split('/').last.toLowerCase();
      final extension = fileName.split('.').last;
      
      // Check file size
      final fileSize = file.lengthSync();
      final fileType = _getFileType(extension);
      
      if (fileType != null && maxFileSizes.containsKey(fileType)) {
        if (fileSize > maxFileSizes[fileType]!) {
          return false;
        }
      } else if (fileSize > 100 * 1024 * 1024) { // 100MB default limit
        return false;
      }

      // Check file extension
      if (fileType != null && supportedFileTypes.containsKey(fileType)) {
        return supportedFileTypes[fileType]!.contains(extension);
      }

      return true; // Allow unknown file types
    } catch (e) {
      debugPrint('Validate file error: $e');
      return false;
    }
  }

  /// Get file type from extension
  String? _getFileType(String extension) {
    for (final entry in supportedFileTypes.entries) {
      if (entry.value.contains(extension)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Upload file to chat
  Future<Map<String, dynamic>> uploadFileToChat({
    required File file,
    required int receiverId,
    int? chatId,
    String? caption,
    Map<String, dynamic>? metadata,
  }) async {
    if (!validateFile(file)) {
      return {
        'success': false,
        'message': 'Invalid file type or size',
      };
    }

    final uploadId = _generateUploadId();
    _uploadProgress[uploadId] = FileUploadProgress(
      id: uploadId,
      fileName: file.path.split('/').last,
      fileSize: file.lengthSync(),
      progress: 0,
      status: 'uploading',
    );

    try {
      final response = await ApiService().uploadFile('/chat/upload-file', XFile(file.path), {
        'receiver_id': receiverId,
        'chat_id': chatId,
        'caption': caption,
        'metadata': metadata,
      });

      _uploadProgress[uploadId]?.status = response['success'] ? 'completed' : 'failed';
      _uploadProgress[uploadId]?.progress = 100;

      _streamControllers['upload-progress']?.add({
        'upload_id': uploadId,
        'progress': 100,
        'status': _uploadProgress[uploadId]?.status,
        'response': response,
      });

      return response;
    } catch (e) {
      _uploadProgress[uploadId]?.status = 'failed';
      _streamControllers['upload-progress']?.add({
        'upload_id': uploadId,
        'progress': 0,
        'status': 'failed',
        'error': e.toString(),
      });

      return {
        'success': false,
        'message': 'Upload failed: $e',
      };
    }
  }

  /// Upload assignment file
  Future<Map<String, dynamic>> uploadAssignmentFile({
    required File file,
    required int assignmentId,
    String? notes,
  }) async {
    if (!validateFile(file)) {
      return {
        'success': false,
        'message': 'Invalid file type or size',
      };
    }

    final uploadId = _generateUploadId();
    _uploadProgress[uploadId] = FileUploadProgress(
      id: uploadId,
      fileName: file.path.split('/').last,
      fileSize: file.lengthSync(),
      progress: 0,
      status: 'uploading',
    );

    try {
      final response = await ApiService().uploadFile('/assignments/upload-submission', XFile(file.path), {
        'assignment_id': assignmentId,
        'notes': notes,
      });

      _uploadProgress[uploadId]?.status = response['success'] ? 'completed' : 'failed';
      _uploadProgress[uploadId]?.progress = 100;

      return response;
    } catch (e) {
      _uploadProgress[uploadId]?.status = 'failed';
      return {
        'success': false,
        'message': 'Upload failed: $e',
      };
    }
  }

  /// Upload profile photo
  Future<Map<String, dynamic>> uploadProfilePhoto({
    required File file,
    String? cropData,
  }) async {
    if (!validateFile(file)) {
      return {
        'success': false,
        'message': 'Invalid file type or size',
      };
    }

    final uploadId = _generateUploadId();
    _uploadProgress[uploadId] = FileUploadProgress(
      id: uploadId,
      fileName: file.path.split('/').last,
      fileSize: file.lengthSync(),
      progress: 0,
      status: 'uploading',
    );

    try {
      final response = await ApiService().uploadFile('/profile/upload-photo', XFile(file.path), {
        'crop_data': cropData,
      });

      _uploadProgress[uploadId]?.status = response['success'] ? 'completed' : 'failed';
      _uploadProgress[uploadId]?.progress = 100;

      return response;
    } catch (e) {
      _uploadProgress[uploadId]?.status = 'failed';
      return {
        'success': false,
        'message': 'Upload failed: $e',
      };
    }
  }

  /// Download file
  Future<File?> downloadFile({
    required String fileUrl,
    required String fileName,
    String? directory,
  }) async {
    try {
      final dir = directory != null 
          ? Directory(directory) 
          : await getApplicationDocumentsDirectory();
      
      final file = File('${dir.path}/$fileName');
      
      final response = await ApiService().downloadFileFromUrl(fileUrl);
      if (response != null) {
        await file.writeAsBytes(response);
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Download file error: $e');
      return null;
    }
  }

  /// Get file thumbnail
  Future<Uint8List?> getFileThumbnail({
    required String fileUrl,
    String? fileType,
  }) async {
    try {
      final response = await ApiService().get('/files/thumbnail?file_url=$fileUrl&file_type=${fileType ?? ''}');

      if (response['success'] && response['thumbnail'] != null) {
        return base64Decode(response['thumbnail']);
      }
      return null;
    } catch (e) {
      debugPrint('Get file thumbnail error: $e');
      return null;
    }
  }

  /// Get file info
  Future<Map<String, dynamic>?> getFileInfo(String fileUrl) async {
    try {
      final response = await ApiService().get('/files/info?file_url=$fileUrl');

      if (response['success']) {
        return response['file_info'];
      }
      return null;
    } catch (e) {
      debugPrint('Get file info error: $e');
      return null;
    }
  }

  /// Delete file
  Future<bool> deleteFile(String fileUrl) async {
    try {
      final response = await ApiService().delete('/files/delete?file_url=$fileUrl');

      return response['success'] ?? false;
    } catch (e) {
      debugPrint('Delete file error: $e');
      return false;
    }
  }

  /// Get file sharing statistics
  Future<Map<String, dynamic>> getFileSharingStatistics() async {
    try {
      final response = await ApiService().get('/files/statistics');

      if (response['success']) {
        return response['statistics'] ?? {};
      }
      return {};
    } catch (e) {
      debugPrint('Get file sharing statistics error: $e');
      return {};
    }
  }

  /// Get recent files
  Future<List<Map<String, dynamic>>> getRecentFiles({
    int limit = 20,
    String? fileType,
  }) async {
    try {
      final response = await ApiService().get('/files/recent?limit=$limit&file_type=${fileType ?? ''}');

      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['files'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Get recent files error: $e');
      return [];
    }
  }

  /// Get upload progress stream
  Stream<Map<String, dynamic>> getUploadProgressStream() {
    if (!_streamControllers.containsKey('upload-progress')) {
      _streamControllers['upload-progress'] = StreamController<Map<String, dynamic>>.broadcast();
    }
    
    return _streamControllers['upload-progress']!.stream;
  }

  /// Get file upload progress
  FileUploadProgress? getUploadProgress(String uploadId) {
    return _uploadProgress[uploadId];
  }

  /// Cancel upload
  Future<void> cancelUpload(String uploadId) async {
    try {
      await ApiService().post('/files/cancel-upload', {
        'upload_id': uploadId,
      });

      _uploadProgress[uploadId]?.status = 'cancelled';
      _streamControllers['upload-progress']?.add({
        'upload_id': uploadId,
        'status': 'cancelled',
      });
    } catch (e) {
      debugPrint('Cancel upload error: $e');
    }
  }

  /// Generate unique upload ID
  String _generateUploadId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    return md5.convert(utf8.encode(random)).toString();
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get file icon
  static IconData getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    if (supportedFileTypes['images']!.contains(extension)) {
      return Icons.image;
    } else if (supportedFileTypes['documents']!.contains(extension)) {
      if (['pdf'].contains(extension)) return Icons.picture_as_pdf;
      if (['doc', 'docx'].contains(extension)) return Icons.description;
      if (['xls', 'xlsx'].contains(extension)) return Icons.table_chart;
      if (['ppt', 'pptx'].contains(extension)) return Icons.slideshow;
      return Icons.insert_drive_file;
    } else if (supportedFileTypes['videos']!.contains(extension)) {
      return Icons.video_file;
    } else if (supportedFileTypes['audio']!.contains(extension)) {
      return Icons.audio_file;
    } else if (supportedFileTypes['archives']!.contains(extension)) {
      return Icons.archive;
    }
    
    return Icons.insert_drive_file;
  }

  /// Dispose resources
  void dispose() {
    _streamControllers.values.forEach((controller) => controller.close());
    _streamControllers.clear();
    _uploadProgress.clear();
  }
}

/// File upload progress model
class FileUploadProgress {
  final String id;
  final String fileName;
  final int fileSize;
  double progress;
  String status; // 'uploading', 'completed', 'failed', 'cancelled'

  FileUploadProgress({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.progress,
    required this.status,
  });

  String get formattedSize => EnhancedFileSharingService.formatFileSize(fileSize);
  
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isUploading => status == 'uploading';
}
