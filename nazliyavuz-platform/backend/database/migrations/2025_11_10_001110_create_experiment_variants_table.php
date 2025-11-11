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
        Schema::create('experiment_variants', function (Blueprint $table) {
            $table->id();
            $table->foreignId('experiment_id')->constrained('experiments')->cascadeOnDelete();
            $table->string('name');
            $table->string('key');
            $table->boolean('is_control')->default(false);
            $table->unsignedInteger('traffic_allocation')->default(0); // percentage weight
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->unique(['experiment_id', 'key']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('experiment_variants');
    }
};

