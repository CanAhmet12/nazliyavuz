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
        Schema::create('reservation_reminder_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('reservation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('reminder_setting_id')->nullable()->constrained('reservation_reminder_settings')->nullOnDelete();
            $table->json('channels')->nullable();
            $table->string('source')->default('automatic');
            $table->timestamp('sent_at')->useCurrent();
            $table->timestamps();

            $table->unique(['reservation_id', 'reminder_setting_id']);
            $table->index('sent_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('reservation_reminder_logs');
    }
};

