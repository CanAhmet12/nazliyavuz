<?php

namespace App\Http\Controllers;

use App\Models\Experiment;
use App\Models\ExperimentAssignment;
use App\Models\ExperimentVariant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

class ExperimentController extends Controller
{
    public function index(): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $experiments = Experiment::with(['variants'])
            ->orderByDesc('created_at')
            ->get();

        $experimentStats = ExperimentAssignment::select(
            'experiment_id',
            'variant_id',
            DB::raw('COUNT(*) as assignments'),
            DB::raw('SUM(CASE WHEN converted_at IS NOT NULL THEN 1 ELSE 0 END) as conversions'),
            DB::raw('SUM(COALESCE(conversion_value, 0)) as conversion_value')
        )
            ->groupBy('experiment_id', 'variant_id')
            ->get()
            ->groupBy('experiment_id');

        $response = $experiments->map(function (Experiment $experiment) use ($experimentStats) {
            $variantStats = $experimentStats->get($experiment->id, collect())->keyBy('variant_id');

            $variants = $experiment->variants->map(function (ExperimentVariant $variant) use ($variantStats) {
                $stats = $variantStats->get($variant->id);
                $assignments = (int) ($stats->assignments ?? 0);
                $conversions = (int) ($stats->conversions ?? 0);
                $conversionValue = (float) ($stats->conversion_value ?? 0.0);

                return [
                    'id' => $variant->id,
                    'name' => $variant->name,
                    'key' => $variant->key,
                    'is_control' => $variant->is_control,
                    'traffic_allocation' => $variant->traffic_allocation,
                    'assignments' => $assignments,
                    'conversions' => $conversions,
                    'conversion_rate' => $assignments > 0 ? round(($conversions / $assignments) * 100, 2) : 0.0,
                    'conversion_value' => round($conversionValue, 2),
                ];
            });

            $totalAssignments = $variants->sum('assignments');
            $totalConversions = $variants->sum('conversions');
            $totalValue = $variants->sum('conversion_value');

            return [
                'id' => $experiment->id,
                'name' => $experiment->name,
                'key' => $experiment->key,
                'status' => $experiment->status,
                'type' => $experiment->type,
                'traffic_allocation' => $experiment->traffic_allocation,
                'starts_at' => $experiment->starts_at?->toIso8601String(),
                'ends_at' => $experiment->ends_at?->toIso8601String(),
                'hypothesis' => $experiment->hypothesis,
                'success_metric' => $experiment->success_metric,
                'meta' => $experiment->meta,
                'variants' => $variants,
                'metrics' => [
                    'assignments' => $totalAssignments,
                    'conversions' => $totalConversions,
                    'conversion_rate' => $totalAssignments > 0 ? round(($totalConversions / $totalAssignments) * 100, 2) : 0.0,
                    'conversion_value' => round($totalValue, 2),
                ],
            ];
        });

