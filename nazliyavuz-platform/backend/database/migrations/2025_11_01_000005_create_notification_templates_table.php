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
        Schema::create('notification_templates', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->string('channel'); // email, push, sms, in_app
            $table->string('subject')->nullable(); // email subject
            $table->text('body');
            $table->json('variables')->nullable();
            $table->string('action_url')->nullable();
            $table->string('action_text')->nullable();
            $table->boolean('is_default')->default(false);
            $table->string('status')->default('draft'); // draft, published, archived
            $table->json('meta')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['channel', 'status']);
        });

        if (Schema::hasTable('scheduled_notifications')) {
            Schema::table('scheduled_notifications', function (Blueprint $table) {
                $table->foreign('template_id')
                    ->references('id')
                    ->on('notification_templates')
                    ->nullOnDelete();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('scheduled_notifications')) {
            Schema::table('scheduled_notifications', function (Blueprint $table) {
                $table->dropForeign(['template_id']);
            });
        }

        Schema::dropIfExists('notification_templates');
    }
};

