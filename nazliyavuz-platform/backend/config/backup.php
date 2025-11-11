<?php

return [
    'storage_disk' => env('BACKUP_STORAGE_DISK', 'local'),
    'retention_days' => (int) env('BACKUP_RETENTION_DAYS', 30),

    'schedule' => [
        'database' => [
            'enabled' => (bool) env('BACKUP_DATABASE_ENABLED', true),
            'cron' => env('BACKUP_DATABASE_CRON', '0 3 * * *'), // every day at 03:00
        ],
        'filesystem' => [
            'enabled' => (bool) env('BACKUP_FILESYSTEM_ENABLED', false),
            'cron' => env('BACKUP_FILESYSTEM_CRON', '30 3 * * 0'), // Sundays at 03:30
        ],
        'full' => [
            'enabled' => (bool) env('BACKUP_FULL_ENABLED', false),
            'cron' => env('BACKUP_FULL_CRON', '0 4 1 * *'), // first day of month at 04:00
        ],
    ],
];

