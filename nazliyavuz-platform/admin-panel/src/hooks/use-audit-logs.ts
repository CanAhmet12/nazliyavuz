import { useQuery } from "@tanstack/react-query";
import {
  fetchAuditLogs,
  type AuditLogsFilters,
  type AuditLogsResponse,
} from "@/lib/api/audit";

export const auditLogsQueryKey = ["admin", "audit-logs"];

export function useAuditLogs(filters: AuditLogsFilters) {
  return useQuery<AuditLogsResponse>({
    queryKey: [...auditLogsQueryKey, filters],
    queryFn: () => fetchAuditLogs(filters),
    keepPreviousData: true,
  });
}

