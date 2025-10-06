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
        // Users tablosuna teacher onay alanları ekle (sadece eksik olanları)
        Schema::table('users', function (Blueprint $table) {
            // teacher_status kolonu yok, onu da ekle
            if (!Schema::hasColumn('users', 'teacher_status')) {
                $table->enum('teacher_status', ['pending', 'approved', 'rejected'])->nullable()->after('role');
            }
            if (!Schema::hasColumn('users', 'admin_notes')) {
                $table->text('admin_notes')->nullable()->after('teacher_status');
            }
            if (!Schema::hasColumn('users', 'approved_by')) {
                $table->foreignId('approved_by')->nullable()->constrained('users')->after('admin_notes');
            }
            if (!Schema::hasColumn('users', 'approved_at')) {
                $table->timestamp('approved_at')->nullable()->after('approved_by');
            }
            if (!Schema::hasColumn('users', 'rejection_reason')) {
                $table->text('rejection_reason')->nullable()->after('approved_at');
            }
        });

        // Teachers tablosuna onay durumu ekle (sadece eksik olanları)
        Schema::table('teachers', function (Blueprint $table) {
            if (!Schema::hasColumn('teachers', 'is_approved')) {
                $table->boolean('is_approved')->default(false)->after('online_available');
            }
            if (!Schema::hasColumn('teachers', 'approved_at')) {
                $table->timestamp('approved_at')->nullable()->after('is_approved');
            }
            if (!Schema::hasColumn('teachers', 'approved_by')) {
                $table->foreignId('approved_by')->nullable()->constrained('users')->after('approved_at');
            }
        });

        // Index'ler ekle (sadece yoksa)
        Schema::table('users', function (Blueprint $table) {
            if (!$this->indexExists('users', 'users_role_teacher_status_index')) {
                $table->index(['role', 'teacher_status'], 'users_role_teacher_status_index');
            }
            if (!$this->indexExists('users', 'users_teacher_status_approved_at_index')) {
                $table->index(['teacher_status', 'approved_at'], 'users_teacher_status_approved_at_index');
            }
        });

        Schema::table('teachers', function (Blueprint $table) {
            if (!$this->indexExists('teachers', 'teachers_is_approved_approved_at_index')) {
                $table->index(['is_approved', 'approved_at'], 'teachers_is_approved_approved_at_index');
            }
        });
    }

    private function indexExists($table, $indexName)
    {
        try {
            $indexes = DB::select("PRAGMA index_list($table)");
            foreach ($indexes as $index) {
                if ($index->name === $indexName) {
                    return true;
                }
            }
            return false;
        } catch (Exception $e) {
            return false;
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex('users_role_teacher_status_index');
            $table->dropIndex('users_teacher_status_approved_at_index');
            $table->dropColumn([
                'teacher_status',
                'admin_notes',
                'approved_by',
                'approved_at',
                'rejection_reason'
            ]);
        });

        Schema::table('teachers', function (Blueprint $table) {
            $table->dropIndex('teachers_is_approved_approved_at_index');
            $table->dropColumn([
                'is_approved',
                'approved_at',
                'approved_by'
            ]);
        });
    }
};