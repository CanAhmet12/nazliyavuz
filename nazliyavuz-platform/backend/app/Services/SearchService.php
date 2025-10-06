<?php

namespace App\Services;

use App\Models\Teacher;
use App\Models\Category;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;

class SearchService
{
    /**
     * Search teachers with advanced filters
     */
    public function searchTeachers(array $filters = []): array
    {
        try {
            $query = Teacher::with(['user', 'categories'])
                ->whereHas('user', function ($q) use ($filters) {
                    if (!empty($filters['query'])) {
                        $q->where('name', 'like', "%{$filters['query']}%")
                          ->orWhere('email', 'like', "%{$filters['query']}%");
                    }
                });

            // Apply category filter
            if (!empty($filters['category'])) {
                $query->whereHas('categories', function ($q) use ($filters) {
                    $q->where('slug', $filters['category']);
                });
            }

            // Apply price filter
            if (!empty($filters['min_price'])) {
                $query->where('hourly_rate', '>=', $filters['min_price']);
            }
            if (!empty($filters['max_price'])) {
                $query->where('hourly_rate', '<=', $filters['max_price']);
            }

            // Apply rating filter
            if (!empty($filters['rating'])) {
                $query->where('average_rating', '>=', $filters['rating']);
            }

            // Apply location filter
            if (!empty($filters['location'])) {
                $query->where('location', 'like', "%{$filters['location']}%");
            }

            // Apply sorting
            $this->applySorting($query, $filters['sort_by'] ?? 'relevance');

            // Apply pagination
            $page = $filters['page'] ?? 1;
            $perPage = $filters['per_page'] ?? 20;
            
            $teachers = $query->paginate($perPage, ['*'], 'page', $page);

            return [
                'teachers' => $teachers->items(),
                'pagination' => [
                    'current_page' => $teachers->currentPage(),
                    'last_page' => $teachers->lastPage(),
                    'per_page' => $teachers->perPage(),
                    'total' => $teachers->total(),
                ],
                'filters' => $filters,
            ];
        } catch (\Exception $e) {
            Log::error('Teacher search failed', [
                'filters' => $filters,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Get search suggestions
     */
    public function getSearchSuggestions(string $query, int $limit = 10): array
    {
        try {
            if (strlen($query) < 2) {
                return [];
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
            return array_slice($suggestions, 0, $limit);
        } catch (\Exception $e) {
            Log::error('Search suggestions failed', [
                'query' => $query,
                'error' => $e->getMessage(),
            ]);
            return [];
        }
    }

    /**
     * Get popular searches
     */
    public function getPopularSearches(): array
    {
        try {
            return Cache::remember('popular_searches', 3600, function () {
                // Mock popular searches - in production, this would come from analytics
                return [
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
            });
        } catch (\Exception $e) {
            Log::error('Failed to get popular searches', [
                'error' => $e->getMessage(),
            ]);
            return [];
        }
    }

    /**
     * Get search filters
     */
    public function getSearchFilters(): array
    {
        try {
            return Cache::remember('search_filters', 3600, function () {
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

                return [
                    'categories' => $categories,
                    'price_ranges' => $priceRanges,
                    'rating_options' => $ratingOptions,
                    'sort_options' => $sortOptions,
                ];
            });
        } catch (\Exception $e) {
            Log::error('Failed to get search filters', [
                'error' => $e->getMessage(),
            ]);
            return [
                'categories' => [],
                'price_ranges' => [],
                'rating_options' => [],
                'sort_options' => [],
            ];
        }
    }

    /**
     * Apply sorting to query
     */
    private function applySorting($query, string $sortBy): void
    {
        switch ($sortBy) {
            case 'price_low':
                $query->orderBy('hourly_rate', 'asc');
                break;
            case 'price_high':
                $query->orderBy('hourly_rate', 'desc');
                break;
            case 'rating':
                $query->orderBy('average_rating', 'desc');
                break;
            case 'experience':
                $query->orderBy('experience_years', 'desc');
                break;
            case 'relevance':
            default:
                $query->orderBy('average_rating', 'desc')
                     ->orderBy('total_lessons', 'desc');
                break;
        }
    }

    /**
     * Track search query for analytics
     */
    public function trackSearchQuery(string $query, array $filters = []): void
    {
        try {
            // In production, this would store search analytics
            Log::info('Search query tracked', [
                'query' => $query,
                'filters' => $filters,
                'timestamp' => now(),
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to track search query', [
                'query' => $query,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
