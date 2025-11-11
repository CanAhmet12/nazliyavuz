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
        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('chat_id')->nullable()->constrained('chats')->onDelete('cascade');
            $table->foreignId('sender_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('receiver_id')->constrained('users')->onDelete('cascade');
            $table->unsignedBigInteger('reservation_id')->nullable();
            $table->text('content');
            $table->enum('message_type', ['text', 'image', 'file', 'audio', 'video'])->default('text');
            $table->string('file_url')->nullable();
            $table->string('file_name')->nullable();
            $table->integer('file_size')->nullable();
            $table->string('file_type')->nullable();
            $table->boolean('is_read')->default(false);
            $table->timestamp('read_at')->nullable();
            $table->boolean('is_deleted')->default(false);
            $table->timestamp('deleted_at')->nullable();
            
            // Advanced features
            $table->foreignId('parent_message_id')->nullable()->constrained('messages')->onDelete('cascade');
            $table->unsignedBigInteger('thread_id')->nullable();
            $table->json('mentions')->nullable();
            $table->foreignId('reply_to_message_id')->nullable()->constrained('messages')->onDelete('cascade');
            $table->foreignId('forwarded_from_message_id')->nullable()->constrained('messages')->onDelete('cascade');
            $table->foreignId('forwarded_from_user_id')->nullable()->constrained('users')->onDelete('cascade');
            $table->timestamp('forwarded_at')->nullable();
            $table->boolean('is_pinned')->default(false);
            $table->timestamp('pinned_at')->nullable();
            $table->foreignId('pinned_by')->nullable()->constrained('users')->onDelete('cascade');
            $table->text('original_content')->nullable();
            $table->timestamp('edited_at')->nullable();
            $table->integer('edit_count')->default(0);
            $table->json('translations')->nullable();
            $table->string('original_language')->nullable();
            $table->boolean('is_encrypted')->default(false);
            $table->string('encryption_key_id')->nullable();
            $table->string('message_status')->default('sent'); // sent, delivered, read
            $table->timestamp('delivered_at')->nullable();
            $table->json('metadata')->nullable();
            
            $table->timestamps();
            
            // Indexes for performance
            $table->index(['sender_id', 'receiver_id']);
            $table->index(['receiver_id', 'is_read']);
            $table->index(['reservation_id']);
            $table->index(['created_at']);
        });

        Schema::create('conversations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user1_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('user2_id')->constrained('users')->onDelete('cascade');
            $table->unsignedBigInteger('reservation_id')->nullable();
            $table->timestamp('last_message_at')->nullable();
            $table->text('last_message')->nullable();
            $table->boolean('user1_deleted')->default(false);
            $table->boolean('user2_deleted')->default(false);
            $table->timestamps();
            
            // Ensure unique conversation between two users
            $table->unique(['user1_id', 'user2_id']);
            $table->index(['user1_id', 'last_message_at']);
            $table->index(['user2_id', 'last_message_at']);
        });

        Schema::create('message_reactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('message_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('reaction'); // emoji or reaction type
            $table->timestamps();
            
            $table->unique(['message_id', 'user_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('message_reactions');
        Schema::dropIfExists('conversations');
        Schema::dropIfExists('messages');
    }
};