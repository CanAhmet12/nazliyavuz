<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Bu tablo öğretmenlerin özel günlerini (tatil, izin, özel saatler) saklar.
     * Örnek: 15 Ocak tam gün izinli, 20 Ocak sadece 14-16 arası müsait
     */
    public function up(): void
    {
        Schema::create('teacher_exceptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('teacher_id')->constrained('teachers', 'user_id')->onDelete('cascade');
            $table->date('exception_date'); // Özel gün tarihi
            $table->enum('type', ['unavailable', 'custom_hours'])->default('unavailable');
            // unavailable = Tamamen müsait değil (izin, tatil)
            // custom_hours = O gün için özel saatler (haftalık takvimi override eder)
            
            $table->time('start_time')->nullable(); // custom_hours için başlangıç
            $table->time('end_time')->nullable();   // custom_hours için bitiş
            $table->string('reason', 255)->nullable(); // "Tatilde", "Hasta", "Özel toplantı"
            $table->text('notes')->nullable(); // Detaylı açıklama
            $table->boolean('is_active')->default(true); // Aktif mi?
            $table->timestamps();
            
            // Indexes
            $table->index(['teacher_id', 'exception_date']);
            $table->index(['exception_date', 'is_active']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('teacher_exceptions');
    }
};

