import { useQuery } from "@tanstack/react-query";
import {
  fetchScheduledNotifications,
  fetchScheduledNotificationLogs,
  type ScheduledNotificationsResponse,
  type ScheduledNotificationLog,
} from "@/lib/api/admin-notifications";

export const scheduledNotificationsQueryKey = ["admin", "notifications", "scheduled"];

export function useScheduledNotifications() {
  return useQuery<ScheduledNotificationsResponse>({
    queryKey: scheduledNotificationsQueryKey,
    queryFn: fetchScheduledNotifications,
    staleTime: 30_000,
  });
}

export function useScheduledNotificationLogs(notificationId: number) {
  return useQuery<{ success: boolean; logs: ScheduledNotificationLog[] }>({
    queryKey: [...scheduledNotificationsQueryKey, "logs", notificationId],
    queryFn: () => fetchScheduledNotificationLogs(notificationId),
    enabled: notificationId > 0,
    staleTime: 30_000,
  });
}

