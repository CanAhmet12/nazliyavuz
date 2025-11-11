"use client";

import { useAdminAnalytics } from "@/hooks/use-admin-analytics";
import { useUserSegmentation } from "@/hooks/use-user-segmentation";
import { useTeacherBenchmark } from "@/hooks/use-teacher-benchmark";
import { useFinanceOverview } from "@/hooks/use-finance-overview";
import { useFinanceForecast } from "@/hooks/use-finance-forecast";
import { UserGrowth } from "@/components/admin/analytics/user-growth";
import { ReservationTrend } from "@/components/admin/analytics/reservation-trend";
import { CategoryPopularity } from "@/components/admin/analytics/category-popularity";
import { TeacherPerformance } from "@/components/admin/analytics/teacher-performance";
import { UserSegmentationPanel } from "@/components/admin/analytics/user-segmentation";
import { TeacherBenchmarkPanel } from "@/components/admin/analytics/teacher-benchmark";
import { FinanceAlerts } from "@/components/admin/finance/finance-alerts";
import { SummaryCards } from "@/components/admin/finance/summary-cards";
import { RevenueForecast } from "@/components/admin/finance/revenue-forecast";
import { ExperimentsPanel } from "@/components/admin/analytics/experiments-panel";
import { Skeleton } from "@/components/ui/skeleton";
import { AlertCircle, PiggyBank, Receipt, Wallet, Inbox } from "lucide-react";

export default function AnalyticsPage() {
  const { data, isLoading, error, refetch } = useAdminAnalytics();
  const { data: financeData, isLoading: isFinanceLoading } = useFinanceOverview();
  const {
    data: forecastData,
    isLoading: isForecastLoading,
    isError: isForecastError,
  } = useFinanceForecast();
  const {
    data: segmentationData,
    isLoading: isSegmentationLoading,
    error: segmentationError,
    refetch: refetchSegmentation,
  } = useUserSegmentation();
  const {
    data: benchmarkData,
    isLoading: isBenchmarkLoading,
    error: benchmarkError,
    refetch: refetchBenchmark,
  } = useTeacherBenchmark();

  if (isLoading) {
    return <AnalyticsSkeleton />;
  }

  if (error || !data?.analytics) {
    return (
      <div className="space-y-4 rounded-2xl border border-rose-500/40 bg-rose-500/10 p-6 text-sm text-rose-200">
        <div className="flex items-center gap-2">
          <AlertCircle className="h-4 w-4" />
          Analitik verileri yüklenirken bir hata oluştu.
        </div>
        <button
          type="button"
          className="rounded-full border border-rose-400/50 px-3 py-1 text-xs text-rose-100 transition-colors hover:bg-rose-500/20"
          onClick={() => refetch()}
        >
          Tekrar dene
        </button>
      </div>
    );
  }

  const analytics = data.analytics;

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-100">
          Analitik & Eğilimler
        </h2>
        <p className="text-sm text-slate-400">
          Kullanıcı büyümesi, rezervasyon aktiviteleri ve performans metrikleri.
        </p>
      </div>

      <UserGrowth data={analytics.user_growth} />

      <div className="grid gap-4 lg:grid-cols-2">
        <ReservationTrend data={analytics.reservation_trends} />
        <CategoryPopularity data={analytics.category_popularity} />
      </div>

      <TeacherPerformance data={analytics.teacher_performance} />

      {isFinanceLoading || !financeData ? (
        <FinanceSkeleton />
      ) : (
        <FinanceOverviewSection overview={financeData} />
      )}

      {isForecastError ? null : isForecastLoading || !forecastData ? (
        <ForecastSkeleton />
      ) : (
        <RevenueForecast data={forecastData} />
      )}

      {segmentationError ? (
        <div className="space-y-4 rounded-2xl border border-amber-500/40 bg-amber-500/10 p-6 text-xs text-amber-100">
          <div className="flex items-center gap-2">
            <AlertCircle className="h-4 w-4" />
            Kullanıcı segmentasyonu verileri yüklenemedi.
          </div>
          <button
            type="button"
            className="rounded-full border border-amber-400/50 px-3 py-1 text-xs transition-colors hover:bg-amber-500/20"
            onClick={() => refetchSegmentation()}
          >
            Tekrar dene
          </button>
        </div>
      ) : isSegmentationLoading || !segmentationData?.segmentation ? (
        <SegmentationSkeleton />
      ) : (
        <UserSegmentationPanel data={segmentationData.segmentation} />
      )}

      {benchmarkError ? (
        <div className="space-y-4 rounded-2xl border border-rose-500/40 bg-rose-500/10 p-6 text-xs text-rose-100">
          <div className="flex items-center gap-2">
            <AlertCircle className="h-4 w-4" />
            Öğretmen benchmark verileri yüklenemedi.
          </div>
          <button
            type="button"
            className="rounded-full border border-rose-400/50 px-3 py-1 text-xs transition-colors hover:bg-rose-500/20"
            onClick={() => refetchBenchmark()}
          >
            Tekrar dene
          </button>
        </div>
      ) : isBenchmarkLoading || !benchmarkData?.benchmark ? (
        <BenchmarkSkeleton />
      ) : (
        <TeacherBenchmarkPanel data={benchmarkData.benchmark} />
      )}

      <ExperimentsPanel />
    </div>
  );
}

