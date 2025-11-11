import { apiClient } from "@/lib/api/client";

export type AuditLog = {
  id: number;
  user_id: number | null;
  user: {
    id: number;
    name: string;
    email: string;
  } | null;
  action: string;
  description?: string | null;
  severity: "info" | "warning" | "error" | "critical" | string;
  target_type?: string | null;
  target_id?: number | null;
  meta?: Record<string, unknown> | null;
  ip_address?: string | null;
  user_agent?: string | null;
  created_at: string;
};

export type AuditLogsResponse = {
  success: boolean;
  logs: AuditLog[];
  pagination: {
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
  };
  filters?: {
    actions?: string[];
    target_types?: string[];
  };
};

export type AuditLogsFilters = {
  action?: string;
  user_id?: number;
  page?: number;
  per_page?: number;
  query?: string;
  severity?: string;
  target_type?: string;
  target_id?: number;
  from?: string;
  to?: string;
  sort?: string;
};

export async function fetchAuditLogs(
  filters: AuditLogsFilters = {},
): Promise<AuditLogsResponse> {
  const { data } = await apiClient.get<AuditLogsResponse>("/admin/audit-logs", {
    params: filters,
  });
  return data;
}

