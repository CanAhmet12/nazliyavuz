<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'last_activity_at')) {
                $table->timestamp('last_activity_at')->nullable()->after('last_login_at');
            }
        });

        Schema::table('notifications', function (Blueprint $table) {
            if (!Schema::hasColumn('notifications', 'title')) {
                $table->string('title')->nullable()->after('type');
            }

            if (!Schema::hasColumn('notifications', 'message')) {
                $table->text('message')->nullable()->after('title');
            }

            if (!Schema::hasColumn('notifications', 'data')) {
                $table->json('data')->nullable()->after('message');
            }

            if (!Schema::hasColumn('notifications', 'priority')) {
                $table->string('priority', 20)->default('normal')->after('data');
            }

            if (!Schema::hasColumn('notifications', 'action_url')) {
                $table->string('action_url')->nullable()->after('priority');
            }

            if (!Schema::hasColumn('notifications', 'action_text')) {
                $table->string('action_text')->nullable()->after('action_url');
            }
        });

        // Migrate existing payload data to the new data column if necessary
        if (Schema::hasColumn('notifications', 'payload')) {
            DB::table('notifications')
                ->select(['id', 'payload'])
                ->orderBy('id')
                ->chunkById(100, function ($notifications) {
                    foreach ($notifications as $notification) {
                        $data = $notification->payload;

                        if (is_string($data)) {
                            $decoded = json_decode($data, true);
                            $data = json_last_error() === JSON_ERROR_NONE ? $decoded : ['legacy_payload' => $data];
                        }

                        DB::table('notifications')
                            ->where('id', $notification->id)
                            ->update([
                                'data' => json_encode($data),
                                'priority' => 'normal',
                            ]);
                    }
                });
        }

        // Rename payload column after migrating data to avoid keeping duplicate information
        if (Schema::hasColumn('notifications', 'payload')) {
            Schema::table('notifications', function (Blueprint $table) {
                $table->dropColumn('payload');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('notifications', function (Blueprint $table) {
            if (!Schema::hasColumn('notifications', 'payload')) {
                $table->json('payload')->nullable();
            }
        });

        // Move data back into payload if it exists
        if (Schema::hasColumn('notifications', 'data')) {
            DB::table('notifications')
                ->select(['id', 'data'])
                ->orderBy('id')
                ->chunkById(100, function ($notifications) {
                    foreach ($notifications as $notification) {
                        $payload = $notification->data;

                        if (!is_string($payload)) {
                            $payload = json_encode($payload);
                        }

                        DB::table('notifications')
                            ->where('id', $notification->id)
                            ->update([
                                'payload' => $payload,
                            ]);
                    }
                });
        }

        Schema::table('notifications', function (Blueprint $table) {
            if (Schema::hasColumn('notifications', 'action_text')) {
                $table->dropColumn('action_text');
            }

            if (Schema::hasColumn('notifications', 'action_url')) {
                $table->dropColumn('action_url');
            }

            if (Schema::hasColumn('notifications', 'priority')) {
                $table->dropColumn('priority');
            }

            if (Schema::hasColumn('notifications', 'data')) {
                $table->dropColumn('data');
            }

            if (Schema::hasColumn('notifications', 'message')) {
                $table->dropColumn('message');
            }

            if (Schema::hasColumn('notifications', 'title')) {
                $table->dropColumn('title');
            }
        });

        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'last_activity_at')) {
                $table->dropColumn('last_activity_at');
            }
        });
    }
};

