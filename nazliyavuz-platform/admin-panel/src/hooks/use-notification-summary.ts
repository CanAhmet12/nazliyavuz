import { useQuery } from "@tanstack/react-query";
import {
  fetchNotificationSummary,
  type NotificationSummaryResponse,
} from "@/lib/api/admin-notifications";

const summaryQueryKey = ["admin", "notifications", "summary"];

export function useNotificationSummary() {
  return useQuery<NotificationSummaryResponse>({
    queryKey: summaryQueryKey,
    queryFn: fetchNotificationSummary,
    staleTime: 60 * 1000,
  });
}

