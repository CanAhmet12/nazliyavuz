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
        Schema::create('experiment_assignments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('experiment_id')->constrained('experiments')->cascadeOnDelete();
            $table->foreignId('variant_id')->constrained('experiment_variants')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('session_id')->nullable();
            $table->string('context')->nullable();
            $table->timestamp('assigned_at')->useCurrent();
            $table->timestamp('converted_at')->nullable();
            $table->decimal('conversion_value', 12, 2)->nullable();
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->unique(['experiment_id', 'user_id']);
            $table->index(['experiment_id', 'variant_id']);
            $table->index('assigned_at');
            $table->index('converted_at');
            $table->index('session_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('experiment_assignments');
    }
};

