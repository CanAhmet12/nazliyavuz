import { useQuery } from "@tanstack/react-query";
import { fetchNotificationTemplateVariables, type NotificationTemplateVariablesResponse } from "@/lib/api/admin-notifications";

export const notificationTemplateVariablesQueryKey = ["admin", "notifications", "template-variables"];

export function useNotificationTemplateVariables() {
  return useQuery<NotificationTemplateVariablesResponse>({
    queryKey: notificationTemplateVariablesQueryKey,
    queryFn: fetchNotificationTemplateVariables,
    staleTime: 60_000,
  });
}

