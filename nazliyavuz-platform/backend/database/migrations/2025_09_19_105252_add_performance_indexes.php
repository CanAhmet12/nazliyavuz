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
        // Add online_available column to teachers table if it doesn't exist
        if (!Schema::hasColumn('teachers', 'online_available')) {
            Schema::table('teachers', function (Blueprint $table) {
                $table->boolean('online_available')->default(false)->after('rating_count');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasColumn('teachers', 'online_available')) {
            Schema::table('teachers', function (Blueprint $table) {
                $table->dropColumn('online_available');
            });
        }
    }
};