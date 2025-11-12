import { useQuery } from "@tanstack/react-query";
import {
  fetchScheduledNotifications,
  fetchScheduledNotificationLogs,
  type ScheduledNotificationsResponse,
  type ScheduledNotificationLog,
} from "@/lib/api/admin-notifications";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const scheduledNotificationsQueryKey = ["admin", "notifications", "scheduled"];

export function useScheduledNotifications() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<ScheduledNotificationsResponse>({
    queryKey: scheduledNotificationsQueryKey,
    queryFn: fetchScheduledNotifications,
    staleTime: 30_000,
    enabled: isEnabled,
  });
}

export function useScheduledNotificationLogs(notificationId: number) {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<{ success: boolean; logs: ScheduledNotificationLog[] }>({
    queryKey: [...scheduledNotificationsQueryKey, "logs", notificationId],
    queryFn: () => fetchScheduledNotificationLogs(notificationId),
    enabled: isEnabled && notificationId > 0,
    staleTime: 30_000,
  });
}

