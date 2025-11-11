-- Mark existing migrations as ran
-- This is safe because the tables already exist

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_214804_create_teachers_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_214804_create_teachers_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_214816_create_categories_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_214816_create_categories_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_214826_create_teacher_category_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_214826_create_teacher_category_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_214839_create_reservations_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_214839_create_reservations_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_214853_create_notifications_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_214853_create_notifications_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_214907_create_favorites_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_214907_create_favorites_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_214917_create_audit_logs_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_214917_create_audit_logs_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_223820_create_ratings_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_223820_create_ratings_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_224735_create_email_verifications_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_224735_create_email_verifications_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_224758_create_password_resets_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_224758_create_password_resets_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_18_231201_create_content_pages_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_18_231201_create_content_pages_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_19_004752_create_teacher_availabilities_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_19_004752_create_teacher_availabilities_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_19_104041_add_fcm_tokens_to_users_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_19_104041_add_fcm_tokens_to_users_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_19_105252_add_performance_indexes') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_19_105252_add_performance_indexes', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_19_112952_create_teacher_certifications_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_19_112952_create_teacher_certifications_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_19_113140_enhance_ratings_system') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_19_113140_enhance_ratings_system', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_19_120457_create_messages_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_19_120457_create_messages_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_19_190308_create_social_accounts_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_19_190308_create_social_accounts_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_19_191148_create_message_reactions_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_19_191148_create_message_reactions_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_20_135719_add_teacher_approval_system') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_20_135719_add_teacher_approval_system', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_21_234839_add_verification_code_to_email_verifications_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_21_234839_add_verification_code_to_email_verifications_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_09_27_034136_add_last_login_at_to_users_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_09_27_034136_add_last_login_at_to_users_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_10_04_011541_add_missing_user_fields_to_users_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_10_04_011541_add_missing_user_fields_to_users_table', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_10_04_031832_add_chat_id_to_messages_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_10_04_031832_add_chat_id_to_messages_table', 2);
    END IF;
END $$;

