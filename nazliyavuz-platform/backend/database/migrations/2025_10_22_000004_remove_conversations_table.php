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
        // Drop conversations table completely as it's not being used
        // Only chats table is used for chat functionality
        Schema::dropIfExists('conversations');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Recreate conversations table if needed (not recommended)
        Schema::create('conversations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user1_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('user2_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('reservation_id')->nullable()->constrained()->onDelete('cascade');
            $table->timestamp('last_message_at')->nullable();
            $table->text('last_message')->nullable();
            $table->boolean('user1_deleted')->default(false);
            $table->boolean('user2_deleted')->default(false);
            $table->timestamps();
            
            $table->unique(['user1_id', 'user2_id']);
            $table->index(['user1_id', 'last_message_at']);
            $table->index(['user2_id', 'last_message_at']);
        });
    }
};
