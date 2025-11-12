import { useQuery } from "@tanstack/react-query";
import {
  fetchAdminAnalytics,
  type AdminAnalyticsResponse,
} from "@/lib/api/analytics";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const adminAnalyticsQueryKey = ["admin", "analytics"];

export function useAdminAnalytics() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<AdminAnalyticsResponse>({
    queryKey: adminAnalyticsQueryKey,
    queryFn: fetchAdminAnalytics,
    staleTime: 60 * 1000,
    enabled: isEnabled,
  });
}

