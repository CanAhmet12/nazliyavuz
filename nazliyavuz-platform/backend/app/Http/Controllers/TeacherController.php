<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use App\Models\Teacher;
use App\Models\User;
use App\Models\Category;
use App\Models\Reservation;
use App\Services\CacheService;

class TeacherController extends Controller
{
    protected CacheService $cacheService;

    public function __construct(CacheService $cacheService)
    {
        $this->cacheService = $cacheService;
    }

    /**
     * Get all teachers with filters
     */
    public function index(Request $request): JsonResponse
    {
        Log::info('🚀 TeacherController::index STARTED', [
            'request_params' => $request->all(),
            'timestamp' => now(),
            'user_agent' => $request->userAgent()
        ]);

        try {
            // Create cache key based on request parameters
            $cacheKey = 'teachers:' . md5(serialize($request->all()));
            Log::info('📝 Cache key created', ['cache_key' => $cacheKey]);
            
            // Try to get from cache first
            $cachedTeachers = cache()->get($cacheKey);
            
            if ($cachedTeachers) {
                Log::info('📦 Cache HIT for teachers', ['cache_key' => $cacheKey]);
                return response()->json([
                    'success' => true,
                    'teachers' => $cachedTeachers,
                    'cached' => true
                ]);
            }
            
            Log::info('📦 Cache MISS - proceeding with database query');

            Log::info('🗄️ Starting database query...');
            $query = Teacher::with(['user', 'categories'])
                ->whereHas('user', function ($q) {
                    $q->where('role', 'teacher');
                })
                ->where('is_approved', 1);
            Log::info('✅ Base query created with relationships');
            
            // Debug: Count total teachers before filters
            $totalTeachersBeforeFilters = $query->count();
            Log::info('📊 Total teachers before filters: ' . $totalTeachersBeforeFilters);

            // Kategori filtresi
            if ($request->has('category') && $request->category) {
                Log::info('🏷️ Applying category filter', ['category' => $request->category]);
                try {
                    // Seçilen kategoriyi bul
                    $selectedCategory = \App\Models\Category::where('slug', $request->category)
                        ->orWhere('name', $request->category)
                        ->first();
                    
                    if ($selectedCategory) {
                        // Eğer ana kategori seçildiyse, tüm alt kategorilerini de dahil et
                        $categoryIds = [$selectedCategory->id];
                        
                        // Alt kategorileri bul
                        $childCategories = \App\Models\Category::where('parent_id', $selectedCategory->id)->get();
                        foreach ($childCategories as $child) {
                            $categoryIds[] = $child->id;
                        }
                        
                        Log::info('📁 Category IDs to filter', ['category_ids' => $categoryIds]);
                        
                        // Öğretmenleri bu kategorilere göre filtrele
                        $query->whereHas('categories', function ($q) use ($categoryIds) {
                            $q->whereIn('categories.id', $categoryIds);
                        });
                        
                        Log::info('✅ Category filter applied successfully');
                    } else {
                        Log::warning('⚠️ Category not found', ['category' => $request->category]);
                    }
                    
                    // Debug: Count teachers after category filter
                    $teachersAfterCategoryFilter = $query->count();
                    Log::info('📊 Teachers after category filter: ' . $teachersAfterCategoryFilter);
                } catch (\Exception $e) {
                    Log::error('💥 ERROR in category filter', [
                        'error' => $e->getMessage(),
                        'category' => $request->category
                    ]);
                    throw $e;
                }
            }

            // Fiyat filtresi
            if ($request->has('min_price')) {
                Log::info('💰 Applying min price filter', ['min_price' => $request->min_price]);
                $query->where('price_hour', '>=', $request->min_price);
            }

            if ($request->has('max_price')) {
                Log::info('💰 Applying max price filter', ['max_price' => $request->max_price]);
                $query->where('price_hour', '<=', $request->max_price);
            }

            // Rating filtresi
            if ($request->has('min_rating')) {
                Log::info('⭐ Applying rating filter', ['min_rating' => $request->min_rating]);
                $query->where('rating_avg', '>=', $request->min_rating);
            }

            // Online availability filtresi
            if ($request->has('online_only') && $request->online_only) {
                Log::info('🌐 Applying online only filter');
                $query->where('online_available', true);
            }

            // Arama
            if ($request->has('search') && $request->search) {
                Log::info('🔍 Applying search filter', ['search' => $request->search]);
                $searchTerm = $request->search;
                $query->where(function ($q) use ($searchTerm) {
                    $q->whereHas('user', function ($userQuery) use ($searchTerm) {
                        $userQuery->where('name', 'like', "%{$searchTerm}%");
                    })
                    ->orWhere('bio', 'like', "%{$searchTerm}%")
                    ->orWhereHas('categories', function ($catQuery) use ($searchTerm) {
                        $catQuery->where('name', 'like', "%{$searchTerm}%");
                    });
                });
            }

            // Sıralama
            $sortBy = $request->get('sort_by', 'rating');
            Log::info('📊 Applying sorting', ['sort_by' => $sortBy]);
            
            switch ($sortBy) {
                case 'price_low':
                    $query->orderBy('price_hour', 'asc');
                    break;
                case 'price_high':
                    $query->orderBy('price_hour', 'desc');
                    break;
                case 'newest':
                    $query->orderBy('created_at', 'desc');
                    break;
                case 'rating':
                default:
                    $query->orderBy('rating_avg', 'desc');
                    break;
            }

            // Sayfalama
            Log::info('📄 Starting pagination', ['per_page' => $request->get('per_page', 20)]);
            $perPage = $request->get('per_page', 20);
            
            try {
                Log::info('🗄️ Executing database query with pagination...');
                $teachers = $query->paginate($perPage);
                Log::info('✅ Database query executed successfully', [
                    'found_teachers' => $teachers->count(),
                    'total_teachers' => $teachers->total(),
                    'current_page' => $teachers->currentPage()
                ]);
            } catch (\Exception $e) {
                Log::error('💥 CRITICAL ERROR during database query execution', [
                    'error_message' => $e->getMessage(),
                    'error_file' => $e->getFile(),
                    'error_line' => $e->getLine(),
                    'per_page' => $perPage,
                    'stack_trace' => $e->getTraceAsString()
                ]);
                throw $e;
            }

            Log::info('📦 Preparing response data...');
            try {
                $result = [
                    'data' => $teachers->items(),
                    'meta' => [
                        'current_page' => $teachers->currentPage(),
                        'last_page' => $teachers->lastPage(),
                        'per_page' => $teachers->perPage(),
                        'total' => $teachers->total(),
                    ]
                ];
                Log::info('✅ Response data prepared successfully', [
                    'data_count' => count($result['data']),
                    'meta' => $result['meta']
                ]);

                // Cache the results
                cache()->put($cacheKey, $result, 1800); // 30 minutes
                Log::info('💾 Results cached successfully', ['cache_key' => $cacheKey]);

                Log::info('🎉 TeacherController::index COMPLETED SUCCESSFULLY');
                return response()->json($result);
                
            } catch (\Exception $e) {
                Log::error('💥 ERROR during response preparation', [
                    'error_message' => $e->getMessage(),
                    'error_file' => $e->getFile(),
                    'error_line' => $e->getLine()
                ]);
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error('💥 CRITICAL ERROR in TeacherController::index', [
                'error_message' => $e->getMessage(),
                'error_file' => $e->getFile(),
                'error_line' => $e->getLine(),
                'stack_trace' => $e->getTraceAsString()
            ]);
            return response()->json(['error' => 'Internal server error', 'details' => $e->getMessage()], 500);
        }
    }

    /**
     * Get single teacher
     */
    public function show(string $id): JsonResponse
    {
        try {
            $teacher = Teacher::with(['user', 'categories', 'reviews.user', 'lessons'])
                ->whereHas('user', function ($q) {
                    $q->where('role', 'teacher');
                })
                ->where('is_approved', 1)
                ->findOrFail($id);

            return response()->json([
                'success' => true,
                'teacher' => $teacher
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting teacher: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TEACHER_NOT_FOUND',
                    'message' => 'Öğretmen bulunamadı'
                ]
            ], 404);
        }
    }

