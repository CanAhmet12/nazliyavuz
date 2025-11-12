import { useQuery } from "@tanstack/react-query";
import { listBackups, getBackupStats } from "@/lib/api/backups";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const backupsQueryKey = ["admin", "backups", "list"];
export const backupStatsQueryKey = ["admin", "backups", "stats"];

export function useBackups() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery({
    queryKey: backupsQueryKey,
    queryFn: listBackups,
    enabled: isEnabled,
  });
}

export function useBackupStats() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery({
    queryKey: backupStatsQueryKey,
    queryFn: getBackupStats,
    enabled: isEnabled,
  });
}

