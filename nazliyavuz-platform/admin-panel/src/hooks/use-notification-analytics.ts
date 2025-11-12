import { useQuery } from "@tanstack/react-query";
import {
  fetchNotificationAnalytics,
  type NotificationAnalyticsResponse,
} from "@/lib/api/admin-notifications";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

const analyticsQueryKey = ["admin", "notifications", "analytics"];

export function useNotificationAnalytics() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<NotificationAnalyticsResponse>({
    queryKey: analyticsQueryKey,
    queryFn: fetchNotificationAnalytics,
    staleTime: 60 * 1000,
    enabled: isEnabled,
  });
}

