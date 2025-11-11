import { useQuery } from "@tanstack/react-query";
import {
  fetchNotificationAnalytics,
  type NotificationAnalyticsResponse,
} from "@/lib/api/admin-notifications";

const analyticsQueryKey = ["admin", "notifications", "analytics"];

export function useNotificationAnalytics() {
  return useQuery<NotificationAnalyticsResponse>({
    queryKey: analyticsQueryKey,
    queryFn: fetchNotificationAnalytics,
    staleTime: 60 * 1000,
  });
}

