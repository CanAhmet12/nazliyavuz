import { useQuery } from "@tanstack/react-query";
import {
  fetchUserSegmentation,
  type UserSegmentationResponse,
} from "@/lib/api/analytics";

export const userSegmentationQueryKey = ["admin", "analytics", "user-segmentation"];

export function useUserSegmentation() {
  return useQuery<UserSegmentationResponse>({
    queryKey: userSegmentationQueryKey,
    queryFn: fetchUserSegmentation,
    staleTime: 60 * 1000,
  });
}