        return response()->json([
            'success' => true,
            'experiments' => $response,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'key' => 'required|string|max:255|unique:experiments,key',
            'type' => 'nullable|string|max:50',
            'status' => 'nullable|string|in:draft,running,paused,completed',
            'traffic_allocation' => 'nullable|integer|min:1|max:100',
            'hypothesis' => 'nullable|string',
            'success_metric' => 'nullable|string',
            'target_filters' => 'nullable|array',
            'starts_at' => 'nullable|date',
            'ends_at' => 'nullable|date|after_or_equal:starts_at',
            'variants' => 'required|array|min:1',
            'variants.*.name' => 'required|string|max:255',
            'variants.*.key' => 'required|string|max:255',
            'variants.*.is_control' => 'nullable|boolean',
            'variants.*.traffic_allocation' => 'nullable|integer|min:0|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();

        $experiment = Experiment::create([
            'name' => $data['name'],
            'key' => $data['key'],
            'type' => $data['type'] ?? 'feature',
            'status' => $data['status'] ?? 'draft',
            'traffic_allocation' => $data['traffic_allocation'] ?? 100,
            'hypothesis' => $data['hypothesis'] ?? null,
            'success_metric' => $data['success_metric'] ?? null,
            'target_filters' => $data['target_filters'] ?? null,
            'starts_at' => $data['starts_at'] ?? null,
            'ends_at' => $data['ends_at'] ?? null,
            'created_by' => $admin->id,
            'updated_by' => $admin->id,
        ]);

        foreach ($data['variants'] as $index => $variantData) {
            $experiment->variants()->create([
                'name' => $variantData['name'],
                'key' => $variantData['key'],
                'is_control' => $variantData['is_control'] ?? $index === 0,
                'traffic_allocation' => $variantData['traffic_allocation'] ?? 0,
            ]);
        }

        return response()->json([
            'success' => true,
            'experiment' => $experiment->fresh('variants'),
        ]);
    }

    public function update(Request $request, Experiment $experiment): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:255',
            'type' => 'sometimes|nullable|string|max:50',
            'status' => 'sometimes|nullable|string|in:draft,running,paused,completed',
            'traffic_allocation' => 'sometimes|nullable|integer|min:1|max:100',
            'hypothesis' => 'sometimes|nullable|string',
            'success_metric' => 'sometimes|nullable|string',
            'target_filters' => 'sometimes|nullable|array',
            'starts_at' => 'sometimes|nullable|date',
            'ends_at' => 'sometimes|nullable|date|after_or_equal:starts_at',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();
        $data['updated_by'] = $admin->id;

        $experiment->update($data);

        return response()->json([
            'success' => true,
            'experiment' => $experiment->fresh('variants'),
        ]);
    }

    public function updateStatus(Request $request, Experiment $experiment): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'status' => 'required|string|in:draft,running,paused,completed',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $experiment->update([
            'status' => $validator->validated()['status'],
            'updated_by' => $admin->id,
        ]);

