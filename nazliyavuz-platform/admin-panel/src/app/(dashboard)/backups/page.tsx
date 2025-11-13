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
    <div className="space-y-4 md:space-y-6">
      <div className="space-y-1.5 md:space-y-2">
        <h2 className="text-base font-semibold text-slate-100 md:text-lg">Yedek Yönetimi</h2>
        <p className="text-xs text-slate-400 md:text-sm">
          Veritabanı ve dosya sistemi yedeklerini yönetin, geri yükleme veya silme işlemleri yapın.
        </p>
      </div>

      <div className="flex flex-wrap gap-2 md:gap-3">
        <Button
          size="sm"
          className="min-h-[44px] flex-1 gap-2 bg-slate-900/80 active:scale-[0.98] hover:bg-slate-900 md:flex-initial md:min-h-0"
          onClick={() =>
            handleAction(createDatabaseBackup, "Veritabanı yedeği oluşturuldu.")
          }
          disabled={isProcessing}
        >
          <Database className="h-3.5 w-3.5 md:h-4 md:w-4" />
          <span className="text-xs md:text-sm">Veritabanı Yedeği</span>
        </Button>
        <Button
          size="sm"
          className="min-h-[44px] flex-1 gap-2 bg-slate-900/80 active:scale-[0.98] hover:bg-slate-900 md:flex-initial md:min-h-0"
          onClick={() =>
            handleAction(
              createFilesystemBackup,
              "Dosya sistemi yedeği oluşturuldu.",
            )
          }
          disabled={isProcessing}
        >
          <Server className="h-3.5 w-3.5 md:h-4 md:w-4" />
          Dosya Sistemi Yedeği
        </Button>
        <Button
          size="sm"
          className="min-h-[44px] flex-1 gap-2 bg-slate-900/80 active:scale-[0.98] hover:bg-slate-900 md:flex-initial md:min-h-0"
          onClick={() =>
            handleAction(createFullBackup, "Tam sistem yedeği oluşturuldu.")
          }
          disabled={isProcessing}
        >
          <HardDrive className="h-3.5 w-3.5 md:h-4 md:w-4" />
          <span className="text-xs md:text-sm">Tam Yedek</span>
        </Button>
      </div>

      {error && (
        <div className="flex items-center gap-2 rounded-xl border border-rose-500/40 bg-rose-500/10 px-3 py-2.5 text-xs text-rose-200 md:gap-3 md:px-4 md:py-3 md:text-sm">
          <AlertCircle className="h-3.5 w-3.5 shrink-0 md:h-4 md:w-4" />
          <span>Yedekler yüklenirken bir hata oluştu. Lütfen tekrar deneyin.</span>
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

