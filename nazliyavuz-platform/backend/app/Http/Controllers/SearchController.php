<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;
use App\Models\Teacher;
use App\Models\Category;
use App\Models\User;

class SearchController extends Controller
{
    /**
     * Search teachers
     */
    public function searchTeachers(Request $request): JsonResponse
    {
        try {
            $query = $request->get('q', '');
            $category = $request->get('category');
            $minPrice = $request->get('min_price');
            $maxPrice = $request->get('max_price');
            $rating = $request->get('rating');
            $location = $request->get('location');
            $sortBy = $request->get('sort_by', 'relevance');
            $page = $request->get('page', 1);
            $perPage = $request->get('per_page', 20);
            
            $teachersQuery = Teacher::with(['user', 'categories'])
                ->whereHas('user', function ($q) use ($query) {
                    if ($query) {
                        $q->where('name', 'like', "%{$query}%")
                          ->orWhere('email', 'like', "%{$query}%");
                    }
                });
            
            // Apply category filter
            if ($category) {
                $teachersQuery->whereHas('categories', function ($q) use ($category) {
                    $q->where('slug', $category);
                });
            }
            
            // Apply price filter
            if ($minPrice) {
                $teachersQuery->where('hourly_rate', '>=', $minPrice);
            }
            if ($maxPrice) {
                $teachersQuery->where('hourly_rate', '<=', $maxPrice);
            }
            
            // Apply rating filter
            if ($rating) {
                $teachersQuery->where('average_rating', '>=', $rating);
            }
            
            // Apply location filter
            if ($location) {
                $teachersQuery->where('location', 'like', "%{$location}%");
            }
            
            // Apply sorting
            switch ($sortBy) {
                case 'price_low':
                    $teachersQuery->orderBy('hourly_rate', 'asc');
                    break;
                case 'price_high':
                    $teachersQuery->orderBy('hourly_rate', 'desc');
                    break;
                case 'rating':
                    $teachersQuery->orderBy('average_rating', 'desc');
                    break;
                case 'experience':
                    $teachersQuery->orderBy('experience_years', 'desc');
                    break;
                case 'relevance':
                default:
                    $teachersQuery->orderBy('average_rating', 'desc')
                                 ->orderBy('total_lessons', 'desc');
                    break;
            }
            
            $teachers = $teachersQuery->paginate($perPage, ['*'], 'page', $page);
            
            return response()->json([
                'success' => true,
                'teachers' => $teachers->items(),
                'pagination' => [
                    'current_page' => $teachers->currentPage(),
                    'last_page' => $teachers->lastPage(),
                    'per_page' => $teachers->perPage(),
                    'total' => $teachers->total(),
                ],
                'filters' => [
                    'query' => $query,
                    'category' => $category,
                    'min_price' => $minPrice,
                    'max_price' => $maxPrice,
                    'rating' => $rating,
                    'location' => $location,
                    'sort_by' => $sortBy,
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error searching teachers: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'TEACHER_SEARCH_ERROR',
                    'message' => 'Öğretmen arama sırasında bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get search suggestions
     */
    public function getSuggestions(Request $request): JsonResponse
    {
        try {
            $query = $request->get('q', '');
            $limit = $request->get('limit', 10);
            
            if (strlen($query) < 2) {
                return response()->json([
                    'success' => true,
                    'suggestions' => []
                ]);
            }
            
            $suggestions = [];
            
            // Teacher name suggestions
            $teacherNames = User::where('role', 'teacher')
                ->where('name', 'like', "%{$query}%")
                ->limit($limit)
                ->pluck('name')
                ->map(function ($name) {
                    return [
                        'type' => 'teacher',
                        'text' => $name,
                        'icon' => 'person'
                    ];
                });
            
            $suggestions = array_merge($suggestions, $teacherNames->toArray());
            
            // Category suggestions
            $categories = Category::where('name', 'like', "%{$query}%")
                ->where('is_active', true)
                ->limit($limit)
                ->get()
                ->map(function ($category) {
                    return [
                        'type' => 'category',
                        'text' => $category->name,
                        'icon' => 'category',
                        'slug' => $category->slug
                    ];
                });
            
            $suggestions = array_merge($suggestions, $categories->toArray());
            
            // Limit total suggestions
            $suggestions = array_slice($suggestions, 0, $limit);
            
            return response()->json([
                'success' => true,
                'suggestions' => $suggestions
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting search suggestions: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SEARCH_SUGGESTIONS_ERROR',
                    'message' => 'Arama önerileri yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get popular searches
     */
    public function getPopularSearches(): JsonResponse
    {
        try {
            // Mock popular searches - in production, this would come from analytics
            $popularSearches = [
                'Matematik',
                'İngilizce',
                'Fizik',
                'Kimya',
                'Biyoloji',
                'Tarih',
                'Coğrafya',
                'Türkçe',
                'Edebiyat',
                'Felsefe'
            ];
            
            return response()->json([
                'success' => true,
                'popular_searches' => $popularSearches
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting popular searches: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'POPULAR_SEARCHES_ERROR',
                    'message' => 'Popüler aramalar yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get search filters
     */
    public function getFilters(): JsonResponse
    {
        try {
            // Get categories for filter
            $categories = Category::active()
                ->root()
                ->with('children')
                ->orderBy('sort_order')
                ->get();
            
            // Get price ranges
            $priceRanges = [
                ['min' => 0, 'max' => 50, 'label' => '0-50 TL'],
                ['min' => 50, 'max' => 100, 'label' => '50-100 TL'],
                ['min' => 100, 'max' => 200, 'label' => '100-200 TL'],
                ['min' => 200, 'max' => 500, 'label' => '200-500 TL'],
                ['min' => 500, 'max' => null, 'label' => '500+ TL'],
            ];
            
            // Get rating options
            $ratingOptions = [
                ['value' => 5, 'label' => '5 Yıldız'],
                ['value' => 4, 'label' => '4+ Yıldız'],
                ['value' => 3, 'label' => '3+ Yıldız'],
                ['value' => 2, 'label' => '2+ Yıldız'],
                ['value' => 1, 'label' => '1+ Yıldız'],
            ];
            
            // Get sort options
            $sortOptions = [
                ['value' => 'relevance', 'label' => 'En Uygun'],
                ['value' => 'rating', 'label' => 'En Yüksek Puan'],
                ['value' => 'price_low', 'label' => 'En Düşük Fiyat'],
                ['value' => 'price_high', 'label' => 'En Yüksek Fiyat'],
                ['value' => 'experience', 'label' => 'En Deneyimli'],
            ];
            
            return response()->json([
                'success' => true,
                'filters' => [
                    'categories' => $categories,
                    'price_ranges' => $priceRanges,
                    'rating_options' => $ratingOptions,
                    'sort_options' => $sortOptions,
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting search filters: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'SEARCH_FILTERS_ERROR',
                    'message' => 'Arama filtreleri yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}