        return response()->json([
            'success' => true,
            'experiment' => $experiment->fresh('variants'),
        ]);
    }

    public function addVariant(Request $request, Experiment $experiment): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'key' => 'required|string|max:255|unique:experiment_variants,key,NULL,id,experiment_id,' . $experiment->id,
            'is_control' => 'nullable|boolean',
            'traffic_allocation' => 'nullable|integer|min:0|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $variant = $experiment->variants()->create([
            'name' => $validator->validated()['name'],
            'key' => $validator->validated()['key'],
            'is_control' => $validator->validated()['is_control'] ?? false,
            'traffic_allocation' => $validator->validated()['traffic_allocation'] ?? 0,
        ]);

        return response()->json([
            'success' => true,
            'variant' => $variant,
        ]);
    }

    public function updateVariant(Request $request, Experiment $experiment, ExperimentVariant $variant): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        if ($variant->experiment_id !== $experiment->id) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_VARIANT',
                    'message' => 'Variant belirtilen deney ile eşleşmiyor.',
                ],
            ], 409);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:255',
            'key' => 'sometimes|required|string|max:255|unique:experiment_variants,key,' . $variant->id . ',id,experiment_id,' . $experiment->id,
            'is_control' => 'sometimes|boolean',
            'traffic_allocation' => 'sometimes|integer|min:0|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $variant->update($validator->validated());

        return response()->json([
            'success' => true,
            'variant' => $variant,
        ]);
    }

    public function deleteVariant(Experiment $experiment, ExperimentVariant $variant): JsonResponse
    {
        $admin = Auth::user();

        if (!$admin || $admin->role !== 'admin') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlemi gerçekleştirme yetkiniz yok',
                ],
            ], 403);
        }

        if ($variant->experiment_id !== $experiment->id) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_VARIANT',
                    'message' => 'Variant belirtilen deney ile eşleşmiyor.',
                ],
            ], 409);
        }

        if ($variant->assignments()->exists()) {
            return response()->json([
                'error' => [
                    'code' => 'VARIANT_IN_USE',
                    'message' => 'Daha önce katılımcı atanmış bir varyant silinemez.',
                ],
            ], 409);
        }

        $variant->delete();

        return response()->json([
            'success' => true,
        ]);
    }

    public function assign(Request $request, Experiment $experiment): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'nullable|integer|exists:users,id',
            'session_id' => 'nullable|string|max:255',
            'context' => 'nullable|string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();
        $userId = $data['user_id'] ?? null;
        $sessionId = $data['session_id'] ?? null;

        if (!$userId && !$sessionId) {
            return response()->json([
                'error' => [
                    'code' => 'MISSING_IDENTIFIERS',
                    'message' => 'Kullanıcı veya oturum bilgisi belirtmelisiniz.',
                ],
            ], 422);
        }

        $existingAssignment = ExperimentAssignment::query()
            ->where('experiment_id', $experiment->id)
            ->when($userId, fn ($query) => $query->where('user_id', $userId))
            ->when(!$userId && $sessionId, fn ($query) => $query->where('session_id', $sessionId))
            ->first();

        if ($existingAssignment) {
            $variant = $existingAssignment->variant;

            return response()->json([
                'success' => true,
                'assignment' => [
                    'variant' => [
                        'id' => $variant->id,
                        'key' => $variant->key,
                        'name' => $variant->name,
                    ],
                    'assignment_id' => $existingAssignment->id,
                    'converted' => (bool) $existingAssignment->converted_at,
                ],
            ]);
        }

        $variants = $experiment->variants;

        if ($variants->isEmpty()) {
            return response()->json([
                'error' => [
                    'code' => 'NO_VARIANTS',
                    'message' => 'Deney için tanımlanmış varyant bulunmuyor.',
                ],
            ], 409);
        }

        $chosenVariant = $this->chooseVariant($variants);

        $assignment = ExperimentAssignment::create([
            'experiment_id' => $experiment->id,
            'variant_id' => $chosenVariant->id,
            'user_id' => $userId,
            'session_id' => $sessionId,
            'context' => $data['context'] ?? null,
            'assigned_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'assignment' => [
                'variant' => [
                    'id' => $chosenVariant->id,
                    'key' => $chosenVariant->key,
                    'name' => $chosenVariant->name,
                ],
                'assignment_id' => $assignment->id,
                'converted' => false,
            ],
        ]);
    }

    public function recordConversion(Request $request, Experiment $experiment, ExperimentVariant $variant): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'nullable|integer|exists:users,id',
            'session_id' => 'nullable|string|max:255',
            'conversion_value' => 'nullable|numeric|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $data = $validator->validated();

        $assignmentQuery = ExperimentAssignment::query()
            ->where('experiment_id', $experiment->id)
            ->where('variant_id', $variant->id);

        if (!empty($data['user_id'])) {
            $assignmentQuery->where('user_id', $data['user_id']);
        } elseif (!empty($data['session_id'])) {
            $assignmentQuery->where('session_id', $data['session_id']);
        } else {
            return response()->json([
                'error' => [
                    'code' => 'MISSING_IDENTIFIERS',
                    'message' => 'Kullanıcı veya oturum bilgisi belirtmelisiniz.',
                ],
            ], 422);
        }

        $assignment = $assignmentQuery->first();

        if (!$assignment) {
            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENT_NOT_FOUND',
                    'message' => 'Belirtilen kullanıcı için atama kaydı bulunamadı.',
                ],
            ], 404);
        }

        $assignment->update([
            'converted_at' => now(),
            'conversion_value' => $data['conversion_value'] ?? $assignment->conversion_value,
        ]);

        return response()->json([
            'success' => true,
            'assignment' => $assignment->fresh(),
        ]);
    }

    private function chooseVariant($variants): ExperimentVariant
    {
        $totalWeight = $variants->sum(function (ExperimentVariant $variant) {
            return max($variant->traffic_allocation, 0);
        });

        if ($totalWeight <= 0) {
            return $variants->first();
        }

        $random = random_int(1, $totalWeight);
        $cumulative = 0;

        foreach ($variants as $variant) {
            $cumulative += max($variant->traffic_allocation, 0);
            if ($random <= $cumulative) {
                return $variant;
            }
        }

        return $variants->last();
    }
}

