<?php

namespace App\Http\Controllers;

use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;

class CategoryController extends Controller
{
    /**
     * Get all categories
     */
    public function index(): JsonResponse
    {
        $categories = Category::active()
            ->with('children')
            ->root()
            ->orderBy('sort_order')
            ->get();

        return response()->json($categories);
    }

    /**
     * Get single category with fallback for old slugs
     */
    public function show(Category $category): JsonResponse
    {
        $category->load(['children', 'teachers.user']);
        
        return response()->json($category);
    }

    /**
     * Handle old category slugs with fallback
     */
    public function showWithFallback(string $slug): JsonResponse
    {
        // Eski slug'ların yeni slug'lara mapping'i
        $oldToNewSlugMap = [
            'san' => 'kulak-egitimi',
            'pilates' => 'meditasyon',
            'web-tasarim' => 'web-tasarimi',
            'bilgisayar' => 'yazilim',
            'akademik' => 'okul-dersleri',
            'teknoloji' => 'yazilim',
        ];

        // Eğer eski slug ise yeni slug'a yönlendir
        if (isset($oldToNewSlugMap[$slug])) {
            $newSlug = $oldToNewSlugMap[$slug];
            $category = Category::where('slug', $newSlug)->first();
            
            if ($category) {
                $category->load(['children', 'teachers.user']);
                return response()->json([
                    'category' => $category,
                    'redirected_from' => $slug,
                    'message' => 'Kategori yeni konumuna taşındı'
                ]);
            }
        }

        // Normal kategori arama
        $category = Category::where('slug', $slug)->first();
        
        if (!$category) {
            return response()->json([
                'error' => [
                    'code' => 'NOT_FOUND',
                    'message' => 'Kategori bulunamadı'
                ]
            ], 404);
        }

        $category->load(['children', 'teachers.user']);
        return response()->json($category);
    }

    /**
     * Get student's reservations
     */
    public function studentReservations(Request $request): JsonResponse
    {
        $user = auth()->user();
        
        if ($user->role !== 'student') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Sadece öğrenciler rezervasyon görüntüleyebilir'
                ]
            ], 403);
        }

        $query = $user->studentReservations()->with(['teacher.user', 'category']);

        // Durum filtresi
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Tarih filtresi
        if ($request->has('date_from')) {
            $query->where('proposed_datetime', '>=', $request->date_from);
        }
        if ($request->has('date_to')) {
            $query->where('proposed_datetime', '<=', $request->date_to);
        }

        $reservations = $query->orderBy('proposed_datetime', 'desc')->paginate(20);

        return response()->json([
            'data' => $reservations->items(),
            'meta' => [
                'current_page' => $reservations->currentPage(),
                'last_page' => $reservations->lastPage(),
                'per_page' => $reservations->perPage(),
                'total' => $reservations->total(),
            ]
        ]);
    }

    /**
     * Admin: Get all categories for management
     */
    public function adminIndex(): JsonResponse
    {
        $categories = Category::with('parent')
            ->orderBy('sort_order')
            ->get();

        return response()->json($categories);
    }

    /**
     * Admin: Create category
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'slug' => 'required|string|max:255|unique:categories',
            'description' => 'sometimes|string|max:1000',
            'icon' => 'sometimes|string|max:100',
            'parent_id' => 'sometimes|exists:categories,id',
            'is_active' => 'sometimes|boolean',
            'sort_order' => 'sometimes|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $category = Category::create($request->all());

        return response()->json([
            'message' => 'Kategori başarıyla oluşturuldu',
            'category' => $category
        ], 201);
    }

    /**
     * Admin: Update category
     */
    public function update(Request $request, Category $category): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255',
            'slug' => 'sometimes|string|max:255|unique:categories,slug,' . $category->id,
            'description' => 'sometimes|string|max:1000',
            'icon' => 'sometimes|string|max:100',
            'parent_id' => 'sometimes|exists:categories,id',
            'is_active' => 'sometimes|boolean',
            'sort_order' => 'sometimes|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $category->update($request->all());

        return response()->json([
            'message' => 'Kategori başarıyla güncellendi',
            'category' => $category
        ]);
    }

    /**
     * Admin: Delete category
     */
    public function destroy(Category $category): JsonResponse
    {
        // Alt kategorileri kontrol et
        if ($category->children()->count() > 0) {
            return response()->json([
                'error' => [
                    'code' => 'CONFLICT',
                    'message' => 'Bu kategorinin alt kategorileri var. Önce onları silin.'
                ]
            ], 409);
        }

        // Bu kategoride öğretmen var mı kontrol et
        if ($category->teachers()->count() > 0) {
            return response()->json([
                'error' => [
                    'code' => 'CONFLICT',
                    'message' => 'Bu kategoride öğretmenler var. Önce öğretmenleri başka kategorilere taşıyın.'
                ]
            ], 409);
        }

        $category->delete();

        return response()->json([
            'message' => 'Kategori başarıyla silindi'
        ]);
    }
}