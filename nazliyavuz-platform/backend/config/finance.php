<?php

return [
    'currency' => env('PLATFORM_CURRENCY', 'TRY'),
    'teacher_share' => (float) env('TEACHER_PAYOUT_SHARE', 0.7),
    'payout_processing_days' => (int) env('TEACHER_PAYOUT_PROCESSING_DAYS', 7),
    'validation' => [
        'pending_payment_grace_days' => (int) env('FINANCE_PENDING_PAYMENT_GRACE_DAYS', 3),
        'payout_overdue_days' => (int) env('FINANCE_PAYOUT_OVERDUE_DAYS', env('TEACHER_PAYOUT_PROCESSING_DAYS', 7) + 2),
    ],
];

