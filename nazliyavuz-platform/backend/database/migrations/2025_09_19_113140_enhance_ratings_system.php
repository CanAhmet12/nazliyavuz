<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Enhance existing ratings table
        Schema::table('ratings', function (Blueprint $table) {
            $table->json('detailed_ratings')->nullable();
            $table->json('media_urls')->nullable();
            $table->boolean('is_anonymous')->default(false);
            $table->boolean('is_verified')->default(false);
            $table->timestamp('verified_at')->nullable();
            $table->integer('helpful_count')->default(0);
            $table->integer('report_count')->default(0);
            $table->enum('status', ['pending', 'approved', 'rejected'])->default('approved');
        });

        // Create rating categories table
        Schema::create('rating_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug');
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        // Create rating helpfulness table
        Schema::create('rating_helpfulness', function (Blueprint $table) {
            $table->id();
            $table->foreignId('rating_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->boolean('is_helpful');
            $table->timestamps();
            
            $table->unique(['rating_id', 'user_id']);
        });

        // Create rating reports table
        Schema::create('rating_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('rating_id')->constrained()->onDelete('cascade');
            $table->foreignId('reported_by')->constrained('users')->onDelete('cascade');
            $table->enum('reason', ['spam', 'inappropriate', 'fake', 'offensive', 'other']);
            $table->text('description')->nullable();
            $table->enum('status', ['pending', 'reviewed', 'resolved'])->default('pending');
            $table->foreignId('reviewed_by')->nullable()->constrained('users');
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();
        });

        // Create teacher feedback table
        Schema::create('teacher_feedback', function (Blueprint $table) {
            $table->id();
            $table->foreignId('teacher_id')->constrained('teachers', 'user_id')->onDelete('cascade');
            $table->foreignId('student_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('reservation_id')->constrained()->onDelete('cascade');
            $table->text('feedback');
            $table->enum('type', ['positive', 'constructive', 'suggestion']);
            $table->boolean('is_anonymous')->default(false);
            $table->boolean('is_public')->default(false);
            $table->timestamps();
        });

        // Insert default rating categories
        DB::table('rating_categories')->insert([
            [
                'name' => 'İletişim',
                'slug' => 'communication',
                'description' => 'Öğretmenin iletişim becerileri',
                'sort_order' => 1,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'Bilgi Seviyesi',
                'slug' => 'knowledge',
                'description' => 'Öğretmenin konu bilgisi',
                'sort_order' => 2,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'Zamanında Olma',
                'slug' => 'punctuality',
                'description' => 'Derslere zamanında gelme',
                'sort_order' => 3,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'Öğretme Yöntemi',
                'slug' => 'teaching_method',
                'description' => 'Öğretme yaklaşımı ve yöntemi',
                'sort_order' => 4,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'Sabır',
                'slug' => 'patience',
                'description' => 'Öğrenciye karşı sabırlı olma',
                'sort_order' => 5,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('ratings', function (Blueprint $table) {
            $table->dropColumn([
                'detailed_ratings',
                'media_urls',
                'is_anonymous',
                'is_verified',
                'verified_at',
                'helpful_count',
                'report_count',
                'status'
            ]);
        });

        Schema::dropIfExists('rating_categories');
        Schema::dropIfExists('rating_helpfulness');
        Schema::dropIfExists('rating_reports');
        Schema::dropIfExists('teacher_feedback');
    }
};