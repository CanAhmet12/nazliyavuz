import { useQuery } from "@tanstack/react-query";
import {
  fetchFinanceOverview,
  type FinanceOverviewResponse,
} from "@/lib/api/finance";

export const financeOverviewKey = ["admin", "finance", "overview"];

export function useFinanceOverview() {
  return useQuery<FinanceOverviewResponse>({
    queryKey: financeOverviewKey,
    queryFn: fetchFinanceOverview,
    staleTime: 60 * 1000,
  });
}

