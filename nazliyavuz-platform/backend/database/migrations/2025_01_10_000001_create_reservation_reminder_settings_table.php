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
        Schema::create('reservation_reminder_settings', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->unsignedInteger('offset_minutes');
            $table->boolean('enabled')->default(true);
            $table->boolean('notify_student')->default(true);
            $table->boolean('notify_teacher')->default(true);
            $table->boolean('send_email')->default(false);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('reservation_reminder_settings');
    }
};

