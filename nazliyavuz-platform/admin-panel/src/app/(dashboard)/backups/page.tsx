"use client";

import { useState } from "react";
import { useBackups, useBackupStats } from "@/hooks/use-backups";
import {
  createDatabaseBackup,
  createFilesystemBackup,
  createFullBackup,
  deleteBackup,
  restoreBackup,
  type BackupItem,
} from "@/lib/api/backups";
import { BackupStats } from "@/components/admin/backups/backup-stats";
import { BackupAutomationStatusCard } from "@/components/admin/backups/backup-automation-status";
import { BackupsTable } from "@/components/admin/backups/backups-table";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { AlertCircle, Database, Server, HardDrive } from "lucide-react";
import toast from "react-hot-toast";
import { useQueryClient } from "@tanstack/react-query";
import { backupsQueryKey, backupStatsQueryKey } from "@/hooks/use-backups";

export default function BackupsPage() {
  const queryClient = useQueryClient();
  const { data: backups, isLoading: backupsLoading, error } = useBackups();
  const { data: stats, isLoading: statsLoading } = useBackupStats();
  const [isProcessing, setIsProcessing] = useState(false);

  const handleAction = async (
    action: () => Promise<unknown>,
    successMessage: string,
  ) => {
    try {
      setIsProcessing(true);
      const response = (await action()) as { success?: boolean; message?: string };
      if (response?.success === false) {
        throw new Error(response?.message ?? "İşlem başarısız oldu.");
      }
      toast.success(successMessage);
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: backupsQueryKey }),
        queryClient.invalidateQueries({ queryKey: backupStatsQueryKey }),
      ]);
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "İşlem sırasında hata oluştu.";
      toast.error(message);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleRestore = (backup: BackupItem) => {
    handleAction(
      () => restoreBackup(backup.filename),
      `${backup.filename} geri yüklendi.`,
    );
  };

  const handleDelete = (backup: BackupItem) => {
    if (!confirm(`${backup.filename} yedeğini silmek istediğinize emin misiniz?`)) {
      return;
    }
    handleAction(
      () => deleteBackup(backup.filename),
      `${backup.filename} yedeği silindi.`,
    );
  };

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-100">Yedek Yönetimi</h2>
        <p className="text-sm text-slate-400">
          Veritabanı ve dosya sistemi yedeklerini yönetin, geri yükleme veya silme işlemleri yapın.
        </p>
      </div>

      <div className="flex flex-wrap gap-3">
        <Button
          className="gap-2 bg-slate-900/80 hover:bg-slate-900"
          onClick={() =>
            handleAction(createDatabaseBackup, "Veritabanı yedeği oluşturuldu.")
          }
          disabled={isProcessing}
        >
          <Database className="h-4 w-4" />
          Veritabanı Yedeği
        </Button>
        <Button
          className="gap-2 bg-slate-900/80 hover:bg-slate-900"
          onClick={() =>
            handleAction(
              createFilesystemBackup,
              "Dosya sistemi yedeği oluşturuldu.",
            )
          }
          disabled={isProcessing}
        >
          <Server className="h-4 w-4" />
          Dosya Sistemi Yedeği
        </Button>
        <Button
          className="gap-2 bg-slate-900/80 hover:bg-slate-900"
          onClick={() =>
            handleAction(createFullBackup, "Tam sistem yedeği oluşturuldu.")
          }
          disabled={isProcessing}
        >
          <HardDrive className="h-4 w-4" />
          Tam Yedek
        </Button>
      </div>

      {error && (
        <div className="flex items-center gap-3 rounded-xl border border-rose-500/40 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
          <AlertCircle className="h-4 w-4" />
          Yedekler yüklenirken bir hata oluştu. Lütfen tekrar deneyin.
        </div>
      )}

      {statsLoading ? (
        <Skeleton className="h-40 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
      ) : stats ? (
        <>
          <BackupAutomationStatusCard automation={stats.automation} />
          <BackupStats
            totalBackups={stats.total_backups}
            totalSizeFormatted={stats.total_size_formatted}
            newestBackup={stats.newest_backup}
            oldestBackup={stats.oldest_backup}
            backupsByType={stats.backups_by_type}
          />
        </>
      ) : null}

      {backupsLoading ? (
        <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
      ) : (
        <BackupsTable
          backups={backups ?? []}
          onRestore={handleRestore}
          onDelete={handleDelete}
          isProcessing={isProcessing}
        />
      )}
    </div>
  );
}

