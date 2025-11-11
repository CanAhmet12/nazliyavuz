import { useQuery } from "@tanstack/react-query";
import { fetchExperiments, type ExperimentsResponse } from "@/lib/api/experiments";

export const experimentsQueryKey = ["admin", "experiments"];

export function useExperiments() {
  return useQuery<ExperimentsResponse>({
    queryKey: experimentsQueryKey,
    queryFn: fetchExperiments,
    staleTime: 30 * 1000,
  });
}

