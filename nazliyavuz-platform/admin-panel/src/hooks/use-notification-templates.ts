import { useQuery } from "@tanstack/react-query";
import {
  fetchNotificationTemplates,
  type NotificationTemplatesResponse,
} from "@/lib/api/admin-notifications";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const notificationTemplatesQueryKey = ["admin", "notifications", "templates"];

export function useNotificationTemplates() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<NotificationTemplatesResponse>({
    queryKey: notificationTemplatesQueryKey,
    queryFn: fetchNotificationTemplates,
    staleTime: 30_000,
    enabled: isEnabled,
  });
}

