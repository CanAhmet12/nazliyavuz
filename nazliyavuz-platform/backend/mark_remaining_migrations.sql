-- Mark remaining migrations as ran
-- These tables already exist, we're just marking them

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_01_15_000001_create_chats_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_01_15_000001_create_chats_table', 1);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_01_15_000001_create_payments_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_01_15_000001_create_payments_table', 1);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_01_15_000003_create_shared_files_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_01_15_000003_create_shared_files_table', 1);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_01_15_000004_create_assignments_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_01_15_000004_create_assignments_table', 1);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_01_15_000005_create_lessons_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_01_15_000005_create_lessons_table', 1);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_01_15_000010_add_critical_performance_indexes') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_01_15_000010_add_critical_performance_indexes', 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM migrations WHERE migration = '2025_01_15_000011_create_video_calls_table') THEN
        INSERT INTO migrations (migration, batch) VALUES ('2025_01_15_000011_create_video_calls_table', 2);
    END IF;
END $$;

