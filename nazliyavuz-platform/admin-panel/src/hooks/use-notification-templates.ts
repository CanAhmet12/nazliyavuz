import { useQuery } from "@tanstack/react-query";
import {
  fetchNotificationTemplates,
  type NotificationTemplatesResponse,
} from "@/lib/api/admin-notifications";

export const notificationTemplatesQueryKey = ["admin", "notifications", "templates"];

export function useNotificationTemplates() {
  return useQuery<NotificationTemplatesResponse>({
    queryKey: notificationTemplatesQueryKey,
    queryFn: fetchNotificationTemplates,
    staleTime: 30_000,
  });
}

