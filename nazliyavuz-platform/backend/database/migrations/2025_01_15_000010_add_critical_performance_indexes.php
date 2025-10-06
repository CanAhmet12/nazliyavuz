<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Critical indexes for reservations table
        Schema::table('reservations', function (Blueprint $table) {
            // Composite index for teacher dashboard queries
            if (!$this->indexExists('reservations', 'reservations_teacher_status_datetime_index')) {
                $table->index(['teacher_id', 'status', 'proposed_datetime'], 'reservations_teacher_status_datetime_index');
            }
            
            // Composite index for student dashboard queries
            if (!$this->indexExists('reservations', 'reservations_student_status_datetime_index')) {
                $table->index(['student_id', 'status', 'proposed_datetime'], 'reservations_student_status_datetime_index');
            }
            
            // Index for date range queries
            if (!$this->indexExists('reservations', 'reservations_proposed_datetime_status_index')) {
                $table->index(['proposed_datetime', 'status'], 'reservations_proposed_datetime_status_index');
            }
            
            // Index for category-based queries
            if (!$this->indexExists('reservations', 'reservations_category_status_index')) {
                $table->index(['category_id', 'status'], 'reservations_category_status_index');
            }
        });

        // Critical indexes for users table
        Schema::table('users', function (Blueprint $table) {
            // Index for role-based queries
            if (!$this->indexExists('users', 'users_role_created_at_index')) {
                $table->index(['role', 'created_at'], 'users_role_created_at_index');
            }
            
            // Index for email verification queries
            if (!$this->indexExists('users', 'users_email_verified_at_index')) {
                $table->index(['email_verified_at'], 'users_email_verified_at_index');
            }
            
            // Index for active users
            if (!$this->indexExists('users', 'users_is_active_created_at_index')) {
                $table->index(['is_active', 'created_at'], 'users_is_active_created_at_index');
            }
        });

        // Critical indexes for teachers table
        Schema::table('teachers', function (Blueprint $table) {
            // Index for online teachers
            if (!$this->indexExists('teachers', 'teachers_online_available_rating_index')) {
                $table->index(['online_available', 'rating'], 'teachers_online_available_rating_index');
            }
            
            // Index for approved teachers with rating
            if (!$this->indexExists('teachers', 'teachers_is_approved_rating_index')) {
                $table->index(['is_approved', 'rating'], 'teachers_is_approved_rating_index');
            }
            
            // Index for price range queries
            if (!$this->indexExists('teachers', 'teachers_price_per_hour_index')) {
                $table->index(['price_per_hour'], 'teachers_price_per_hour_index');
            }
        });

        // Critical indexes for messages table
        Schema::table('messages', function (Blueprint $table) {
            // Composite index for chat queries
            if (!$this->indexExists('messages', 'messages_sender_receiver_created_index')) {
                $table->index(['sender_id', 'receiver_id', 'created_at'], 'messages_sender_receiver_created_index');
            }
            
            // Index for unread messages
            if (!$this->indexExists('messages', 'messages_receiver_is_read_index')) {
                $table->index(['receiver_id', 'is_read'], 'messages_receiver_is_read_index');
            }
            
            // Index for message type queries
            if (!$this->indexExists('messages', 'messages_type_created_at_index')) {
                $table->index(['message_type', 'created_at'], 'messages_type_created_at_index');
            }
        });

        // Critical indexes for chats table
        Schema::table('chats', function (Blueprint $table) {
            // Index for user chat queries
            if (!$this->indexExists('chats', 'chats_user1_user2_index')) {
                $table->index(['user1_id', 'user2_id'], 'chats_user1_user2_index');
            }
            
            // Index for last message queries
            if (!$this->indexExists('chats', 'chats_last_message_at_index')) {
                $table->index(['last_message_at'], 'chats_last_message_at_index');
            }
        });

        // Critical indexes for notifications table
        Schema::table('notifications', function (Blueprint $table) {
            // Index for user notifications
            if (!$this->indexExists('notifications', 'notifications_user_read_created_index')) {
                $table->index(['user_id', 'is_read', 'created_at'], 'notifications_user_read_created_index');
            }
            
            // Index for notification type queries
            if (!$this->indexExists('notifications', 'notifications_type_created_at_index')) {
                $table->index(['type', 'created_at'], 'notifications_type_created_at_index');
            }
        });

        // Critical indexes for assignments table
        Schema::table('assignments', function (Blueprint $table) {
            // Index for teacher assignments
            if (!$this->indexExists('assignments', 'assignments_teacher_status_due_index')) {
                $table->index(['teacher_id', 'status', 'due_date'], 'assignments_teacher_status_due_index');
            }
            
            // Index for student assignments
            if (!$this->indexExists('assignments', 'assignments_student_status_due_index')) {
                $table->index(['student_id', 'status', 'due_date'], 'assignments_student_status_due_index');
            }
        });

        // Critical indexes for lessons table
        Schema::table('lessons', function (Blueprint $table) {
            // Index for teacher lessons
            if (!$this->indexExists('lessons', 'lessons_teacher_datetime_index')) {
                $table->index(['teacher_id', 'start_datetime'], 'lessons_teacher_datetime_index');
            }
            
            // Index for student lessons
            if (!$this->indexExists('lessons', 'lessons_student_datetime_index')) {
                $table->index(['student_id', 'start_datetime'], 'lessons_student_datetime_index');
            }
        });

        // Critical indexes for ratings table
        Schema::table('ratings', function (Blueprint $table) {
            // Index for teacher ratings
            if (!$this->indexExists('ratings', 'ratings_teacher_created_at_index')) {
                $table->index(['teacher_id', 'created_at'], 'ratings_teacher_created_at_index');
            }
            
            // Index for student ratings
            if (!$this->indexExists('ratings', 'ratings_student_created_at_index')) {
                $table->index(['student_id', 'created_at'], 'ratings_student_created_at_index');
            }
        });

        // Critical indexes for payments table
        Schema::table('payments', function (Blueprint $table) {
            // Index for user payments
            if (!$this->indexExists('payments', 'payments_user_status_created_index')) {
                $table->index(['user_id', 'status', 'created_at'], 'payments_user_status_created_index');
            }
            
            // Index for payment method queries
            if (!$this->indexExists('payments', 'payments_method_created_at_index')) {
                $table->index(['payment_method', 'created_at'], 'payments_method_created_at_index');
            }
        });

        // Critical indexes for audit_logs table
        Schema::table('audit_logs', function (Blueprint $table) {
            // Index for user audit logs
            if (!$this->indexExists('audit_logs', 'audit_logs_user_created_at_index')) {
                $table->index(['user_id', 'created_at'], 'audit_logs_user_created_at_index');
            }
            
            // Index for action type queries
            if (!$this->indexExists('audit_logs', 'audit_logs_action_created_at_index')) {
                $table->index(['action', 'created_at'], 'audit_logs_action_created_at_index');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Drop all indexes
        Schema::table('reservations', function (Blueprint $table) {
            $table->dropIndex('reservations_teacher_status_datetime_index');
            $table->dropIndex('reservations_student_status_datetime_index');
            $table->dropIndex('reservations_proposed_datetime_status_index');
            $table->dropIndex('reservations_category_status_index');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex('users_role_created_at_index');
            $table->dropIndex('users_email_verified_at_index');
            $table->dropIndex('users_is_active_created_at_index');
        });

        Schema::table('teachers', function (Blueprint $table) {
            $table->dropIndex('teachers_online_available_rating_index');
            $table->dropIndex('teachers_is_approved_rating_index');
            $table->dropIndex('teachers_price_per_hour_index');
        });

        Schema::table('messages', function (Blueprint $table) {
            $table->dropIndex('messages_sender_receiver_created_index');
            $table->dropIndex('messages_receiver_is_read_index');
            $table->dropIndex('messages_type_created_at_index');
        });

        Schema::table('chats', function (Blueprint $table) {
            $table->dropIndex('chats_user1_user2_index');
            $table->dropIndex('chats_last_message_at_index');
        });

        Schema::table('notifications', function (Blueprint $table) {
            $table->dropIndex('notifications_user_read_created_index');
            $table->dropIndex('notifications_type_created_at_index');
        });

        Schema::table('assignments', function (Blueprint $table) {
            $table->dropIndex('assignments_teacher_status_due_index');
            $table->dropIndex('assignments_student_status_due_index');
        });

        Schema::table('lessons', function (Blueprint $table) {
            $table->dropIndex('lessons_teacher_datetime_index');
            $table->dropIndex('lessons_student_datetime_index');
        });

        Schema::table('ratings', function (Blueprint $table) {
            $table->dropIndex('ratings_teacher_created_at_index');
            $table->dropIndex('ratings_student_created_at_index');
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->dropIndex('payments_user_status_created_index');
            $table->dropIndex('payments_method_created_at_index');
        });

        Schema::table('audit_logs', function (Blueprint $table) {
            $table->dropIndex('audit_logs_user_created_at_index');
            $table->dropIndex('audit_logs_action_created_at_index');
        });
    }

    /**
     * Check if index exists
     */
    private function indexExists($table, $indexName): bool
    {
        try {
            $indexes = DB::select("SHOW INDEX FROM {$table}");
            foreach ($indexes as $index) {
                if ($index->Key_name === $indexName) {
                    return true;
                }
            }
            return false;
        } catch (Exception $e) {
            return false;
        }
    }
};
