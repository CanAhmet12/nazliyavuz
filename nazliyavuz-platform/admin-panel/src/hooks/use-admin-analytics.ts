import { useQuery } from "@tanstack/react-query";
import {
  fetchAdminAnalytics,
  type AdminAnalyticsResponse,
} from "@/lib/api/analytics";

export const adminAnalyticsQueryKey = ["admin", "analytics"];

export function useAdminAnalytics() {
  return useQuery<AdminAnalyticsResponse>({
    queryKey: adminAnalyticsQueryKey,
    queryFn: fetchAdminAnalytics,
    staleTime: 60 * 1000,
  });
}

