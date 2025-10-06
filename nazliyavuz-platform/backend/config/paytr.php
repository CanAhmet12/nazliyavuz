<?php

return [
    'merchant_id' => env('PAYTR_MERCHANT_ID'),
    'merchant_key' => env('PAYTR_MERCHANT_KEY'),
    'merchant_salt' => env('PAYTR_MERCHANT_SALT'),
    'test_mode' => env('PAYTR_TEST_MODE', true), // Set to false for production
    'callback_url' => env('APP_URL') . '/api/payments/callback',
    'success_url' => env('APP_URL') . '/payment/success', // Frontend redirect URL
    'fail_url' => env('APP_URL') . '/payment/fail',     // Frontend redirect URL
];