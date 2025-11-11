import { useQuery } from "@tanstack/react-query";
import {
  fetchFinanceForecast,
  type FinanceForecastResponse,
} from "@/lib/api/finance";

export const financeForecastKey = ["admin", "finance", "forecast"];

export function useFinanceForecast(params?: { historyDays?: number; forecastDays?: number }) {
  return useQuery<FinanceForecastResponse>({
    queryKey: [...financeForecastKey, params?.historyDays ?? 120, params?.forecastDays ?? 45],
    queryFn: () => fetchFinanceForecast(params),
    staleTime: 60 * 1000,
  });
}

