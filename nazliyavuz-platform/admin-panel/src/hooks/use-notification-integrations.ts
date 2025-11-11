import { useQuery } from "@tanstack/react-query";
import { fetchNotificationIntegrationStatus } from "@/lib/api/admin-notifications";

export const notificationIntegrationStatusQueryKey = ["admin", "notification-integrations", "status"];

export function useNotificationIntegrationStatus() {
  return useQuery({
    queryKey: notificationIntegrationStatusQueryKey,
    queryFn: fetchNotificationIntegrationStatus,
    staleTime: 1000 * 60,
  });
}