function AnalyticsSkeleton() {
  return (
    <div className="space-y-6">
      <Skeleton className="h-6 w-40" />
      <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
      <div className="grid gap-4 lg:grid-cols-2">
        <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
        <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
      </div>
      <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
    </div>
  );
}

function SegmentationSkeleton() {
  return (
    <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <Skeleton className="h-5 w-64" />
      <Skeleton className="h-24 rounded-xl border border-slate-800/70 bg-slate-900/60" />
      <div className="grid gap-3 md:grid-cols-2">
        <Skeleton className="h-40 rounded-xl border border-slate-800/70 bg-slate-900/60" />
        <Skeleton className="h-40 rounded-xl border border-slate-800/70 bg-slate-900/60" />
      </div>
    </div>
  );
}

function BenchmarkSkeleton() {
  return (
    <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <Skeleton className="h-5 w-72" />
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, index) => (
          <Skeleton
            key={index}
            className="h-24 rounded-xl border border-slate-800/70 bg-slate-900/60"
          />
        ))}
      </div>
      <Skeleton className="h-64 rounded-xl border border-slate-800/70 bg-slate-900/60" />
    </div>
  );
}

function FinanceSkeleton() {
  return (
    <div className="space-y-6 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <Skeleton className="h-5 w-64" />
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, index) => (
          <Skeleton
            key={index}
            className="h-20 rounded-xl border border-slate-800/70 bg-slate-900/60"
          />
        ))}
      </div>
    </div>
  );
}

function FinanceOverviewSection({
  overview,
}: {
  overview: NonNullable<ReturnType<typeof useFinanceOverview>["data"]>;
}) {
  const { totals, alerts } = overview;

  const metrics = [
    {
      label: "Toplam Gelir",
      value: formatCurrency(totals.totalRevenue, totals.currency),
      subLabel: "Tüm zamanlar",
      icon: <Wallet className="h-4 w-4" />,
    },
    {
      label: "Aylık Gelir",
      value: formatCurrency(totals.monthlyRevenue, totals.currency),
      subLabel: "Son 30 gün",
      icon: <Receipt className="h-4 w-4" />,
    },
    {
      label: "Bekleyen Ödemeler",
      value: formatCurrency(totals.outstandingPayments, totals.currency),
      subLabel: "Tahsil edilmesi gereken",
      icon: <Inbox className="h-4 w-4" />,
    },
    {
      label: "Payout Bakiyesi",
      value: formatCurrency(totals.payoutBalance, totals.currency),
      subLabel: "Öğretmenlere aktarılacak",
      icon: <PiggyBank className="h-4 w-4" />,
    },
  ];

  return (
    <section className="space-y-4">
      <FinanceAlerts alerts={alerts} />
      <SummaryCards metrics={metrics} />
    </section>
  );
}

function ForecastSkeleton() {
  return (
    <div className="h-64 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <Skeleton className="h-6 w-48" />
      <Skeleton className="mt-4 h-36 rounded-xl border border-slate-900/70 bg-slate-900/50" />
    </div>
  );
}

function formatCurrency(value: number, currency: string) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(value);
}

