<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Add only missing fields that don't already exist
            if (!Schema::hasColumn('users', 'status')) {
                $table->string('status')->default('active')->after('rejection_reason');
            }
            if (!Schema::hasColumn('users', 'suspended_reason')) {
                $table->text('suspended_reason')->nullable()->after('status');
            }
            if (!Schema::hasColumn('users', 'suspended_at')) {
                $table->timestamp('suspended_at')->nullable()->after('suspended_reason');
            }
            if (!Schema::hasColumn('users', 'suspended_by')) {
                $table->unsignedBigInteger('suspended_by')->nullable()->after('suspended_at');
                
                // Add foreign key constraint
                $table->foreign('suspended_by')->references('id')->on('users')->onDelete('set null');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Drop foreign keys first
            $table->dropForeign(['approved_by']);
            $table->dropForeign(['suspended_by']);
            
            // Drop columns
            $table->dropColumn([
                'phone',
                'bio',
                'teacher_status',
                'admin_notes',
                'approved_by',
                'approved_at',
                'rejection_reason',
                'status',
                'suspended_reason',
                'suspended_at',
                'suspended_by'
            ]);
        });
    }
};
