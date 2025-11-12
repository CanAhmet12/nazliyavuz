import { useQuery } from "@tanstack/react-query";
import {
  fetchUserSegmentation,
  type UserSegmentationResponse,
} from "@/lib/api/analytics";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const userSegmentationQueryKey = ["admin", "analytics", "user-segmentation"];

export function useUserSegmentation() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<UserSegmentationResponse>({
    queryKey: userSegmentationQueryKey,
    queryFn: fetchUserSegmentation,
    staleTime: 60 * 1000,
    enabled: isEnabled,
  });
}

