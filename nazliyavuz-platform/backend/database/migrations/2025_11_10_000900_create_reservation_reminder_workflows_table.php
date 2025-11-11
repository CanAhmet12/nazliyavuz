<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('reservation_reminder_workflows', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->text('description')->nullable();
            $table->string('status')->default('active'); // draft, active, archived
            $table->json('target_statuses')->nullable();
            $table->json('target_roles')->nullable();
            $table->json('meta')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index('status');
        });

        Schema::table('reservation_reminder_settings', function (Blueprint $table) {
            $table->foreignId('workflow_id')
                ->nullable()
                ->after('id')
                ->constrained('reservation_reminder_workflows')
                ->cascadeOnDelete();
            $table->unsignedInteger('step_order')->default(1)->after('workflow_id');
            $table->enum('offset_direction', ['before', 'after'])->default('before')->after('offset_minutes');
            $table->unsignedInteger('send_window')->default(10)->after('offset_direction');
            $table->boolean('stop_on_success')->default(true)->after('enabled');
            $table->json('channels')->nullable()->after('send_email');
            $table->json('metadata')->nullable()->after('channels');
        });

        // Backfill existing settings into a default workflow and populate new columns.
        if (Schema::hasTable('reservation_reminder_settings')) {
            $existingSettings = DB::table('reservation_reminder_settings')
                ->orderBy('offset_minutes')
                ->get();

            if ($existingSettings->isNotEmpty()) {
                $defaultWorkflowId = DB::table('reservation_reminder_workflows')->insertGetId([
                    'name' => 'Varsayılan Hatırlatma Akışı',
                    'slug' => Str::slug('Varsayılan Hatırlatma Akışı'),
                    'description' => 'Otomatik hatırlatmalar için oluşturulan varsayılan akış.',
                    'status' => 'active',
                    'target_statuses' => json_encode(['accepted', 'in_progress']),
                    'target_roles' => json_encode(['student', 'teacher']),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);

                $order = 1;

                foreach ($existingSettings as $setting) {
                    $channels = [
                        'student' => [
                            'push' => [
                                'enabled' => (bool) ($setting->notify_student ?? false),
                                'template_id' => null,
                            ],
                            'email' => [
                                'enabled' => (bool) ($setting->send_email ?? false),
                                'template_id' => null,
                            ],
                            'sms' => [
                                'enabled' => false,
                                'template_id' => null,
                            ],
                        ],
                        'teacher' => [
                            'push' => [
                                'enabled' => (bool) ($setting->notify_teacher ?? false),
                                'template_id' => null,
                            ],
                            'email' => [
                                'enabled' => false,
                                'template_id' => null,
                            ],
                            'sms' => [
                                'enabled' => false,
                                'template_id' => null,
                            ],
                        ],
                    ];

                    DB::table('reservation_reminder_settings')
                        ->where('id', $setting->id)
                        ->update([
                            'workflow_id' => $defaultWorkflowId,
                            'step_order' => $order++,
                            'offset_direction' => 'before',
                            'send_window' => 10,
                            'stop_on_success' => true,
                            'channels' => json_encode($channels),
                            'metadata' => json_encode([]),
                        ]);
                }
            }
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('reservation_reminder_settings', function (Blueprint $table) {
            $table->dropForeign(['workflow_id']);
            $table->dropColumn([
                'workflow_id',
                'step_order',
                'offset_direction',
                'send_window',
                'stop_on_success',
                'channels',
                'metadata',
            ]);
        });

        Schema::dropIfExists('reservation_reminder_workflows');
    }
};

