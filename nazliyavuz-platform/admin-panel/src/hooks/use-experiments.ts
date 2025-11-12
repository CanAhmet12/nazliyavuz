import { useQuery } from "@tanstack/react-query";
import {
  fetchExperiments,
  type ExperimentsResponse,
} from "@/lib/api/experiments";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const experimentsQueryKey = ["admin", "experiments"];

export function useExperiments() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<ExperimentsResponse>({
    queryKey: experimentsQueryKey,
    queryFn: fetchExperiments,
    staleTime: 30 * 1000,
    enabled: isEnabled,
  });
}

