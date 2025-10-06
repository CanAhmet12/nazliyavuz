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
        Schema::create('teacher_certifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('teacher_id')->constrained('teachers', 'user_id')->onDelete('cascade');
            $table->string('certification_type'); // diploma, certificate, license, etc.
            $table->string('institution');
            $table->string('certificate_number')->nullable();
            $table->date('issue_date');
            $table->date('expiry_date')->nullable();
            $table->string('document_url')->nullable();
            $table->enum('status', ['pending', 'verified', 'rejected'])->default('pending');
            $table->text('admin_notes')->nullable();
            $table->foreignId('verified_by')->nullable()->constrained('users');
            $table->timestamp('verified_at')->nullable();
            $table->timestamps();
        });

        Schema::create('teacher_portfolios', function (Blueprint $table) {
            $table->id();
            $table->foreignId('teacher_id')->constrained('teachers', 'user_id')->onDelete('cascade');
            $table->string('title');
            $table->text('description');
            $table->string('file_url');
            $table->string('file_type'); // image, video, pdf, etc.
            $table->boolean('is_featured')->default(false);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('teacher_videos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('teacher_id')->constrained('teachers', 'user_id')->onDelete('cascade');
            $table->string('title');
            $table->text('description');
            $table->string('video_url');
            $table->string('thumbnail_url')->nullable();
            $table->integer('duration')->nullable(); // in seconds
            $table->boolean('is_intro_video')->default(false);
            $table->integer('views_count')->default(0);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('teacher_certifications');
        Schema::dropIfExists('teacher_portfolios');
        Schema::dropIfExists('teacher_videos');
    }
};