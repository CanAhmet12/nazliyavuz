import { useQuery } from "@tanstack/react-query";
import {
  fetchNotificationHistory,
  type NotificationHistoryFilters,
  type NotificationHistoryResponse,
} from "@/lib/api/admin-notifications";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const notificationHistoryKey = ["admin", "notifications", "history"];

export function useNotificationHistory(filters: NotificationHistoryFilters) {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<NotificationHistoryResponse>({
    queryKey: [...notificationHistoryKey, filters],
    queryFn: () => fetchNotificationHistory(filters),
    placeholderData: (previousData) => previousData,
    enabled: isEnabled,
  });
}

