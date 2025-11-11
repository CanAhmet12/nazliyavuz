<?php

namespace App\Services;

use Carbon\Carbon;
use Cron\CronExpression;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class AdminBackupService
{
    protected string $backupPath = 'backups';
    protected int $maxBackups = 30; // Keep last 30 backups

    /**
     * Create database backup
     */
    public function createDatabaseBackup(array $context = []): array
    {
        try {
            $timestamp = now()->format('Y-m-d_H-i-s');
            $filename = "database_backup_{$timestamp}.sql";
            $filepath = storage_path("app/{$this->backupPath}/{$filename}");

            // Ensure backup directory exists
            if (!is_dir(dirname($filepath))) {
                mkdir(dirname($filepath), 0755, true);
            }

            // Get database configuration
            $config = config('database.connections.' . config('database.default'));
            $host = $config['host'];
            $port = $config['port'];
            $database = $config['database'];
            $username = $config['username'];
            $password = $config['password'];

            // Create mysqldump command
            $command = sprintf(
                'mysqldump --host=%s --port=%s --user=%s --password=%s %s > %s',
                escapeshellarg($host),
                escapeshellarg($port),
                escapeshellarg($username),
                escapeshellarg($password),
                escapeshellarg($database),
                escapeshellarg($filepath)
            );

            // Execute backup command
            $output = [];
            $returnCode = 0;
            exec($command, $output, $returnCode);

            if ($returnCode !== 0) {
                throw new \Exception('Database backup failed: ' . implode("\n", $output));
            }

            // Verify backup file exists and has content
            if (!file_exists($filepath) || filesize($filepath) === 0) {
                throw new \Exception('Backup file was not created or is empty');
            }

            // Store backup metadata
            $metadata = $this->buildBackupMetadata($filename, $filepath, 'database', $context);

            $this->storeBackupMetadata($metadata);

            // Cleanup old backups
            $this->cleanupOldBackups();

            Log::info('Database backup created successfully', $metadata);

            return [
                'success' => true,
                'message' => 'Database backup created successfully',
                'backup' => $metadata,
            ];

        } catch (\Exception $e) {
            Log::error('Database backup failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return [
                'success' => false,
                'message' => 'Database backup failed: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * Create file system backup
     */
    public function createFileSystemBackup(array $context = []): array
    {
        try {
            $timestamp = now()->format('Y-m-d_H-i-s');
            $filename = "filesystem_backup_{$timestamp}.tar.gz";
            $filepath = storage_path("app/{$this->backupPath}/{$filename}");

            // Ensure backup directory exists
            if (!is_dir(dirname($filepath))) {
                mkdir(dirname($filepath), 0755, true);
            }

            // Create tar.gz archive of storage directory
            $command = sprintf(
                'tar -czf %s -C %s .',
                escapeshellarg($filepath),
                escapeshellarg(storage_path('app'))
            );

            // Execute backup command
            $output = [];
            $returnCode = 0;
            exec($command, $output, $returnCode);

            if ($returnCode !== 0) {
                throw new \Exception('File system backup failed: ' . implode("\n", $output));
            }

            // Verify backup file exists and has content
            if (!file_exists($filepath) || filesize($filepath) === 0) {
                throw new \Exception('Backup file was not created or is empty');
            }

            // Store backup metadata
            $metadata = $this->buildBackupMetadata($filename, $filepath, 'filesystem', $context);

            $this->storeBackupMetadata($metadata);

            // Cleanup old backups
            $this->cleanupOldBackups();

            Log::info('File system backup created successfully', $metadata);

            return [
                'success' => true,
                'message' => 'File system backup created successfully',
                'backup' => $metadata,
            ];

        } catch (\Exception $e) {
            Log::error('File system backup failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return [
                'success' => false,
                'message' => 'File system backup failed: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * Create full system backup
     */
    public function createFullBackup(array $context = []): array
    {
        try {
            $timestamp = now()->format('Y-m-d_H-i-s');
            $filename = "full_backup_{$timestamp}.tar.gz";
            $filepath = storage_path("app/{$this->backupPath}/{$filename}");

            // Ensure backup directory exists
            if (!is_dir(dirname($filepath))) {
                mkdir(dirname($filepath), 0755, true);
            }

            // Create full backup including database and files
            $tempDir = storage_path("app/{$this->backupPath}/temp_{$timestamp}");
            mkdir($tempDir, 0755, true);

            // Export database to temp directory
            $dbFile = "{$tempDir}/database.sql";
            $this->exportDatabaseToFile($dbFile);

            // Copy important directories
            $this->copyDirectory(storage_path('app'), "{$tempDir}/storage");
            $this->copyDirectory(base_path('config'), "{$tempDir}/config");
            $this->copyDirectory(base_path('database'), "{$tempDir}/database");

            // Create tar.gz archive
            $command = sprintf(
                'tar -czf %s -C %s .',
                escapeshellarg($filepath),
                escapeshellarg($tempDir)
            );

            // Execute backup command
            $output = [];
            $returnCode = 0;
            exec($command, $output, $returnCode);

            if ($returnCode !== 0) {
                throw new \Exception('Full backup failed: ' . implode("\n", $output));
            }

            // Cleanup temp directory
            $this->removeDirectory($tempDir);

            // Verify backup file exists and has content
            if (!file_exists($filepath) || filesize($filepath) === 0) {
                throw new \Exception('Backup file was not created or is empty');
            }

            // Store backup metadata
            $metadata = $this->buildBackupMetadata($filename, $filepath, 'full', $context);

            $this->storeBackupMetadata($metadata);

            // Cleanup old backups
            $this->cleanupOldBackups();

            Log::info('Full backup created successfully', $metadata);

            return [
                'success' => true,
                'message' => 'Full backup created successfully',
                'backup' => $metadata,
            ];

        } catch (\Exception $e) {
            Log::error('Full backup failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return [
                'success' => false,
                'message' => 'Full backup failed: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * List all backups
     */
    public function listBackups(): array
    {
        $backupDir = storage_path("app/{$this->backupPath}");
        
        if (!is_dir($backupDir)) {
            return [];
        }

        $backups = [];
        $metadataIndex = $this->indexMetadataByFilename();
        $files = glob("{$backupDir}/*.{sql,tar.gz}", GLOB_BRACE);

        foreach ($files as $file) {
            $filename = basename($file);
            $meta = $metadataIndex[$filename] ?? [];
            $backups[] = [
                'filename' => $filename,
                'filepath' => $file,
                'size' => filesize($file),
                'created_at' => date('Y-m-d H:i:s', filemtime($file)),
                'type' => $this->getBackupType($file),
                'status' => $meta['status'] ?? 'completed',
                'source' => $meta['source'] ?? 'manual',
                'storage' => $meta['storage'] ?? 'local',
                'run_at' => $meta['run_at'] ?? ($meta['created_at'] ?? null),
            ];
        }

        // Sort by creation time (newest first)
        usort($backups, function ($a, $b) {
            return strtotime($b['created_at']) - strtotime($a['created_at']);
        });

        return $backups;
    }

    /**
     * Restore from backup
     */
    public function restoreFromBackup(string $filename, array $context = []): array
    {
        try {
            $filepath = storage_path("app/{$this->backupPath}/{$filename}");
            
            if (!file_exists($filepath)) {
                throw new \Exception('Backup file not found');
            }

            $type = $this->getBackupType($filepath);

            $result = match ($type) {
                'database' => $this->restoreDatabase($filepath),
                'filesystem', 'full' => $this->restoreFilesystem($filepath),
                default => throw new \Exception('Unknown backup type'),
            };

            $this->storeBackupMetadata($this->buildRestoreMetadata($filename, $type, 'completed', $context));

            return $result;

        } catch (\Exception $e) {
            Log::error('Backup restore failed', [
                'filename' => $filename,
                'error' => $e->getMessage(),
            ]);

            $this->storeBackupMetadata($this->buildRestoreMetadata($filename, $this->getBackupType($filename), 'failed', $context + [
                'message' => $e->getMessage(),
            ]));

            return [
                'success' => false,
                'message' => 'Backup restore failed: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * Delete backup
     */
    public function deleteBackup(string $filename): array
    {
        try {
            $filepath = storage_path("app/{$this->backupPath}/{$filename}");
            
            if (!file_exists($filepath)) {
                throw new \Exception('Backup file not found');
            }

            if (!unlink($filepath)) {
                throw new \Exception('Failed to delete backup file');
            }

            Log::info('Backup deleted successfully', ['filename' => $filename]);

            $metadata = $this->readMetadata();
            $metadata = array_filter($metadata, fn ($item) => ($item['filename'] ?? null) !== $filename);
            $this->writeMetadata(array_values($metadata));

            return [
                'success' => true,
                'message' => 'Backup deleted successfully',
            ];

        } catch (\Exception $e) {
            Log::error('Backup deletion failed', [
                'filename' => $filename,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => 'Backup deletion failed: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * Get backup statistics
     */
    public function getBackupStats(): array
    {
        $backups = $this->listBackups();
        $totalSize = array_sum(array_column($backups, 'size'));
        $metadata = $this->readMetadata();
        
        return [
            'total_backups' => count($backups),
            'total_size' => $totalSize,
            'total_size_formatted' => $this->formatBytes($totalSize),
            'oldest_backup' => !empty($backups) ? end($backups)['created_at'] : null,
            'newest_backup' => !empty($backups) ? $backups[0]['created_at'] : null,
            'backups_by_type' => $this->getBackupsByType($backups),
            'automation' => $this->getAutomationStatus($metadata),
        ];
    }

    /**
     * Export database to file
     */
    private function exportDatabaseToFile(string $filepath): void
    {
        $config = config('database.connections.' . config('database.default'));
        $host = $config['host'];
        $port = $config['port'];
        $database = $config['database'];
        $username = $config['username'];
        $password = $config['password'];

        $command = sprintf(
            'mysqldump --host=%s --port=%s --user=%s --password=%s %s > %s',
            escapeshellarg($host),
            escapeshellarg($port),
            escapeshellarg($username),
            escapeshellarg($password),
            escapeshellarg($database),
            escapeshellarg($filepath)
        );

        $output = [];
        $returnCode = 0;
        exec($command, $output, $returnCode);

        if ($returnCode !== 0) {
            throw new \Exception('Database export failed: ' . implode("\n", $output));
        }
    }

    /**
     * Restore database
     */
    private function restoreDatabase(string $filepath): array
    {
        $config = config('database.connections.' . config('database.default'));
        $host = $config['host'];
        $port = $config['port'];
        $database = $config['database'];
        $username = $config['username'];
        $password = $config['password'];

        $command = sprintf(
            'mysql --host=%s --port=%s --user=%s --password=%s %s < %s',
            escapeshellarg($host),
            escapeshellarg($port),
            escapeshellarg($username),
            escapeshellarg($password),
            escapeshellarg($database),
            escapeshellarg($filepath)
        );

        $output = [];
        $returnCode = 0;
        exec($command, $output, $returnCode);

        if ($returnCode !== 0) {
            throw new \Exception('Database restore failed: ' . implode("\n", $output));
        }

        return [
            'success' => true,
            'message' => 'Database restored successfully',
        ];
    }

    /**
     * Restore filesystem
     */
    private function restoreFilesystem(string $filepath): array
    {
        $command = sprintf(
            'tar -xzf %s -C %s',
            escapeshellarg($filepath),
            escapeshellarg(storage_path('app'))
        );

        $output = [];
        $returnCode = 0;
        exec($command, $output, $returnCode);

        if ($returnCode !== 0) {
            throw new \Exception('Filesystem restore failed: ' . implode("\n", $output));
        }

        return [
            'success' => true,
            'message' => 'Filesystem restored successfully',
        ];
    }

    /**
     * Copy directory recursively
     */
    private function copyDirectory(string $source, string $destination): void
    {
        if (!is_dir($source)) {
            return;
        }

        if (!is_dir($destination)) {
            mkdir($destination, 0755, true);
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($source, \RecursiveDirectoryIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::SELF_FIRST
        );

        foreach ($iterator as $item) {
            $target = $destination . DIRECTORY_SEPARATOR . $iterator->getSubPathName();
            
            if ($item->isDir()) {
                if (!is_dir($target)) {
                    mkdir($target, 0755, true);
                }
            } else {
                copy($item, $target);
            }
        }
    }

    /**
     * Remove directory recursively
     */
    private function removeDirectory(string $directory): void
    {
        if (!is_dir($directory)) {
            return;
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($directory, \RecursiveDirectoryIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::CHILD_FIRST
        );

        foreach ($iterator as $item) {
            if ($item->isDir()) {
                rmdir($item->getPathname());
            } else {
                unlink($item->getPathname());
            }
        }

        rmdir($directory);
    }

    /**
     * Get backup type from filename
     */
    private function getBackupType(string $filepath): string
    {
        $filename = basename($filepath);
        
        if (strpos($filename, 'database_backup_') === 0) {
            return 'database';
        } elseif (strpos($filename, 'filesystem_backup_') === 0) {
            return 'filesystem';
        } elseif (strpos($filename, 'full_backup_') === 0) {
            return 'full';
        }
        
        return 'unknown';
    }

    private function storeBackupMetadata(array $metadata): void
    {
        $metadata = $this->normalizeMetadata($metadata);
        $existingMetadata = $this->readMetadata();
        $existingMetadata[] = $metadata;

        $this->writeMetadata($existingMetadata);
    }

    /**
     * Cleanup old backups
     */
    private function cleanupOldBackups(): void
    {
        $backups = $this->listBackups();
        
        if (count($backups) > $this->maxBackups) {
            $backupsToDelete = array_slice($backups, $this->maxBackups);
            
            foreach ($backupsToDelete as $backup) {
                $this->deleteBackup($backup['filename']);
            }
        }
    }

    /**
     * Get backups by type
     */
    private function getBackupsByType(array $backups): array
    {
        $byType = [];
        
        foreach ($backups as $backup) {
            $type = $backup['type'];
            if (!isset($byType[$type])) {
                $byType[$type] = 0;
            }
            $byType[$type]++;
        }
        
        return $byType;
    }

    /**
     * Format bytes to human readable format
     */
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        
        $bytes /= pow(1024, $pow);
        
        return round($bytes, 2) . ' ' . $units[$pow];
    }
    private function buildBackupMetadata(string $filename, string $filepath, string $type, array $context = []): array
    {
        $now = now()->toISOString();
        return array_merge([
            'event' => 'backup',
            'filename' => $filename,
            'filepath' => $filepath,
            'size' => filesize($filepath),
            'type' => $type,
            'status' => 'completed',
            'source' => $context['source'] ?? 'manual',
            'initiated_by' => $context['initiated_by'] ?? null,
            'initiated_by_name' => $context['initiated_by_name'] ?? null,
            'trigger' => $context['trigger'] ?? 'admin_api',
            'storage' => $context['storage'] ?? config('backup.storage_disk', 'local'),
            'run_at' => $context['run_at'] ?? $now,
            'created_at' => $now,
            'duration_seconds' => $context['duration_seconds'] ?? null,
        ], $context['extra'] ?? []);
    }

    private function buildRestoreMetadata(string $filename, string $type, string $status, array $context = []): array
    {
        $now = now()->toISOString();

        return array_merge([
            'event' => 'restore',
            'filename' => $filename,
            'type' => $type,
            'status' => $status,
            'source' => $context['source'] ?? 'manual',
            'initiated_by' => $context['initiated_by'] ?? null,
            'initiated_by_name' => $context['initiated_by_name'] ?? null,
            'trigger' => $context['trigger'] ?? 'admin_api',
            'run_at' => $context['run_at'] ?? $now,
            'message' => $context['message'] ?? null,
        ], $context['extra'] ?? []);
    }

    public function recordAutomationEvent(array $metadata): void
    {
        $this->storeBackupMetadata($metadata);
    }

    private function readMetadata(): array
    {
        $metadataFile = $this->getMetadataFilePath();
        if (!file_exists($metadataFile)) {
            return [];
        }

        $decoded = json_decode(file_get_contents($metadataFile), true);
        return is_array($decoded) ? $decoded : [];
    }

    private function writeMetadata(array $metadata): void
    {
        $metadataFile = $this->getMetadataFilePath();
        if (!is_dir(dirname($metadataFile))) {
            mkdir(dirname($metadataFile), 0755, true);
        }

        file_put_contents($metadataFile, json_encode(array_values($metadata), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    }

    private function getMetadataFilePath(): string
    {
        return storage_path("app/{$this->backupPath}/metadata.json");
    }

    private function normalizeMetadata(array $metadata): array
    {
        $now = now()->toIso8601String();

        return array_merge([
            'event' => $metadata['event'] ?? 'backup',
            'status' => $metadata['status'] ?? 'completed',
            'source' => $metadata['source'] ?? 'manual',
            'run_at' => $metadata['run_at'] ?? $metadata['created_at'] ?? $now,
            'created_at' => $metadata['created_at'] ?? $now,
        ], $metadata);
    }

    private function indexMetadataByFilename(): array
    {
        $metadata = $this->readMetadata();
        $index = [];

        foreach ($metadata as $entry) {
            if (($entry['event'] ?? 'backup') === 'backup' && !empty($entry['filename'])) {
                $index[$entry['filename']] = $entry;
            }
        }

        return $index;
    }

    private function getAutomationStatus(array $metadata): array
    {
        $scheduleConfig = config('backup.schedule', []);

        $databaseLast = $this->findLatestEvent($metadata, fn ($entry) => ($entry['event'] ?? 'backup') === 'backup'
            && ($entry['type'] ?? null) === 'database'
            && ($entry['source'] ?? null) === 'scheduler');

        $filesystemLast = $this->findLatestEvent($metadata, fn ($entry) => ($entry['event'] ?? 'backup') === 'backup'
            && ($entry['type'] ?? null) === 'filesystem'
            && ($entry['source'] ?? null) === 'scheduler');

        $fullLast = $this->findLatestEvent($metadata, fn ($entry) => ($entry['event'] ?? 'backup') === 'backup'
            && ($entry['type'] ?? null) === 'full'
            && ($entry['source'] ?? null) === 'scheduler');

        $lastRestore = $this->findLatestEvent($metadata, fn ($entry) => ($entry['event'] ?? null) === 'restore');

        return [
            'schedule' => [
                'database' => $this->buildScheduleStatus($scheduleConfig['database'] ?? [], $databaseLast),
                'filesystem' => $this->buildScheduleStatus($scheduleConfig['filesystem'] ?? [], $filesystemLast),
                'full' => $this->buildScheduleStatus($scheduleConfig['full'] ?? [], $fullLast),
            ],
            'restore' => [
                'last_restore_at' => $lastRestore['run_at'] ?? null,
                'last_restore_status' => $lastRestore['status'] ?? null,
                'last_restore_file' => $lastRestore['filename'] ?? null,
                'initiated_by' => $lastRestore['initiated_by'] ?? null,
                'initiated_by_name' => $lastRestore['initiated_by_name'] ?? null,
                'message' => $lastRestore['message'] ?? null,
            ],
        ];
    }

    private function findLatestEvent(array $metadata, callable $predicate): array
    {
        $filtered = array_filter($metadata, $predicate);
        usort($filtered, fn ($a, $b) => strtotime($b['run_at'] ?? $b['created_at'] ?? '') <=> strtotime($a['run_at'] ?? $a['created_at'] ?? ''));

        return $filtered[0] ?? [];
    }

    private function buildScheduleStatus(array $config, array $lastEvent): array
    {
        $enabled = (bool) ($config['enabled'] ?? false);
        $cron = $config['cron'] ?? null;
        $nextRunAt = null;

        if ($enabled && $cron) {
            try {
                $expression = CronExpression::factory($cron);
                $nextRunAt = $expression->getNextRunDate()->format(DATE_ATOM);
            } catch (\Throwable $e) {
                Log::warning('Invalid backup cron expression', [
                    'cron' => $cron,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return [
            'enabled' => $enabled,
            'cron' => $cron,
            'next_run_at' => $nextRunAt,
            'last_run_at' => $lastEvent['run_at'] ?? null,
            'last_status' => $lastEvent['status'] ?? null,
            'last_file' => $lastEvent['filename'] ?? null,
            'storage' => $lastEvent['storage'] ?? config('backup.storage_disk', 'local'),
            'source' => $lastEvent['source'] ?? null,
            'duration_seconds' => $lastEvent['duration_seconds'] ?? null,
        ];
    }
}
