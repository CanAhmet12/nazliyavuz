-- Add missing columns to users table for teacher approval system
ALTER TABLE users ADD COLUMN IF NOT EXISTS teacher_status VARCHAR(20) NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_notes TEXT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP NULL;

-- Add indexes
CREATE INDEX IF NOT EXISTS users_role_teacher_status_index ON users(role, teacher_status);
CREATE INDEX IF NOT EXISTS users_teacher_status_approved_at_index ON users(teacher_status, approved_at);

