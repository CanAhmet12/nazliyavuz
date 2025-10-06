<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;
use Exception;

class BackupDatabaseCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'backup:database 
                            {--storage=local : Storage disk (local, s3)}
                            {--compress=true : Compress backup file}
                            {--retention=30 : Retention days}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Create database backup with compression and retention';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        try {
            $this->info('🗄️ Starting database backup...');

            $storage = $this->option('storage');
            $compress = $this->option('compress') === 'true';
            $retention = (int) $this->option('retention');

            // Create backup
            $backupPath = $this->createBackup($compress);
            
            // Upload to storage
            $this->uploadToStorage($backupPath, $storage);
            
            // Clean old backups
            $this->cleanOldBackups($retention, $storage);
            
            $this->info('✅ Database backup completed successfully!');
            
            return Command::SUCCESS;
            
        } catch (Exception $e) {
            $this->error('❌ Backup failed: ' . $e->getMessage());
            \Log::error('Database backup failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            
            return Command::FAILURE;
        }
    }

    /**
     * Create database backup
     */
    private function createBackup(bool $compress): string
    {
        $timestamp = Carbon::now()->format('Y-m-d_H-i-s');
        $filename = "backup_{$timestamp}.sql";
        $backupPath = storage_path("app/backups/{$filename}");

        // Ensure backup directory exists
        if (!file_exists(dirname($backupPath))) {
            mkdir(dirname($backupPath), 0755, true);
        }

        $this->info("📦 Creating backup: {$filename}");

        // Get database configuration
        $config = config('database.connections.' . config('database.default'));
        
        if ($config['driver'] === 'sqlite') {
            $this->backupSqlite($config, $backupPath);
        } else {
            $this->backupMysql($config, $backupPath);
        }

        // Compress if requested
        if ($compress) {
            $compressedPath = $this->compressBackup($backupPath);
            unlink($backupPath); // Remove uncompressed file
            return $compressedPath;
        }

        return $backupPath;
    }

    /**
     * Backup SQLite database
     */
    private function backupSqlite(array $config, string $backupPath): void
    {
        $sourcePath = $config['database'];
        
        if (!file_exists($sourcePath)) {
            throw new Exception("SQLite database file not found: {$sourcePath}");
        }

        if (!copy($sourcePath, $backupPath)) {
            throw new Exception("Failed to copy SQLite database");
        }

        $this->info("📋 SQLite database backed up successfully");
    }

    /**
     * Backup MySQL database
     */
    private function backupMysql(array $config, string $backupPath): void
    {
        $host = $config['host'];
        $port = $config['port'];
        $database = $config['database'];
        $username = $config['username'];
        $password = $config['password'];

        // Build mysqldump command
        $command = sprintf(
            'mysqldump --host=%s --port=%s --user=%s --password=%s --single-transaction --routines --triggers %s > %s',
            escapeshellarg($host),
            escapeshellarg($port),
            escapeshellarg($username),
            escapeshellarg($password),
            escapeshellarg($database),
            escapeshellarg($backupPath)
        );

        $this->info("🔄 Executing mysqldump...");
        
        $output = [];
        $returnCode = 0;
        exec($command, $output, $returnCode);

        if ($returnCode !== 0) {
            throw new Exception("mysqldump failed with return code: {$returnCode}");
        }

        if (!file_exists($backupPath) || filesize($backupPath) === 0) {
            throw new Exception("Backup file is empty or doesn't exist");
        }

        $this->info("📋 MySQL database backed up successfully");
    }

    /**
     * Compress backup file
     */
    private function compressBackup(string $backupPath): string
    {
        $compressedPath = $backupPath . '.gz';
        
        $this->info("🗜️ Compressing backup...");
        
        $fp_out = gzopen($compressedPath, 'wb9');
        $fp_in = fopen($backupPath, 'rb');
        
        if (!$fp_out || !$fp_in) {
            throw new Exception("Failed to open files for compression");
        }
        
        while (!feof($fp_in)) {
            gzwrite($fp_out, fread($fp_in, 1024 * 512));
        }
        
        fclose($fp_in);
        gzclose($fp_out);
        
        $originalSize = filesize($backupPath);
        $compressedSize = filesize($compressedPath);
        $ratio = round((1 - $compressedSize / $originalSize) * 100, 2);
        
        $this->info("📊 Compression ratio: {$ratio}% (Original: {$originalSize} bytes, Compressed: {$compressedSize} bytes)");
        
        return $compressedPath;
    }

    /**
     * Upload backup to storage
     */
    private function uploadToStorage(string $backupPath, string $storage): void
    {
        $filename = basename($backupPath);
        $storagePath = "backups/{$filename}";
        
        $this->info("☁️ Uploading to {$storage} storage...");
        
        $contents = file_get_contents($backupPath);
        Storage::disk($storage)->put($storagePath, $contents);
        
        $this->info("✅ Uploaded to {$storage}: {$storagePath}");
        
        // Remove local file after upload
        unlink($backupPath);
    }

    /**
     * Clean old backups
     */
    private function cleanOldBackups(int $retention, string $storage): void
    {
        $this->info("🧹 Cleaning backups older than {$retention} days...");
        
        $cutoffDate = Carbon::now()->subDays($retention);
        $deletedCount = 0;
        
        $files = Storage::disk($storage)->files('backups');
        
        foreach ($files as $file) {
            $lastModified = Carbon::createFromTimestamp(Storage::disk($storage)->lastModified($file));
            
            if ($lastModified->lt($cutoffDate)) {
                Storage::disk($storage)->delete($file);
                $deletedCount++;
                $this->info("🗑️ Deleted old backup: " . basename($file));
            }
        }
        
        $this->info("✅ Cleaned {$deletedCount} old backup files");
    }
}
