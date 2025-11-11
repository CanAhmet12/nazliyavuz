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
        // Add last_message tracking to chats (only if columns don't exist)
        if (!Schema::hasColumn('chats', 'last_message_id')) {
            Schema::table('chats', function (Blueprint $table) {
                $table->foreignId('last_message_id')->nullable()
                    ->after('user2_id')
                    ->constrained('messages')
                    ->onDelete('set null');
            });
        }
        
        if (!Schema::hasColumn('chats', 'last_message_at')) {
            Schema::table('chats', function (Blueprint $table) {
                $table->timestamp('last_message_at')->nullable()->after('last_message_id');
            });
        }
        
        if (!Schema::hasColumn('chats', 'user1_deleted')) {
            Schema::table('chats', function (Blueprint $table) {
                $table->boolean('user1_deleted')->default(false)->after('last_message_at');
            });
        }
        
        if (!Schema::hasColumn('chats', 'user2_deleted')) {
            Schema::table('chats', function (Blueprint $table) {
                $table->boolean('user2_deleted')->default(false)->after('user1_deleted');
            });
        }
        
        // Add indexes only if they don't exist
        try {
            Schema::table('chats', function (Blueprint $table) {
                $table->index(['user1_id', 'user1_deleted'], 'chats_user1_deleted_index');
                $table->index(['user2_id', 'user2_deleted'], 'chats_user2_deleted_index');
            });
        } catch (Exception $e) {
            // Indexes might already exist, ignore error
        }

        // Drop conversations table (not being used, duplicate of chats)
        Schema::dropIfExists('conversations');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Recreate conversations table
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

        // Remove fields from chats
        Schema::table('chats', function (Blueprint $table) {
            $table->dropForeign(['last_message_id']);
            $table->dropColumn([
                'last_message_id',
                'last_message_at',
                'user1_deleted',
                'user2_deleted',
            ]);
        });
    }
};

