import { useQuery } from "@tanstack/react-query";
import { fetchNotificationIntegrationStatus } from "@/lib/api/admin-notifications";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const notificationIntegrationStatusQueryKey = ["admin", "notification-integrations", "status"];

export function useNotificationIntegrationStatus() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery({
    queryKey: notificationIntegrationStatusQueryKey,
    queryFn: fetchNotificationIntegrationStatus,
    staleTime: 1000 * 60,
    enabled: isEnabled,
  });
}

