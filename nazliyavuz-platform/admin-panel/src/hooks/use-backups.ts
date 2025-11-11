import { useQuery } from "@tanstack/react-query";
import { listBackups, getBackupStats } from "@/lib/api/backups";

export const backupsQueryKey = ["admin", "backups", "list"];
export const backupStatsQueryKey = ["admin", "backups", "stats"];

export function useBackups() {
  return useQuery({
    queryKey: backupsQueryKey,
    queryFn: listBackups,
  });
}

export function useBackupStats() {
  return useQuery({
    queryKey: backupStatsQueryKey,
    queryFn: getBackupStats,
  });
}

