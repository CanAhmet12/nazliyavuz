import { apiClient } from "@/lib/api/client";

type RevenueTrendItem = {
  month: string;
  value: number;
};

type PaymentMethodDistribution = {
  method: string;
  percentage: number;
};

type RecentPayment = {
  id: string;
  student: string;
  teacher: string;
  amount: number;
  currency: string;
  status: "paid" | "refunded" | "failed";
  date: string;
};

type PendingPayout = {
  id: string;
  teacher: string;
  amount: number;
  currency: string;
  scheduledDate: string;
  status: "scheduled" | "processing";
};

type TopTeacherRevenue = {
  teacher: string;
  amount: number;
  currency: string;
  lessons: number;
};

export type FinanceAlert = {
  id: string;
  severity: "error" | "warning" | "info";
  title: string;
  message: string;
  affected?: number;
  meta?: Record<string, unknown>;
};

export type FinanceOverviewResponse = {
  success: boolean;
  totals: {
    totalRevenue: number;
    monthlyRevenue: number;
    outstandingPayments: number;
    payoutBalance: number;
    currency: string;
  };
  revenueTrend: RevenueTrendItem[];
  paymentMethods: PaymentMethodDistribution[];
  recentPayments: RecentPayment[];
  pendingPayouts: PendingPayout[];
  topTeachers: TopTeacherRevenue[];
  alerts: FinanceAlert[];
  generatedAt: string;
};

export async function fetchFinanceOverview(): Promise<FinanceOverviewResponse> {
  const { data } = await apiClient.get<FinanceOverviewResponse>(
    "/admin/finance/overview",
  );
  return data;
}

export type FinanceExportType = "payments" | "payouts";

export type FinanceExportParams = {
  startDate?: string;
  endDate?: string;
  status?: string;
};

export async function exportFinanceReport(
  type: FinanceExportType,
  params: FinanceExportParams = {},
): Promise<Blob> {
  const response = await apiClient.get(`/admin/finance/exports/${type}`, {
    params: {
      start_date: params.startDate,
      end_date: params.endDate,
      status: params.status,
    },
    responseType: "blob",
  });

  return response.data as Blob;
}

export type FinanceForecastPoint = {
  date: string;
  value: number;
  lower?: number;
  upper?: number;
};

export type FinanceForecastResponse = {
  success: boolean;
  currency: string;
  historyDays: number;
  forecastDays: number;
  actual: FinanceForecastPoint[];
  forecast: FinanceForecastPoint[];
  summary: {
    averageDailyRevenue: number;
    projected30DayRevenue: number;
    trendPercentage: number;
    slope: number;
  };
  generatedAt: string;
};

export async function fetchFinanceForecast(
  params?: { historyDays?: number; forecastDays?: number },
): Promise<FinanceForecastResponse> {
  const { data } = await apiClient.get<FinanceForecastResponse>("/admin/finance/forecast", {
    params: {
      history_days: params?.historyDays,
      forecast_days: params?.forecastDays,
    },
  });

  return data;
}

