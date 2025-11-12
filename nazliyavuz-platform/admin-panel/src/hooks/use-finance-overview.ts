import { useQuery } from "@tanstack/react-query";
import {
  fetchFinanceOverview,
  type FinanceOverviewResponse,
} from "@/lib/api/finance";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const financeOverviewKey = ["admin", "finance", "overview"];

export function useFinanceOverview() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<FinanceOverviewResponse>({
    queryKey: financeOverviewKey,
    queryFn: fetchFinanceOverview,
    staleTime: 60 * 1000,
    enabled: isEnabled,
  });
}

