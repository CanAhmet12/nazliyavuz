<?php

namespace App\Http\Controllers;

use App\Models\Payment;
use App\Models\Reservation;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AdminFinanceController extends Controller
{
    public function overview(): JsonResponse
    {
        $currency = config('finance.currency', 'TRY');
        $teacherShare = (float) config('finance.teacher_share', 0.7);
        $payoutProcessingDays = (int) config('finance.payout_processing_days', 7);

        $totalRevenue = (float) Payment::successful()->sum('amount');

        $monthlyRevenue = (float) Payment::successful()
            ->where(function ($query) {
                $query->where(function ($sub) {
                    $sub->whereNotNull('paid_at')
                        ->where('paid_at', '>=', now()->subDays(30));
                })->orWhere(function ($sub) {
                    $sub->whereNull('paid_at')
                        ->where('created_at', '>=', now()->subDays(30));
                });
            })
            ->sum('amount');

        $outstandingPayments = (float) Payment::whereIn('status', ['pending', 'processing'])->sum('amount');

        $payoutEligiblePaymentsQuery = Payment::successful()
            ->whereHas('reservation', function ($query) {
                $query->whereIn('status', ['accepted', 'completed']);
            });

        $payoutBalance = (float) (clone $payoutEligiblePaymentsQuery)->sum('amount') * $teacherShare;

        $startMonth = now()->subMonths(5)->startOfMonth();
        $trendRaw = Payment::successful()
            ->selectRaw("DATE_FORMAT(COALESCE(paid_at, created_at), '%Y-%m-01') as month_start, SUM(amount) as total")
            ->where(function ($query) use ($startMonth) {
                $query->where(function ($sub) use ($startMonth) {
                    $sub->whereNotNull('paid_at')
                        ->where('paid_at', '>=', $startMonth);
                })->orWhere(function ($sub) use ($startMonth) {
                    $sub->whereNull('paid_at')
                        ->where('created_at', '>=', $startMonth);
                });
            })
            ->groupBy('month_start')
            ->orderBy('month_start')
            ->get()
            ->values();

        $revenueTrend = collect(range(5, 0))->map(function ($i) use ($trendRaw) {
            $start = now()->subMonths($i)->startOfMonth();
            $label = (clone $start)->locale('tr')->translatedFormat('F Y');
            $key = $start->format('Y-m-01');
            $match = $trendRaw->firstWhere('month_start', $key);

            return [
                'month' => ucfirst($label),
                'value' => (float) ($match->total ?? 0),
            ];
        });

        $paymentMethodCounts = Payment::successful()
            ->selectRaw('COALESCE(payment_method, "other") as method, COUNT(*) as count')
            ->groupBy('method')
            ->get();

        $totalMethodCount = max($paymentMethodCounts->sum('count'), 1);
        $paymentMethods = $paymentMethodCounts->map(function ($item) use ($totalMethodCount) {
            return [
                'method' => $this->translatePaymentMethod($item->method),
                'percentage' => round(($item->count / $totalMethodCount) * 100, 2),
            ];
        });

        $recentPayments = Payment::successful()
            ->with(['user', 'reservation.teacher'])
            ->orderByDesc(DB::raw('COALESCE(paid_at, created_at)'))
            ->limit(5)
            ->get()
            ->map(function (Payment $payment) {
                $status = match ($payment->status) {
                    'success' => 'paid',
                    'refunded' => 'refunded',
                    default => 'failed',
                };

                return [
                    'id' => $payment->paytr_order_id ?? $payment->id,
                    'student' => $payment->user?->name ?? 'Bilinmiyor',
                    'teacher' => $payment->reservation?->teacher?->name ?? 'Bilinmiyor',
                    'amount' => (float) $payment->amount,
                    'currency' => $payment->currency,
                    'status' => $status,
                    'date' => optional($payment->paid_at ?? $payment->created_at)->toISOString(),
                ];
            });

        $pendingPayouts = (clone $payoutEligiblePaymentsQuery)
            ->with(['reservation.teacher'])
            ->orderBy(DB::raw('COALESCE(paid_at, created_at)'), 'asc')
            ->limit(5)
            ->get()
            ->map(function (Payment $payment) use ($teacherShare, $payoutProcessingDays) {
                $baseDate = $payment->paid_at ?? $payment->created_at ?? now();
                $scheduledDate = (clone $baseDate)->addDays($payoutProcessingDays);
                $status = $scheduledDate->isPast() ? 'processing' : 'scheduled';

                return [
                    'id' => $payment->paytr_order_id ?? $payment->id,
                    'teacher' => $payment->reservation?->teacher?->name ?? 'Bilinmiyor',
                    'amount' => round((float) $payment->amount * $teacherShare, 2),
                    'currency' => $payment->currency,
                    'scheduledDate' => $scheduledDate->toISOString(),
                    'status' => $status,
                ];
            });

        $topTeachers = Reservation::query()
            ->select('teacher_id', DB::raw('SUM(price) as total_amount'), DB::raw('COUNT(*) as total_lessons'))
            ->whereIn('status', ['accepted', 'completed'])
            ->groupBy('teacher_id')
            ->orderByDesc('total_amount')
            ->limit(5)
            ->with('teacher')
            ->get()
            ->map(function (Reservation $reservation) use ($teacherShare, $currency) {
                return [
                    'teacher' => $reservation->teacher?->name ?? 'Bilinmiyor',
                    'amount' => round((float) $reservation->total_amount * $teacherShare, 2),
                    'currency' => $currency,
                    'lessons' => (int) $reservation->total_lessons,
                ];
            });

        $now = now();
        $pendingPaymentGraceDays = (int) config('finance.validation.pending_payment_grace_days', 3);
        $payoutOverdueDays = (int) config('finance.validation.payout_overdue_days', $payoutProcessingDays);

        $alerts = [];

        $missingPaymentLinks = Reservation::whereIn('payment_status', ['paid', 'partial_refund'])
            ->whereDoesntHave('payments', function ($query) {
                $query->where('status', 'success');
            })
            ->count();

        if ($missingPaymentLinks > 0) {
            $alerts[] = [
                'id' => 'missing_payment_links',
                'severity' => 'error',
                'title' => 'Başarılı ödeme kaydı bulunamadı',
                'message' => sprintf(
                    '%d rezervasyon için ödeme durumu "ödendi" ancak başarılı ödeme kaydı bulunamadı.',
                    $missingPaymentLinks
                ),
                'affected' => $missingPaymentLinks,
            ];
        }

        $stalePendingPayments = Payment::whereIn('status', ['pending', 'processing'])
            ->where('created_at', '<', $now->copy()->subDays($pendingPaymentGraceDays))
            ->count();

        if ($stalePendingPayments > 0) {
            $alerts[] = [
                'id' => 'stale_pending_payments',
                'severity' => 'warning',
                'title' => 'Uzun süredir bekleyen ödemeler var',
                'message' => sprintf(
                    '%d ödeme kaydı %d günden uzun süredir "bekleyen" durumunda.',
                    $stalePendingPayments,
                    $pendingPaymentGraceDays
                ),
                'affected' => $stalePendingPayments,
                'meta' => [
                    'threshold_days' => $pendingPaymentGraceDays,
                ],
            ];
        }

        $overduePayoutsCount = (clone $payoutEligiblePaymentsQuery)
            ->whereRaw('COALESCE(paid_at, created_at) <= ?', [$now->copy()->subDays($payoutOverdueDays)])
            ->count();

        if ($overduePayoutsCount > 0) {
            $alerts[] = [
                'id' => 'overdue_payouts',
                'severity' => 'warning',
                'title' => 'Öğretmen ödemesi gecikiyor',
                'message' => sprintf(
                    '%d öğretmen ödemesi planlanan payout süresini geçti.',
                    $overduePayoutsCount
                ),
                'affected' => $overduePayoutsCount,
                'meta' => [
                    'threshold_days' => $payoutOverdueDays,
                ],
            ];
        }

        $orphanPayments = Payment::successful()
            ->whereNull('reservation_id')
            ->count();

        if ($orphanPayments > 0) {
            $alerts[] = [
                'id' => 'orphan_payments',
                'severity' => 'warning',
                'title' => 'Rezervasyona bağlı olmayan ödemeler',
                'message' => sprintf(
                    '%d başarılı ödeme, herhangi bir rezervasyon kaydına bağlı değil.',
                    $orphanPayments
                ),
                'affected' => $orphanPayments,
            ];
        }

        $negativePayments = Payment::where('amount', '<=', 0)->count();

        if ($negativePayments > 0) {
            $alerts[] = [
                'id' => 'negative_payments',
                'severity' => 'error',
                'title' => 'Geçersiz ödeme tutarları',
                'message' => sprintf(
                    '%d ödeme kaydında sıfır veya negatif tutar tespit edildi.',
                    $negativePayments
                ),
                'affected' => $negativePayments,
            ];
        }

        return response()->json([
            'success' => true,
            'totals' => [
                'totalRevenue' => round($totalRevenue, 2),
                'monthlyRevenue' => round($monthlyRevenue, 2),
                'outstandingPayments' => round($outstandingPayments, 2),
                'payoutBalance' => round($payoutBalance, 2),
                'currency' => $currency,
            ],
            'revenueTrend' => $revenueTrend,
            'paymentMethods' => $paymentMethods,
            'recentPayments' => $recentPayments,
            'pendingPayouts' => $pendingPayouts,
            'topTeachers' => $topTeachers,
            'alerts' => $alerts,
            'generatedAt' => $now->toIso8601String(),
        ]);
    }

    public function exportPayments(Request $request): StreamedResponse|JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'start_date' => 'nullable|date',
            'end_date' => 'nullable|date|after_or_equal:start_date',
            'status' => 'nullable|in:pending,processing,success,failed,cancelled,refunded',
            'format' => 'nullable|in:csv',
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
        $startDate = isset($data['start_date']) ? Carbon::parse($data['start_date'])->startOfDay() : null;
        $endDate = isset($data['end_date']) ? Carbon::parse($data['end_date'])->endOfDay() : null;
        $status = $data['status'] ?? null;

        $paymentsQuery = Payment::query()
            ->with(['user', 'reservation.teacher'])
            ->when($status, fn ($query) => $query->where('status', $status))
            ->when(!$status, fn ($query) => $query->whereIn('status', ['success', 'refunded']));

        $this->applyPaymentDateFilters($paymentsQuery, $startDate, $endDate);

        $filename = sprintf('finance-payments-%s.csv', now()->format('Ymd_His'));

        return response()->streamDownload(function () use ($paymentsQuery) {
            $handle = fopen('php://output', 'w');
            if ($handle === false) {
                return;
            }

            fwrite($handle, chr(0xEF) . chr(0xBB) . chr(0xBF));

            fputcsv($handle, [
                'Payment ID',
                'PayTR Order',
                'Student',
                'Student Email',
                'Reservation ID',
                'Teacher',
                'Amount',
                'Currency',
                'Status',
                'Method',
                'Paid At',
                'Created At',
            ]);

            $paymentsQuery->orderBy('id')->chunkById(500, function ($payments) use ($handle) {
                foreach ($payments as $payment) {
                    $student = $payment->user;
                    $reservation = $payment->reservation;
                    $teacher = $reservation?->teacher;

                    fputcsv($handle, [
                        $payment->id,
                        $payment->paytr_order_id,
                        $student?->name ?? 'Bilinmiyor',
                        $student?->email ?? '',
                        $reservation?->id ?? '',
                        $teacher?->name ?? '',
                        number_format((float) $payment->amount, 2, '.', ''),
                        $payment->currency,
                        $payment->status,
                        $payment->payment_method ?? '',
                        $this->formatExportDate($payment->paid_at),
                        $this->formatExportDate($payment->created_at),
                    ]);
                }
            }, 'id');

            fclose($handle);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    public function exportPayouts(Request $request): StreamedResponse|JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'start_date' => 'nullable|date',
            'end_date' => 'nullable|date|after_or_equal:start_date',
            'format' => 'nullable|in:csv',
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
        $startDate = isset($data['start_date']) ? Carbon::parse($data['start_date'])->startOfDay() : null;
        $endDate = isset($data['end_date']) ? Carbon::parse($data['end_date'])->endOfDay() : null;

        $teacherShare = (float) config('finance.teacher_share', 0.7);
        $payoutProcessingDays = (int) config('finance.payout_processing_days', 7);

        $paymentsQuery = Payment::successful()
            ->whereHas('reservation.teacher')
            ->with(['reservation.teacher']);

        $this->applyPaymentDateFilters($paymentsQuery, $startDate, $endDate);

        $aggregates = [];

        $paymentsQuery->orderBy('id')->chunkById(500, function ($payments) use (
            &$aggregates,
            $teacherShare,
            $payoutProcessingDays
        ) {
            foreach ($payments as $payment) {
                $teacher = $payment->reservation?->teacher;
                if (!$teacher) {
                    continue;
                }

                $teacherId = $teacher->id;

                if (!isset($aggregates[$teacherId])) {
                    $aggregates[$teacherId] = [
                        'teacher' => $teacher->name ?? 'Bilinmiyor',
                        'email' => $teacher->email ?? '',
                        'lesson_count' => 0,
                        'gross_amount' => 0.0,
                        'share_amount' => 0.0,
                        'currency' => $payment->currency ?? 'TRY',
                        'last_payment_at' => null,
                        'next_payout_date' => null,
                    ];
                }

                $aggregates[$teacherId]['lesson_count']++;
                $aggregates[$teacherId]['gross_amount'] += (float) $payment->amount;
                $aggregates[$teacherId]['share_amount'] += (float) $payment->amount * $teacherShare;

                $currency = $payment->currency ?? 'TRY';
                if ($aggregates[$teacherId]['currency'] !== $currency) {
                    $aggregates[$teacherId]['currency'] = 'MIXED';
                }

                $baseDate = $payment->paid_at ?? $payment->created_at;
                if ($baseDate) {
                    $baseDate = $baseDate->copy();
                    if (
                        !$aggregates[$teacherId]['last_payment_at']
                        || $baseDate->gt($aggregates[$teacherId]['last_payment_at'])
                    ) {
                        $aggregates[$teacherId]['last_payment_at'] = $baseDate;
                        $aggregates[$teacherId]['next_payout_date'] = $baseDate->copy()->addDays($payoutProcessingDays);
                    }
                }
            }
        }, 'id');

        $records = array_values($aggregates);
        usort($records, fn ($a, $b) => $b['share_amount'] <=> $a['share_amount']);

        $filename = sprintf('finance-payouts-%s.csv', now()->format('Ymd_His'));

        return response()->streamDownload(function () use ($records) {
            $handle = fopen('php://output', 'w');
            if ($handle === false) {
                return;
            }

            fwrite($handle, chr(0xEF) . chr(0xBB) . chr(0xBF));

            fputcsv($handle, [
                'Teacher',
                'Email',
                'Lesson Count',
                'Gross Revenue',
                'Teacher Share',
                'Currency',
                'Last Payment At',
                'Next Payout Date',
            ]);

            foreach ($records as $row) {
                fputcsv($handle, [
                    $row['teacher'],
                    $row['email'],
                    $row['lesson_count'],
                    number_format((float) $row['gross_amount'], 2, '.', ''),
                    number_format((float) $row['share_amount'], 2, '.', ''),
                    $row['currency'],
                    $this->formatExportDate($row['last_payment_at']),
                    $this->formatExportDate($row['next_payout_date']),
                ]);
            }

            fclose($handle);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    private function applyPaymentDateFilters($query, ?Carbon $startDate, ?Carbon $endDate): void
    {
        $query
            ->when($startDate, function ($query) use ($startDate) {
                $query->where(function ($subQuery) use ($startDate) {
                    $subQuery
                        ->whereNotNull('paid_at')
                        ->where('paid_at', '>=', $startDate)
                        ->orWhere(function ($nested) use ($startDate) {
                            $nested->whereNull('paid_at')->where('created_at', '>=', $startDate);
                        });
                });
            })
            ->when($endDate, function ($query) use ($endDate) {
                $query->where(function ($subQuery) use ($endDate) {
                    $subQuery
                        ->whereNotNull('paid_at')
                        ->where('paid_at', '<=', $endDate)
                        ->orWhere(function ($nested) use ($endDate) {
                            $nested->whereNull('paid_at')->where('created_at', '<=', $endDate);
                        });
                });
            });
    }

    private function formatExportDate($date): string
    {
        if (!$date instanceof Carbon) {
            return '';
        }

        return $date->copy()->timezone(config('app.timezone'))->format('Y-m-d H:i:s');
    }

    public function forecast(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'history_days' => 'nullable|integer|min:30|max:365',
            'forecast_days' => 'nullable|integer|min:7|max:90',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors(),
                ],
            ], 422);
        }

        $historyDays = (int) ($request->input('history_days', 120));
        $forecastDays = (int) ($request->input('forecast_days', 45));

        $endDate = Carbon::today();
        $startDate = (clone $endDate)->subDays($historyDays - 1);

        $rawDaily = Payment::successful()
            ->selectRaw("DATE(COALESCE(paid_at, created_at)) as day, SUM(amount) as total")
            ->where(function ($query) use ($startDate, $endDate) {
                $query->where(function ($sub) use ($startDate, $endDate) {
                    $sub->whereNotNull('paid_at')
                        ->whereBetween('paid_at', [$startDate->copy()->startOfDay(), $endDate->copy()->endOfDay()]);
                })->orWhere(function ($sub) use ($startDate, $endDate) {
                    $sub->whereNull('paid_at')
                        ->whereBetween('created_at', [$startDate->copy()->startOfDay(), $endDate->copy()->endOfDay()]);
                });
            })
            ->groupBy('day')
            ->orderBy('day')
            ->get()
            ->pluck('total', 'day');

        $actualSeries = [];
        $dayCursor = $startDate->copy();
        $index = 0;
        $sumX = 0.0;
        $sumY = 0.0;
        $sumXY = 0.0;
        $sumX2 = 0.0;

        while ($dayCursor->lte($endDate)) {
            $key = $dayCursor->format('Y-m-d');
            $value = (float) ($rawDaily[$key] ?? 0.0);

            $actualSeries[] = [
                'date' => $dayCursor->toDateString(),
                'value' => round($value, 2),
            ];

            $sumX += $index;
            $sumY += $value;
            $sumXY += $index * $value;
            $sumX2 += $index * $index;

            $index++;
            $dayCursor->addDay();
        }

        $n = max(count($actualSeries), 1);
        $denominator = ($n * $sumX2) - ($sumX * $sumX);
        $slope = $denominator !== 0.0 ? (($n * $sumXY) - ($sumX * $sumY)) / $denominator : 0.0;
        $intercept = ($sumY - ($slope * $sumX)) / $n;

        $predictedActual = [];
        foreach ($actualSeries as $idx => $item) {
            $predictedActual[$item['date']] = $intercept + ($slope * $idx);
        }

        $errors = [];
        foreach ($actualSeries as $item) {
            $pred = $predictedActual[$item['date']] ?? $item['value'];
            $errors[] = abs($item['value'] - $pred);
        }
        $errorMargin = !empty($errors) ? max(array_sum($errors) / count($errors), 0.0) : 0.0;

        $forecastSeries = [];
        $lastIndex = $n - 1;
        $forecastSum = 0.0;

        for ($i = 1; $i <= $forecastDays; $i++) {
            $futureIndex = $lastIndex + $i;
            $futureDate = $endDate->copy()->addDays($i);
            $predictedValue = max($intercept + ($slope * $futureIndex), 0.0);
            $lower = max($predictedValue - $errorMargin, 0.0);
            $upper = $predictedValue + $errorMargin;

            $forecastSeries[] = [
                'date' => $futureDate->toDateString(),
                'value' => round($predictedValue, 2),
                'lower' => round($lower, 2),
                'upper' => round($upper, 2),
            ];

            if ($i <= 30) {
                $forecastSum += $predictedValue;
            }
        }

        $avgDaily = $n > 0 ? array_sum(array_column($actualSeries, 'value')) / $n : 0.0;
        $lastActual = end($actualSeries);
        $lastForecast = $forecastSeries[0] ?? ['value' => $avgDaily];
        $trendPct = ($lastActual['value'] ?? 0.0) > 0
            ? (($lastForecast['value'] - $lastActual['value']) / max($lastActual['value'], 1e-3)) * 100
            : 0.0;

        return response()->json([
            'success' => true,
            'currency' => config('finance.currency', 'TRY'),
            'historyDays' => $historyDays,
            'forecastDays' => $forecastDays,
            'actual' => $actualSeries,
            'forecast' => $forecastSeries,
            'summary' => [
                'averageDailyRevenue' => round($avgDaily, 2),
                'projected30DayRevenue' => round($forecastSum, 2),
                'trendPercentage' => round($trendPct, 2),
                'slope' => round($slope, 4),
            ],
            'generatedAt' => Carbon::now()->toIso8601String(),
        ]);
    }

    private function translatePaymentMethod(?string $method): string
    {
        $map = [
            'credit_card' => 'Kredi Kartı',
            'debit_card' => 'Banka Kartı',
            'bank_transfer' => 'Havale/EFT',
            'cash' => 'Nakit',
            'other' => 'Diğer',
        ];

        return $map[$method] ?? ucfirst(str_replace('_', ' ', $method ?? 'Diğer'));
    }
}

