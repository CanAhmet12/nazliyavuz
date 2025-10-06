<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use App\Models\SharedFile;

class FileSharingController extends Controller
{
    /**
     * Get shared files for authenticated user
     */
    public function getSharedFiles(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $query = SharedFile::query();
            
            // Filter by user role and relationships
            if ($user->role === 'teacher') {
                $query->where('teacher_id', $user->id);
            } else {
                $query->where('student_id', $user->id);
            }
            
            // Apply category filter
            if ($request->has('category') && $request->category) {
                $query->where('category', $request->category);
            }
            
            // Apply search filter
            if ($request->has('search') && $request->search) {
                $query->where('name', 'like', '%' . $request->search . '%');
            }
            
            $files = $query->with(['teacher:id,name', 'student:id,name'])
                ->orderBy('created_at', 'desc')
                ->paginate($request->get('per_page', 20));
            
            return response()->json([
                'success' => true,
                'files' => $files->items(),
                'pagination' => [
                    'current_page' => $files->currentPage(),
                    'last_page' => $files->lastPage(),
                    'per_page' => $files->perPage(),
                    'total' => $files->total(),
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting shared files: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'FILES_FETCH_ERROR',
                    'message' => 'Dosyalar yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Upload shared file
     */
    public function uploadSharedFile(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'file' => 'required|file|max:5120', // 5MB max for local development
            'category' => 'required|string|max:50',
            'description' => 'nullable|string|max:255',
            'shared_with' => 'required|array',
            'shared_with.*' => 'integer|exists:users,id',
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
            $file = $request->file('file');
            
            // Generate unique filename
            $filename = time() . '_' . $file->getClientOriginalName();
            $filePath = $file->storeAs('shared_files', $filename, 'public');
            
            // Create shared file record
            $sharedFile = SharedFile::create([
                'teacher_id' => $user->role === 'teacher' ? $user->id : null,
                'student_id' => $user->role === 'student' ? $user->id : null,
                'name' => $file->getClientOriginalName(),
                'file_path' => $filePath,
                'file_size' => $file->getSize(),
                'mime_type' => $file->getMimeType(),
                'category' => $request->category,
                'description' => $request->description,
                'shared_with' => $request->shared_with,
            ]);
            
            return response()->json([
                'success' => true,
                'message' => 'Dosya başarıyla yüklendi',
                'file' => $sharedFile
            ], 201);
            
        } catch (\Exception $e) {
            Log::error('Error uploading shared file: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'FILE_UPLOAD_ERROR',
                    'message' => 'Dosya yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Download shared file
     */
    public function downloadSharedFile(SharedFile $file): JsonResponse
    {
        try {
            $user = Auth::user();
            
            // Check if user has access to this file
            $hasAccess = false;
            
            if ($user->role === 'teacher' && $file->teacher_id === $user->id) {
                $hasAccess = true;
            } elseif ($user->role === 'student' && $file->student_id === $user->id) {
                $hasAccess = true;
            } elseif (in_array($user->id, $file->shared_with)) {
                $hasAccess = true;
            }
            
            if (!$hasAccess) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu dosyaya erişim yetkiniz yok'
                    ]
                ], 403);
            }
            
            // Check if file exists
            if (!Storage::disk('public')->exists($file->file_path)) {
                return response()->json([
                    'error' => [
                        'code' => 'FILE_NOT_FOUND',
                        'message' => 'Dosya bulunamadı'
                    ]
                ], 404);
            }
            
            // Generate download URL
            $downloadUrl = Storage::disk('public')->url($file->file_path);
            
            return response()->json([
                'success' => true,
                'download_url' => $downloadUrl,
                'file_name' => $file->name,
                'file_size' => $file->file_size,
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error downloading shared file: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'FILE_DOWNLOAD_ERROR',
                    'message' => 'Dosya indirilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Delete shared file
     */
    public function deleteSharedFile(SharedFile $file): JsonResponse
    {
        try {
            $user = Auth::user();
            
            // Check if user owns this file
            $isOwner = false;
            
            if ($user->role === 'teacher' && $file->teacher_id === $user->id) {
                $isOwner = true;
            } elseif ($user->role === 'student' && $file->student_id === $user->id) {
                $isOwner = true;
            }
            
            if (!$isOwner) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu dosyayı silme yetkiniz yok'
                    ]
                ], 403);
            }
            
            // Delete file from storage
            if (Storage::disk('public')->exists($file->file_path)) {
                Storage::disk('public')->delete($file->file_path);
            }
            
            // Delete database record
            $file->delete();
            
            return response()->json([
                'success' => true,
                'message' => 'Dosya başarıyla silindi'
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error deleting shared file: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'FILE_DELETE_ERROR',
                    'message' => 'Dosya silinirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}