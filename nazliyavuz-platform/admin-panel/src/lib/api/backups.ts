import { apiClient } from "@/lib/api/client";

export type BackupItem = {
  filename: string;
  filepath?: string;
  size: number;
  created_at: string;
  type: "database" | "filesystem" | "full";
  status?: string;
  source?: string;
  storage?: string;
  run_at?: string | null;
};

export type BackupListResponse = {
  success: boolean;
  backups: BackupItem[];
};

export type BackupAutomationDetail = {
  enabled: boolean;
  cron?: string | null;
  next_run_at?: string | null;
  last_run_at?: string | null;
  last_status?: string | null;
  last_file?: string | null;
  storage?: string | null;
  duration_seconds?: number | null;
};

export type BackupAutomationStatus = {
  schedule: {
    database: BackupAutomationDetail;
    filesystem: BackupAutomationDetail;
    full: BackupAutomationDetail;
  };
  restore: {
    last_restore_at?: string | null;
    last_restore_status?: string | null;
    last_restore_file?: string | null;
    initiated_by?: number | null;
    initiated_by_name?: string | null;
    message?: string | null;
  };
};

export type BackupStats = {
  total_backups: number;
  total_size: number;
  total_size_formatted: string;
  oldest_backup: string | null;
  newest_backup: string | null;
  backups_by_type: Record<string, number>;
  automation: BackupAutomationStatus;
};

export type BackupStatsResponse = {
  success: boolean;
  stats: BackupStats;
};

export async function listBackups(): Promise<BackupItem[]> {
  const { data } = await apiClient.get<BackupListResponse>("/admin/backups");
  return data.backups ?? [];
}

export async function getBackupStats(): Promise<BackupStats> {
  const { data } = await apiClient.get<BackupStatsResponse>(
    "/admin/backups/stats",
  );
  return data.stats;
}

type CreateBackupResponse = {
  success: boolean;
  message: string;
  backup?: BackupItem;
};

export async function createDatabaseBackup(): Promise<CreateBackupResponse> {
  const { data } = await apiClient.post<CreateBackupResponse>(
    "/admin/backups/database",
  );
  return data;
}

export async function createFilesystemBackup(): Promise<CreateBackupResponse> {
  const { data } = await apiClient.post<CreateBackupResponse>(
    "/admin/backups/filesystem",
  );
  return data;
}

export async function createFullBackup(): Promise<CreateBackupResponse> {
  const { data } = await apiClient.post<CreateBackupResponse>(
    "/admin/backups/full",
  );
  return data;
}

type RestoreBackupResponse = {
  success: boolean;
  message: string;
};

export async function restoreBackup(filename: string): Promise<RestoreBackupResponse> {
  const { data } = await apiClient.post<RestoreBackupResponse>(
    "/admin/backups/restore",
    { filename },
  );
  return data;
}

type DeleteBackupResponse = {
  success: boolean;
  message: string;
};

export async function deleteBackup(filename: string): Promise<DeleteBackupResponse> {
  const { data } = await apiClient.delete<DeleteBackupResponse>(
    "/admin/backups/delete",
    { data: { filename } },
  );
  return data;
}

