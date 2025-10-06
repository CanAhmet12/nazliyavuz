import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class FileUploadScreen extends StatefulWidget {
  final String uploadType;
  final Function(String)? onUploadComplete;

  const FileUploadScreen({
    super.key,
    required this.uploadType,
    this.onUploadComplete,
  });

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  
  XFile? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadedUrl;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUploadSection(),
            const SizedBox(height: 24),
            if (_selectedFile != null) _buildFilePreview(),
            const SizedBox(height: 24),
            if (_isUploading) _buildUploadProgress(),
            if (_uploadedUrl != null) _buildUploadSuccess(),
            if (_errorMessage != null) _buildErrorMessage(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (widget.uploadType) {
      case 'profile_photo':
        return 'Profil Fotoğrafı Yükle';
      case 'document':
        return 'Doküman Yükle';
      default:
        return 'Dosya Yükle';
    }
  }

  Widget _buildUploadSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dosya Seç',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildUploadButton(
                    'Kameradan Çek',
                    Icons.camera_alt,
                    () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUploadButton(
                    'Galeriden Seç',
                    Icons.photo_library,
                    () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.uploadType == 'document')
              _buildUploadButton(
                'Dosya Seç',
                Icons.attach_file,
                _pickDocument,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton(String title, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: _isUploading ? null : onPressed,
      icon: Icon(icon),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildFilePreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seçilen Dosya',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_isImageFile())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _selectedFile!.path,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image, size: 40),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.insert_drive_file, size: 40),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFile!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<int>(
                        future: _selectedFile!.length(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              _formatFileSize(snapshot.data!),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            );
                          }
                          return Text(
                            'Dosya boyutu hesaplanıyor...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFileType(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedFile = null;
                      _errorMessage = null;
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Yükleniyor...'),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Text(
              '${(_uploadProgress * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSuccess() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yükleme Başarılı!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dosya başarıyla yüklendi.',
                    style: TextStyle(color: Colors.green[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yükleme Hatası',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _selectedFile != null && !_isUploading ? _uploadFile : null,
            child: const Text('Yükle'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedFile = image;
          _errorMessage = null;
          _uploadedUrl = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Resim seçilirken hata oluştu: $e';
      });
    }
  }

  Future<void> _pickDocument() async {
    // For document picking, you would typically use file_picker package
    // For now, we'll show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Doküman seçme özelliği yakında eklenecek'),
      ),
    );
  }

  bool _isImageFile() {
    if (_selectedFile == null) return false;
    final extension = _selectedFile!.path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getFileType() {
    if (_selectedFile == null) return '';
    final extension = _selectedFile!.path.toLowerCase().split('.').last;
    return extension.toUpperCase();
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      // Method 1: Direct upload (for smaller files)
      final fileSize = await _selectedFile!.length();
      if (fileSize < 5 * 1024 * 1024) { // 5MB
        await _directUpload();
      } else {
        // Method 2: Presigned URL upload (for larger files)
        await _presignedUpload();
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Yükleme hatası: $e';
      });
    }
  }

  Future<void> _directUpload() async {
    try {
      final result = await _apiService.uploadFile('/upload/profile-photo', _selectedFile!, {});
      
      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
        _uploadedUrl = result['url'];
      });

      if (widget.onUploadComplete != null) {
        widget.onUploadComplete!(_uploadedUrl!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dosya başarıyla yüklendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      throw Exception('Direct upload failed: $e');
    }
  }

  Future<void> _presignedUpload() async {
    try {
      // Step 1: Get presigned URL
      final presignedResult = await _apiService.generatePresignedUrl(
        _selectedFile!.name,
        _getContentType(),
      );

      if (!presignedResult['success']) {
        throw Exception('Presigned URL alınamadı');
      }

      // Step 2: Upload to S3 using presigned URL
      final dio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          _selectedFile!.path,
          filename: _selectedFile!.name,
        ),
      });

      await dio.put(
        presignedResult['presigned_url'],
        data: formData,
        onSendProgress: (sent, total) {
          setState(() {
            _uploadProgress = sent / total;
          });
        },
      );

      // Step 3: Confirm upload
      final confirmResult = await _apiService.confirmUpload(
        presignedResult['path'],
        presignedResult['filename'],
        widget.uploadType,
      );

      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
        _uploadedUrl = confirmResult['url'];
      });

      if (widget.onUploadComplete != null) {
        widget.onUploadComplete!(_uploadedUrl!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dosya başarıyla yüklendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      throw Exception('Presigned upload failed: $e');
    }
  }

  String _getContentType() {
    if (_selectedFile == null) return 'application/octet-stream';
    
    final extension = _selectedFile!.path.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      default:
        return 'application/octet-stream';
    }
  }
}
