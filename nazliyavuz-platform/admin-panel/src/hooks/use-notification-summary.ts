import { useQuery } from "@tanstack/react-query";
import {
  fetchNotificationSummary,
  type NotificationSummaryResponse,
} from "@/lib/api/admin-notifications";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

const summaryQueryKey = ["admin", "notifications", "summary"];

export function useNotificationSummary() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<NotificationSummaryResponse>({
    queryKey: summaryQueryKey,
    queryFn: fetchNotificationSummary,
    staleTime: 60 * 1000,
    enabled: isEnabled,
  });
}

