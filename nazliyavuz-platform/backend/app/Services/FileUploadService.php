<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class FileUploadService
{
    /**
     * Upload profile photo to S3
     */
    public function uploadProfilePhoto(UploadedFile $file, int $userId): array
    {
        try {
            // Validate file
            $this->validateImageFile($file);

            // Generate unique filename
            $filename = 'profile_' . $userId . '_' . time() . '.' . $file->getClientOriginalExtension();
            $path = 'profile-photos/' . $filename;

            // Upload to S3
            $uploadedPath = $file->storeAs('profile-photos', $filename, 's3');

            // Get public URL
            $s3Disk = Storage::disk('s3');
            $url = config('filesystems.disks.s3.url') . '/' . $uploadedPath;

            Log::info('Profile photo uploaded to S3', [
                'user_id' => $userId,
                'path' => $uploadedPath,
                'url' => $url
            ]);

            return [
                'success' => true,
                'path' => $uploadedPath,
                'url' => $url,
                'filename' => $filename
            ];
        } catch (\Exception $e) {
            Log::error('Failed to upload profile photo to S3', [
                'user_id' => $userId,
                'error' => $e->getMessage()
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Upload document to S3
     */
    public function uploadDocument(UploadedFile $file, int $userId, string $type = 'document'): array
    {
        try {
            // Validate document
            $this->validateDocumentFile($file);

            // Generate unique filename
            $filename = $type . '_' . $userId . '_' . time() . '.' . $file->getClientOriginalExtension();
            $path = 'documents/' . $type . '/' . $filename;

            // Upload to S3
            $uploadedPath = $file->storeAs('documents/' . $type, $filename, 's3');

            // Get public URL
            $s3Disk = Storage::disk('s3');
            $url = config('filesystems.disks.s3.url') . '/' . $uploadedPath;

            Log::info('Document uploaded to S3', [
                'user_id' => $userId,
                'type' => $type,
                'path' => $uploadedPath,
                'url' => $url
            ]);

            return [
                'success' => true,
                'path' => $uploadedPath,
                'url' => $url,
                'filename' => $filename,
                'type' => $type
            ];
        } catch (\Exception $e) {
            Log::error('Failed to upload document to S3', [
                'user_id' => $userId,
                'type' => $type,
                'error' => $e->getMessage()
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Delete file from S3
     */
    public function deleteFile(string $path): bool
    {
        try {
            if (Storage::disk('s3')->exists($path)) {
                Storage::disk('s3')->delete($path);
                
                Log::info('File deleted from S3', ['path' => $path]);
                return true;
            }

            return false;
        } catch (\Exception $e) {
            Log::error('Failed to delete file from S3', [
                'path' => $path,
                'error' => $e->getMessage()
            ]);

            return false;
        }
    }


    /**
     * Validate image file
     */
    private function validateImageFile(UploadedFile $file): void
    {
        $allowedMimes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
        $maxSize = 5 * 1024 * 1024; // 5MB

        if (!in_array($file->getMimeType(), $allowedMimes)) {
            throw new \InvalidArgumentException('Geçersiz dosya formatı. Sadece JPEG, PNG, GIF ve WebP formatları desteklenir.');
        }

        if ($file->getSize() > $maxSize) {
            throw new \InvalidArgumentException('Dosya boyutu çok büyük. Maksimum 5MB olmalıdır.');
        }
    }

    /**
     * Validate document file
     */
    private function validateDocumentFile(UploadedFile $file): void
    {
        $allowedMimes = [
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'image/jpeg',
            'image/png',
            'image/gif'
        ];
        $maxSize = 10 * 1024 * 1024; // 10MB

        if (!in_array($file->getMimeType(), $allowedMimes)) {
            throw new \InvalidArgumentException('Geçersiz dosya formatı. Sadece PDF, DOC, DOCX ve resim formatları desteklenir.');
        }

        if ($file->getSize() > $maxSize) {
            throw new \InvalidArgumentException('Dosya boyutu çok büyük. Maksimum 10MB olmalıdır.');
        }
    }

    /**
     * Generate presigned URL for direct upload to S3
     */
    public function generatePresignedUrl(string $filename, string $contentType, int $userId): array
    {
        try {
            // Validate file type
            $this->validateFileType($contentType);
            
            // Generate unique filename
            $uniqueFilename = $userId . '_' . time() . '_' . Str::random(10) . '_' . $filename;
            $path = 'uploads/' . $uniqueFilename;
            
            // Generate presigned URL using AWS SDK
            $s3Client = new \Aws\S3\S3Client([
                'version' => 'latest',
                'region' => config('filesystems.disks.s3.region'),
                'credentials' => [
                    'key' => config('filesystems.disks.s3.key'),
                    'secret' => config('filesystems.disks.s3.secret'),
                ],
            ]);
            
            $command = $s3Client->getCommand('PutObject', [
                'Bucket' => config('filesystems.disks.s3.bucket'),
                'Key' => $path,
                'ContentType' => $contentType,
            ]);

            $request = $s3Client->createPresignedRequest($command, "+15 minutes");
            $presignedUrl = (string) $request->getUri();
            
            Log::info('Presigned URL generated', [
                'user_id' => $userId,
                'filename' => $uniqueFilename,
                'content_type' => $contentType
            ]);
            
            return [
                'success' => true,
                'presigned_url' => $presignedUrl,
                'path' => $path,
                'filename' => $uniqueFilename,
                'expires_in' => 900 // 15 minutes
            ];
        } catch (\Exception $e) {
            Log::error('Failed to generate presigned URL', [
                'user_id' => $userId,
                'error' => $e->getMessage()
            ]);
            
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Validate file type
     */
    private function validateFileType(string $contentType): void
    {
        $allowedTypes = [
            'image/jpeg',
            'image/png',
            'image/gif',
            'image/webp',
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'text/plain',
            'application/zip',
            'application/x-rar-compressed'
        ];

        if (!in_array($contentType, $allowedTypes)) {
            throw new \InvalidArgumentException('Desteklenmeyen dosya türü: ' . $contentType);
        }
    }

    /**
     * Get temporary URL for file download
     */
    public function getTemporaryUrl(string $filePath, int $minutes = 5): string
    {
        try {
            // Generate presigned URL for temporary access
            $s3Client = new \Aws\S3\S3Client([
                'version' => 'latest',
                'region' => config('filesystems.disks.s3.region'),
                'credentials' => [
                    'key' => config('filesystems.disks.s3.key'),
                    'secret' => config('filesystems.disks.s3.secret'),
                ],
            ]);
            
            $command = $s3Client->getCommand('GetObject', [
                'Bucket' => config('filesystems.disks.s3.bucket'),
                'Key' => $filePath,
            ]);

            $request = $s3Client->createPresignedRequest($command, "+{$minutes} minutes");
            return (string) $request->getUri();
        } catch (\Exception $e) {
            Log::error('Failed to generate temporary URL', [
                'file_path' => $filePath,
                'error' => $e->getMessage(),
            ]);
            
            // Fallback to public URL
            return config('filesystems.disks.s3.url') . '/' . $filePath;
        }
    }

    /**
     * Get file info
     */
    public function getFileInfo(string $path): array
    {
        try {
            if (!Storage::disk('s3')->exists($path)) {
                return [
                    'success' => false,
                    'error' => 'Dosya bulunamadı'
                ];
            }

            $url = config('filesystems.disks.s3.url') . '/' . $path;
            $size = Storage::disk('s3')->size($path);
            $lastModified = Storage::disk('s3')->lastModified($path);

            return [
                'success' => true,
                'path' => $path,
                'url' => $url,
                'size' => $size,
                'last_modified' => $lastModified
            ];
        } catch (\Exception $e) {
            Log::error('Failed to get file info', [
                'path' => $path,
                'error' => $e->getMessage()
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }
}
