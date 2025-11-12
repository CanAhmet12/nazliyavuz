import { useQuery } from "@tanstack/react-query";
import {
  fetchAuditLogs,
  type AuditLogsFilters,
  type AuditLogsResponse,
} from "@/lib/api/audit";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const auditLogsQueryKey = ["admin", "audit-logs"];

export function useAuditLogs(filters: AuditLogsFilters) {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<AuditLogsResponse>({
    queryKey: [...auditLogsQueryKey, filters],
    queryFn: () => fetchAuditLogs(filters),
    keepPreviousData: true,
    enabled: isEnabled,
  });
}

