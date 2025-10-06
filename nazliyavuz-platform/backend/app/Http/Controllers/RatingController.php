<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use App\Services\MailService;
use App\Models\Teacher;
use App\Models\Reservation;
use App\Models\Rating;
use App\Models\AuditLog;

/**
 * @OA\Tag(
 *     name="Ratings",
 *     description="Değerlendirme ve yorum işlemleri"
 * )
 */
class RatingController extends Controller
{
    protected MailService $mailService;

    public function __construct(MailService $mailService)
    {
        $this->mailService = $mailService;
    }

    /**
     * @OA\Post(
     *     path="/ratings",
     *     tags={"Ratings"},
     *     summary="Yeni değerlendirme oluştur",
     *     description="Tamamlanan rezervasyon için değerlendirme ve yorum oluşturur",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"reservation_id","rating"},
     *             @OA\Property(property="reservation_id", type="integer", example=1),
     *             @OA\Property(property="rating", type="integer", minimum=1, maximum=5, example=5),
     *             @OA\Property(property="review", type="string", example="Çok iyi bir öğretmen, dersi çok iyi anlattı")
     *         )
     *     ),
     *     @OA\Response(
     *         response=201,
     *         description="Değerlendirme başarıyla oluşturuldu",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Değerlendirme başarıyla oluşturuldu"),
     *             @OA\Property(property="rating", type="object")
     *         )
     *     ),
     *     @OA\Response(
     *         response=422,
     *         description="Validation hatası",
     *         @OA\JsonContent(
     *             @OA\Property(property="error", type="object")
     *         )
     *     )
     * )
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reservation_id' => 'required|integer|exists:reservations,id',
            'rating' => 'required|integer|min:1|max:5',
            'review' => 'nullable|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Validation hatası',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        $user = Auth::user();
        
        // Rezervasyonu kontrol et
        $reservation = Reservation::findOrFail($request->reservation_id);
        
        // Sadece öğrenci kendi rezervasyonunu değerlendirebilir
        if ($reservation->student_id !== $user->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu rezervasyonu değerlendirme yetkiniz yok'
                ]
            ], 403);
        }

        // Rezervasyon tamamlanmış olmalı
        if ($reservation->status !== 'completed') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_STATUS',
                    'message' => 'Sadece tamamlanan rezervasyonlar değerlendirilebilir'
                ]
            ], 400);
        }

        // Zaten değerlendirme var mı kontrol et
        if (Rating::where('reservation_id', $request->reservation_id)->exists()) {
            return response()->json([
                'error' => [
                    'code' => 'ALREADY_RATED',
                    'message' => 'Bu rezervasyon zaten değerlendirilmiş'
                ]
            ], 400);
        }

        $rating = Rating::create([
            'student_id' => $user->id,
            'teacher_id' => $reservation->teacher_id,
            'reservation_id' => $request->reservation_id,
            'rating' => $request->rating,
            'review' => $request->review,
        ]);

        // Öğretmenin ortalama rating'ini güncelle
        $this->updateTeacherRating($reservation->teacher_id);

        // E-posta bildirimi gönder
        $teacher = Teacher::where('user_id', $reservation->teacher_id)->first();
        if ($teacher) {
            $this->mailService->sendRatingNotification(
                $teacher->user,
                $user,
                $request->rating,
                $request->review
            );
        }

        // Audit log
        AuditLog::createLog(
            userId: $user->id,
            action: 'create_rating',
            targetType: 'Rating',
            targetId: $rating->id,
            meta: [
                'teacher_id' => $reservation->teacher_id,
                'reservation_id' => $request->reservation_id,
                'rating' => $request->rating,
                'has_review' => !empty($request->review),
            ],
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        return response()->json([
            'message' => 'Değerlendirme başarıyla oluşturuldu',
            'rating' => $rating->load(['student', 'teacher'])
        ], 201);
    }

    /**
     * @OA\Get(
     *     path="/teachers/{teacher}/ratings",
     *     tags={"Ratings"},
     *     summary="Öğretmen değerlendirmeleri",
     *     description="Belirli bir öğretmenin tüm değerlendirmelerini getirir",
     *     @OA\Parameter(
     *         name="teacher",
     *         in="path",
     *         required=true,
     *         description="Öğretmen ID",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Değerlendirmeler başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="data", type="array", @OA\Items(type="object")),
     *             @OA\Property(property="meta", type="object")
     *         )
     *     )
     * )
     */
    public function getTeacherRatings(Teacher $teacher): JsonResponse
    {
        $ratings = Rating::where('teacher_id', $teacher->user_id)
            ->with(['student', 'reservation'])
            ->orderBy('created_at', 'desc')
            ->get();

        // Format ratings to include student name and comment
        $formattedRatings = $ratings->map(function ($rating) {
            return [
                'id' => $rating->id,
                'student_id' => $rating->student_id,
                'teacher_id' => $rating->teacher_id,
                'reservation_id' => $rating->reservation_id,
                'rating' => $rating->rating,
                'comment' => $rating->review, // Map review to comment
                'student_name' => $rating->student->name ?? 'Anonim',
                'created_at' => $rating->created_at->toISOString(),
                'updated_at' => $rating->updated_at->toISOString(),
                'student' => $rating->student ? [
                    'id' => $rating->student->id,
                    'name' => $rating->student->name,
                    'email' => $rating->student->email,
                ] : null,
                'reservation' => $rating->reservation ? [
                    'id' => $rating->reservation->id,
                    'subject' => $rating->reservation->subject,
                ] : null,
            ];
        });

        return response()->json([
            'success' => true,
            'ratings' => $formattedRatings,
            'total' => $formattedRatings->count()
        ]);
    }

