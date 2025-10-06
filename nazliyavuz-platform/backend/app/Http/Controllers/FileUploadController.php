<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use App\Models\User;

class FileUploadController extends Controller
{
    /**
     * Upload profile photo
     */
    public function uploadProfilePhoto(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'photo' => 'required|image|mimes:jpeg,png,jpg,gif|max:2048', // 2MB max
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz dosya formatı',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = Auth::user();
            $file = $request->file('photo');
            
            // Delete old profile photo if exists
            if ($user->profile_photo_url) {
                $oldPath = str_replace('/storage/', '', $user->profile_photo_url);
                if (Storage::disk('public')->exists($oldPath)) {
                    Storage::disk('public')->delete($oldPath);
                }
            }
            
            // Generate unique filename
            $filename = 'profile_' . $user->id . '_' . time() . '.' . $file->getClientOriginalExtension();
            $filePath = $file->storeAs('profile_photos', $filename, 'public');
            
            // Update user profile photo URL
            $user->update([
                'profile_photo_url' => Storage::disk('public')->url($filePath)
            ]);
            
            return response()->json([
                'success' => true,
                'message' => 'Profil fotoğrafı başarıyla güncellendi',
                'profile_photo_url' => $user->profile_photo_url
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error uploading profile photo: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'PHOTO_UPLOAD_ERROR',
                    'message' => 'Profil fotoğrafı yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Delete profile photo
     */
    public function deleteProfilePhoto(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            if ($user->profile_photo_url) {
                // Delete file from storage
                $filePath = str_replace('/storage/', '', $user->profile_photo_url);
                if (Storage::disk('public')->exists($filePath)) {
                    Storage::disk('public')->delete($filePath);
                }
                
                // Update user profile photo URL
                $user->update([
                    'profile_photo_url' => null
                ]);
            }
            
            return response()->json([
                'success' => true,
                'message' => 'Profil fotoğrafı başarıyla silindi'
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error deleting profile photo: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'PHOTO_DELETE_ERROR',
                    'message' => 'Profil fotoğrafı silinirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Upload document
     */
    public function uploadDocument(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'document' => 'required|file|mimes:pdf,doc,docx,txt|max:10240', // 10MB max
            'type' => 'required|string|in:certificate,diploma,cv,other',
            'description' => 'nullable|string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz dosya formatı',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = Auth::user();
            $file = $request->file('document');
            
            // Generate unique filename
            $filename = 'doc_' . $user->id . '_' . time() . '_' . $file->getClientOriginalName();
            $filePath = $file->storeAs('documents', $filename, 'public');
            
            // Store document info in user's documents field (JSON)
            $documents = $user->documents ?? [];
            $documents[] = [
                'name' => $file->getClientOriginalName(),
                'file_path' => $filePath,
                'file_size' => $file->getSize(),
                'mime_type' => $file->getMimeType(),
                'type' => $request->type,
                'description' => $request->description,
                'uploaded_at' => now()->toISOString(),
            ];
            
            $user->update([
                'documents' => $documents
            ]);
            
            return response()->json([
                'success' => true,
                'message' => 'Doküman başarıyla yüklendi',
                'document' => [
                    'name' => $file->getClientOriginalName(),
                    'type' => $request->type,
                    'file_size' => $file->getSize(),
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error uploading document: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'DOCUMENT_UPLOAD_ERROR',
                    'message' => 'Doküman yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Generate presigned URL for direct upload
     */
    public function generatePresignedUrl(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'filename' => 'required|string|max:255',
            'content_type' => 'required|string|max:100',
            'file_size' => 'required|integer|max:10485760', // 10MB max
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Geçersiz veri',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        try {
            $user = Auth::user();
            
            // Generate unique filename
            $extension = pathinfo($request->filename, PATHINFO_EXTENSION);
            $filename = 'upload_' . $user->id . '_' . time() . '.' . $extension;
            $filePath = 'uploads/' . $filename;
            
            // For now, return a simple upload URL
            // In production, you would integrate with AWS S3 or similar service
            $uploadUrl = route('api.v1.upload.direct', ['filename' => $filename]);
            
            return response()->json([
                'success' => true,
                'upload_url' => $uploadUrl,
                'filename' => $filename,
                'expires_in' => 3600, // 1 hour
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error generating presigned URL: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'PRESIGNED_URL_ERROR',
                    'message' => 'Upload URL oluşturulurken bir hata oluştu'
                ]
            ], 500);
        }
    }
}