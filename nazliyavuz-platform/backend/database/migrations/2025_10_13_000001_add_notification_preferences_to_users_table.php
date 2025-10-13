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
            $table->boolean('email_notifications')->default(true)->after('status');
            $table->boolean('push_notifications')->default(true)->after('email_notifications');
            $table->boolean('lesson_reminders')->default(true)->after('push_notifications');
            $table->boolean('marketing_emails')->default(false)->after('lesson_reminders');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['email_notifications', 'push_notifications', 'lesson_reminders', 'marketing_emails']);
        });
    }
};

