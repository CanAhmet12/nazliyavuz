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
        Schema::create('scheduled_notifications', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('message');
            $table->string('type')->default('info');
            $table->string('priority')->default('normal');
            $table->string('target_type')->default('all'); // all, students, teachers, admins
            $table->json('target_filters')->nullable();
            $table->json('channels')->nullable(); // e.g. { "push": true, "email": false, "in_app": true }
            $table->foreignId('template_id')->nullable()->constrained('notification_templates')->nullOnDelete();
            $table->timestamp('scheduled_at')->nullable();
            $table->string('timezone', 64)->nullable();
            $table->string('status')->default('draft'); // draft, scheduled, queued, sending, sent, failed, cancelled
            $table->unsignedInteger('sent_count')->default(0);
            $table->unsignedInteger('fail_count')->default(0);
            $table->timestamp('last_attempt_at')->nullable();
            $table->json('meta')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['status', 'scheduled_at']);
            $table->index('target_type');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('scheduled_notifications');
    }
};

