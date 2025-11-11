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
        // Create message_threads table
        Schema::create('message_threads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('chat_id')->constrained('chats')->onDelete('cascade');
            $table->foreignId('root_message_id')->constrained('messages')->onDelete('cascade');
            $table->string('thread_title')->nullable();
            $table->boolean('is_active')->default(true);
            $table->integer('message_count')->default(0);
            $table->timestamp('last_activity_at')->nullable();
            $table->timestamps();
            
            $table->index(['chat_id', 'is_active']);
            $table->index(['root_message_id']);
        });

        // Create message_mentions table
        Schema::create('message_mentions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('message_id')->constrained('messages')->onDelete('cascade');
            $table->foreignId('mentioned_user_id')->constrained('users')->onDelete('cascade');
            $table->integer('position')->nullable();
            $table->timestamps();
            
            $table->unique(['message_id', 'mentioned_user_id']);
            $table->index(['mentioned_user_id', 'created_at']);
        });

        // Create message_encryption_keys table
        Schema::create('message_encryption_keys', function (Blueprint $table) {
            $table->id();
            $table->string('key_id')->unique();
            $table->foreignId('chat_id')->constrained('chats')->onDelete('cascade');
            $table->text('public_key');
            $table->text('private_key_encrypted');
            $table->boolean('is_active')->default(true);
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();
            
            $table->index(['chat_id', 'is_active']);
        });

        // Create message_translations table
        Schema::create('message_translations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('message_id')->constrained('messages')->onDelete('cascade');
            $table->string('language_code', 5);
            $table->text('translated_content');
            $table->string('translation_service')->nullable();
            $table->decimal('confidence_score', 3, 2)->nullable();
            $table->timestamps();
            
            $table->unique(['message_id', 'language_code']);
            $table->index(['language_code']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('message_translations');
        Schema::dropIfExists('message_encryption_keys');
        Schema::dropIfExists('message_mentions');
        Schema::dropIfExists('message_threads');
    }
};
