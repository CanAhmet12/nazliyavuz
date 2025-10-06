<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;
use App\Models\ContentPage;

class ContentPageController extends Controller
{
    /**
     * Get all content pages
     */
    public function index(): JsonResponse
    {
        try {
            $pages = ContentPage::where('is_active', true)
                ->orderBy('sort_order')
                ->get();
            
            return response()->json([
                'success' => true,
                'pages' => $pages
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting content pages: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'CONTENT_PAGES_ERROR',
                    'message' => 'İçerik sayfaları yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get single content page
     */
    public function show(string $slug): JsonResponse
    {
        try {
            $page = ContentPage::where('slug', $slug)
                ->where('is_active', true)
                ->first();
            
            if (!$page) {
                return response()->json([
                    'error' => [
                        'code' => 'PAGE_NOT_FOUND',
                        'message' => 'Sayfa bulunamadı'
                    ]
                ], 404);
            }
            
            return response()->json([
                'success' => true,
                'page' => $page
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting content page: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'CONTENT_PAGE_ERROR',
                    'message' => 'İçerik sayfası yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}