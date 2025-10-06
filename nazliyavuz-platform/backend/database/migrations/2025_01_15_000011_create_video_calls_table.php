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
        Schema::create('video_calls', function (Blueprint $table) {
            $table->id();
            $table->string('call_id')->unique();
            $table->foreignId('caller_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('receiver_id')->constrained('users')->onDelete('cascade');
            $table->enum('call_type', ['video', 'audio'])->default('video');
            $table->string('subject')->nullable();
            $table->foreignId('reservation_id')->nullable()->constrained()->onDelete('set null');
            $table->enum('status', ['initiated', 'active', 'ended', 'rejected', 'missed'])->default('initiated');
            $table->timestamp('started_at')->nullable();
            $table->timestamp('answered_at')->nullable();
            $table->timestamp('ended_at')->nullable();
            $table->integer('duration_seconds')->nullable();
            $table->string('end_reason')->nullable();
            $table->json('call_quality_metrics')->nullable();
            $table->boolean('is_recorded')->default(false);
            $table->string('recording_url')->nullable();
            $table->boolean('screen_shared')->default(false);
            $table->json('metadata')->nullable();
            $table->timestamps();
            
            // Indexes for performance
            $table->index(['caller_id', 'status']);
            $table->index(['receiver_id', 'status']);
            $table->index(['call_type', 'status']);
            $table->index(['started_at']);
            $table->index(['reservation_id']);
        });

        Schema::create('video_call_participants', function (Blueprint $table) {
            $table->id();
            $table->foreignId('video_call_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->enum('role', ['caller', 'receiver'])->default('receiver');
            $table->enum('status', ['invited', 'active', 'left', 'disconnected'])->default('invited');
            $table->timestamp('joined_at')->nullable();
            $table->timestamp('left_at')->nullable();
            $table->boolean('is_muted')->default(false);
            $table->boolean('video_enabled')->default(true);
            $table->boolean('screen_sharing')->default(false);
            $table->json('connection_quality')->nullable();
            $table->timestamps();
            
            // Indexes for performance
            $table->index(['video_call_id', 'user_id']);
            $table->index(['user_id', 'status']);
            $table->index(['video_call_id', 'status']);
        });

        Schema::create('video_call_recordings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('video_call_id')->constrained()->onDelete('cascade');
            $table->string('recording_url');
            $table->string('recording_type')->default('video'); // video, audio
            $table->integer('duration_seconds');
            $table->string('file_size')->nullable();
            $table->string('file_format')->nullable();
            $table->boolean('is_processed')->default(false);
            $table->string('thumbnail_url')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();
            
            // Indexes for performance
            $table->index(['video_call_id']);
            $table->index(['recording_type']);
            $table->index(['is_processed']);
        });

        // Add availability column to users table
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'available_for_calls')) {
                $table->boolean('available_for_calls')->default(true)->after('is_active');
            }
        });

        // Add index for availability
        Schema::table('users', function (Blueprint $table) {
            if (!$this->indexExists('users', 'users_available_for_calls_index')) {
                $table->index(['available_for_calls'], 'users_available_for_calls_index');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('video_call_recordings');
        Schema::dropIfExists('video_call_participants');
        Schema::dropIfExists('video_calls');
        
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex('users_available_for_calls_index');
            $table->dropColumn('available_for_calls');
        });
    }

    /**
     * Check if index exists
     */
    private function indexExists($table, $indexName): bool
    {
        try {
            $indexes = DB::select("SHOW INDEX FROM {$table}");
            foreach ($indexes as $index) {
                if ($index->Key_name === $indexName) {
                    return true;
                }
            }
            return false;
        } catch (Exception $e) {
            return false;
        }
    }
};
