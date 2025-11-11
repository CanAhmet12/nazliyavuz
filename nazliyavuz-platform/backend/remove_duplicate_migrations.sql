-- Remove duplicate migration records
DELETE FROM migrations WHERE migration IN (
    '2025_01_15_000025_add_fcm_tokens_to_users_table',
    '2025_01_15_000026_add_performance_indexes',
    '2025_01_15_000027_enhance_ratings_system',
    '2025_01_15_000029_add_verification_code_to_email_verifications_table'
);

