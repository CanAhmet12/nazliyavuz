import { useQuery } from "@tanstack/react-query";
import {
  fetchNotificationHistory,
  type NotificationHistoryFilters,
  type NotificationHistoryResponse,
} from "@/lib/api/admin-notifications";

export const notificationHistoryKey = ["admin", "notifications", "history"];

export function useNotificationHistory(filters: NotificationHistoryFilters) {
  return useQuery<NotificationHistoryResponse>({
    queryKey: [...notificationHistoryKey, filters],
    queryFn: () => fetchNotificationHistory(filters),
    keepPreviousData: true,
  });
}