    /**
     * @OA\Get(
     *     path="/student/ratings",
     *     tags={"Ratings"},
     *     summary="Öğrenci değerlendirmeleri",
     *     description="Giriş yapmış öğrencinin verdiği değerlendirmeleri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Değerlendirmeler başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="data", type="array", @OA\Items(type="object"))
     *         )
     *     )
     * )
     */
    public function getStudentRatings(): JsonResponse
    {
        $user = Auth::user();
        
        $ratings = Rating::where('student_id', $user->id)
            ->with(['teacher.user', 'reservation'])
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'data' => $ratings
        ]);
    }

    /**
     * @OA\Put(
     *     path="/ratings/{rating}",
     *     tags={"Ratings"},
     *     summary="Değerlendirme güncelle",
     *     description="Mevcut değerlendirmeyi günceller",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="rating",
     *         in="path",
     *         required=true,
     *         description="Değerlendirme ID",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"rating"},
     *             @OA\Property(property="rating", type="integer", minimum=1, maximum=5, example=4),
     *             @OA\Property(property="review", type="string", example="Güncellenmiş yorum")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Değerlendirme başarıyla güncellendi",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Değerlendirme başarıyla güncellendi"),
     *             @OA\Property(property="rating", type="object")
     *         )
     *     )
     * )
     */
    public function update(Request $request, Rating $rating): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'rating' => 'required|integer|min:1|max:5',
            'review' => 'nullable|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Validation hatası',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        $user = Auth::user();
        
        // Sadece değerlendirmeyi veren öğrenci güncelleyebilir
        if ($rating->student_id !== $user->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu değerlendirmeyi güncelleme yetkiniz yok'
                ]
            ], 403);
        }

        $rating->update([
            'rating' => $request->rating,
            'review' => $request->review,
        ]);

        // Öğretmenin ortalama rating'ini güncelle
        $this->updateTeacherRating($rating->teacher_id);

        // Audit log
        AuditLog::createLog(
            userId: $user->id,
            action: 'update_rating',
            targetType: 'Rating',
            targetId: $rating->id,
            meta: [
                'teacher_id' => $rating->teacher_id,
                'old_rating' => $rating->getOriginal('rating'),
                'new_rating' => $request->rating,
                'has_review' => !empty($request->review),
            ],
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        return response()->json([
            'message' => 'Değerlendirme başarıyla güncellendi',
            'rating' => $rating->load(['student', 'teacher'])
        ]);
    }

    /**
     * @OA\Delete(
     *     path="/ratings/{rating}",
     *     tags={"Ratings"},
     *     summary="Değerlendirme sil",
     *     description="Mevcut değerlendirmeyi siler",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="rating",
     *         in="path",
     *         required=true,
     *         description="Değerlendirme ID",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Değerlendirme başarıyla silindi",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Değerlendirme başarıyla silindi")
     *         )
     *     )
     * )
     */
    public function destroy(Rating $rating): JsonResponse
    {
        $user = Auth::user();
        
        // Sadece değerlendirmeyi veren öğrenci silebilir
        if ($rating->student_id !== $user->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu değerlendirmeyi silme yetkiniz yok'
                ]
            ], 403);
        }

        $teacherId = $rating->teacher_id;
        $rating->delete();

        // Öğretmenin ortalama rating'ini güncelle
        $this->updateTeacherRating($teacherId);

        // Audit log
        AuditLog::createLog(
            userId: $user->id,
            action: 'delete_rating',
            targetType: 'Rating',
            targetId: $rating->id,
            meta: [
                'teacher_id' => $teacherId,
                'rating' => $rating->rating,
                'had_review' => !empty($rating->review),
            ],
            ipAddress: request()->ip(),
            userAgent: request()->userAgent(),
        );

        return response()->json([
            'message' => 'Değerlendirme başarıyla silindi'
        ]);
    }

    /**
     * Öğretmenin ortalama rating'ini güncelle
     */
    private function updateTeacherRating(int $teacherId): void
    {
        $teacher = Teacher::where('user_id', $teacherId)->first();
        
        if ($teacher) {
            $ratings = Rating::where('teacher_id', $teacherId);
            $avgRating = $ratings->avg('rating');
            $ratingCount = $ratings->count();
            
            $teacher->update([
                'rating_avg' => round($avgRating, 2),
                'rating_count' => $ratingCount,
            ]);
        }
    }
}
