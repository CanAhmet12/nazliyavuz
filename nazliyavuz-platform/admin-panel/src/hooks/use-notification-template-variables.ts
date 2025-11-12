import { useQuery } from "@tanstack/react-query";
import {
  fetchNotificationTemplateVariables,
  type NotificationTemplateVariablesResponse,
} from "@/lib/api/admin-notifications";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const notificationTemplateVariablesQueryKey = ["admin", "notifications", "template-variables"];

export function useNotificationTemplateVariables() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<NotificationTemplateVariablesResponse>({
    queryKey: notificationTemplateVariablesQueryKey,
    queryFn: fetchNotificationTemplateVariables,
    staleTime: 60_000,
    enabled: isEnabled,
  });
}