    /**
     * Get featured teachers
     */
    public function featured(): JsonResponse
    {
        try {
            $teachers = Teacher::with(['user', 'categories'])
                ->whereHas('user', function ($q) {
                    $q->where('role', 'teacher');
                })
                ->where('is_approved', 1)
                ->where('rating_avg', '>=', 4.0)
                ->orderBy('rating_avg', 'desc')
                ->limit(10)
                ->get();

            return response()->json([
                'success' => true,
                'featured_teachers' => $teachers
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting featured teachers: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'FEATURED_TEACHERS_ERROR',
                    'message' => 'Öne çıkan öğretmenler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get teacher's students
     */
    public function getStudents(): JsonResponse
    {
        try {
            $user = Auth::user();

            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler bu endpoint\'i kullanabilir'
                    ]
                ], 403);
            }

            // Get students who have reservations with this teacher
            $students = User::where('role', 'student')
                ->whereHas('studentReservations', function ($q) use ($user) {
                    $q->where('teacher_id', $user->id)
                      ->where('status', 'accepted');
                })
                ->select('id', 'name', 'email', 'profile_photo_url')
                ->get();

            return response()->json([
                'success' => true,
                'students' => $students
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting teacher students: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TEACHER_STUDENTS_ERROR',
                    'message' => 'Öğrenciler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get teacher's lessons
     */
    public function getLessons(): JsonResponse
    {
        try {
            $user = Auth::user();

            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler bu endpoint\'i kullanabilir'
                    ]
                ], 403);
            }

            $lessons = \App\Models\Lesson::where('teacher_id', $user->id)
                ->with(['student', 'reservation'])
                ->orderBy('scheduled_at', 'desc')
                ->get();

            return response()->json([
                'success' => true,
                'lessons' => $lessons
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting teacher lessons: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TEACHER_LESSONS_ERROR',
                    'message' => 'Dersler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get teacher statistics
     */
    public function statistics(): JsonResponse
    {
        try {
            $user = Auth::user();

            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler bu endpoint\'i kullanabilir'
                    ]
                ], 403);
            }

            $teacher = Teacher::where('user_id', $user->id)->first();
            
            if (!$teacher) {
                return response()->json([
                    'error' => [
                        'code' => 'TEACHER_NOT_FOUND',
                        'message' => 'Öğretmen profili bulunamadı'
                    ]
                ], 404);
            }

            $totalLessons = \App\Models\Lesson::where('teacher_id', $user->id)->count();
            $completedLessons = \App\Models\Lesson::where('teacher_id', $user->id)
                ->where('status', 'completed')->count();
            $totalStudents = User::where('role', 'student')
                ->whereHas('studentReservations', function ($q) use ($user) {
                    $q->where('teacher_id', $user->id)
                      ->where('status', 'accepted');
                })->count();
            $totalReservations = Reservation::where('teacher_id', $user->id)->count();
            $pendingReservations = Reservation::where('teacher_id', $user->id)
                ->where('status', 'pending')->count();

            $statistics = [
                'total_lessons' => $totalLessons,
                'completed_lessons' => $completedLessons,
                'total_students' => $totalStudents,
                'total_reservations' => $totalReservations,
                'pending_reservations' => $pendingReservations,
                'rating_avg' => $teacher->rating_avg,
                'rating_count' => $teacher->rating_count,
                'completion_rate' => $totalLessons > 0 ? round(($completedLessons / $totalLessons) * 100, 2) : 0,
            ];

            return response()->json([
                'success' => true,
                'statistics' => $statistics
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting teacher statistics: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TEACHER_STATISTICS_ERROR',
                    'message' => 'İstatistikler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Create teacher profile
     */
    public function store(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler profil oluşturabilir'
                    ]
                ], 403);
            }

            // Check if teacher profile already exists
            $existingTeacher = Teacher::where('user_id', $user->id)->first();
            if ($existingTeacher) {
                return response()->json([
                    'error' => [
                        'code' => 'PROFILE_EXISTS',
                        'message' => 'Öğretmen profili zaten mevcut'
                    ]
                ], 400);
            }

            $validator = Validator::make($request->all(), [
                'bio' => 'required|string|min:50|max:1000',
                'price_hour' => 'required|numeric|min:50|max:1000',
                'education' => 'nullable|array',
                'education.*' => 'string|max:255',
                'certifications' => 'nullable|array',
                'certifications.*' => 'string|max:255',
                'languages' => 'nullable|array',
                'languages.*' => 'string|max:50',
                'online_available' => 'boolean',
                'experience_years' => 'nullable|integer|min:0|max:50',
                'main_categories' => 'required|array|min:1',
                'main_categories.*' => 'integer|exists:categories,id',
                'sub_categories' => 'required|array|min:1',
                'sub_categories.*' => 'integer|exists:categories,id',
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

            // Create teacher profile
            $teacherData = [
                'user_id' => $user->id,
                'bio' => $request->bio,
                'education' => $request->education ?? [],
                'certifications' => $request->certifications ?? [],
                'price_hour' => $request->price_hour,
                'languages' => $request->input('languages', []),
                'is_approved' => false, // Admin onayı gerekli
            ];
            
            if ($request->has('online_available')) {
                $teacherData['online_available'] = $request->input('online_available');
            }
            
            if ($request->has('experience_years')) {
                $teacherData['experience_years'] = $request->input('experience_years');
            }
            
            $teacher = Teacher::create($teacherData);

            // Attach main and sub categories
            $allCategories = array_merge($request->main_categories, $request->sub_categories);
            $teacher->categories()->sync($allCategories);

            // Update user's teacher_status to pending
            $user->update(['teacher_status' => 'pending']);

            Log::info('Teacher profile created', [
                'user_id' => $user->id,
                'teacher_id' => $teacher->user_id
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Öğretmen profili başarıyla oluşturuldu. Admin onayı bekleniyor.',
                'teacher' => $teacher->load(['user', 'categories'])
            ], 201);

        } catch (\Exception $e) {
            Log::error('Error creating teacher profile: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TEACHER_CREATE_ERROR',
                    'message' => 'Profil oluşturulurken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update teacher profile
     */
    public function update(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler profil güncelleyebilir'
                    ]
                ], 403);
            }

            $teacher = Teacher::where('user_id', $user->id)->first();
            if (!$teacher) {
                return response()->json([
                    'error' => [
                        'code' => 'TEACHER_NOT_FOUND',
                        'message' => 'Öğretmen profili bulunamadı'
                    ]
                ], 404);
            }

            $validator = Validator::make($request->all(), [
                'bio' => 'sometimes|string|min:50|max:1000',
                'specialization' => 'sometimes|string|max:255',
                'price_hour' => 'sometimes|numeric|min:50|max:1000',
                'education' => 'sometimes|array',
                'education.*' => 'string|max:255',
                'certifications' => 'sometimes|array',
                'certifications.*' => 'string|max:255',
                'languages' => 'sometimes|array',
                'languages.*' => 'string|max:50',
                'online_available' => 'sometimes|boolean',
                'categories' => 'sometimes|array|min:1',
                'categories.*' => 'integer|exists:categories,id',
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

            // Update teacher profile
            $updateData = $request->only([
                'bio', 'education', 'certifications', 'price_hour', 
                'languages', 'online_available'
            ]);

            $teacher->update($updateData);

            // Update categories if provided
            if ($request->has('categories')) {
                $teacher->categories()->sync($request->categories);
            }

            Log::info('Teacher profile updated', [
                'user_id' => $user->id,
                'teacher_id' => $teacher->user_id
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Öğretmen profili başarıyla güncellendi',
                'teacher' => $teacher->load(['user', 'categories'])
            ]);

        } catch (\Exception $e) {
            Log::error('Error updating teacher profile: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TEACHER_UPDATE_ERROR',
                    'message' => 'Profil güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get teacher's lessons
     */
    public function getTeacherLessons(Request $request, int $teacherId): JsonResponse
    {
        try {
            $query = Reservation::where('teacher_id', $teacherId)
                ->with(['student:id,name,email,profile_photo_url', 'category:id,name,slug'])
                ->where('status', 'completed');

            // Apply filters
            if ($request->has('date_from')) {
                $query->where('proposed_datetime', '>=', $request->date_from);
            }
            
            if ($request->has('date_to')) {
                $query->where('proposed_datetime', '<=', $request->date_to);
            }

            $lessons = $query->orderBy('proposed_datetime', 'desc')->get();

            $formattedLessons = $lessons->map(function ($lesson) {
                return [
                    'id' => $lesson->id,
                    'student_id' => $lesson->student_id,
                    'teacher_id' => $lesson->teacher_id,
                    'category_id' => $lesson->category_id,
                    'subject' => $lesson->subject ?? ($lesson->category->name ?? 'Ders'),
                    'proposed_datetime' => $lesson->proposed_datetime->toISOString(),
                    'status' => $lesson->status,
                    'notes' => $lesson->notes,
                    'teacher_notes' => $lesson->teacher_notes,
                    'price' => $lesson->price ?? 0,
                    'duration_minutes' => $lesson->duration_minutes,
                    'created_at' => $lesson->created_at->toISOString(),
                    'updated_at' => $lesson->updated_at->toISOString(),
                    'student' => [
                        'id' => $lesson->student->id,
                        'name' => $lesson->student->name,
                        'email' => $lesson->student->email,
                        'profile_photo_url' => $lesson->student->profile_photo_url,
                    ],
                    'category' => [
                        'id' => $lesson->category->id,
                        'name' => $lesson->category->name,
                        'slug' => $lesson->category->slug,
                    ],
                ];
            });

            return response()->json([
                'success' => true,
                'lessons' => $formattedLessons,
                'total' => $formattedLessons->count()
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting teacher lessons: ' . $e->getMessage());
            return response()->json([
                'error' => [
                    'code' => 'TEACHER_LESSONS_ERROR',
                    'message' => 'Öğretmen dersleri yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}