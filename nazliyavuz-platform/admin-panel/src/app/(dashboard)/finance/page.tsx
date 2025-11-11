"use client";

import { useFinanceOverview } from "@/hooks/use-finance-overview";
import { SummaryCards } from "@/components/admin/finance/summary-cards";
import { RevenueTrend } from "@/components/admin/finance/revenue-trend";
import { PaymentMethods } from "@/components/admin/finance/payment-methods";
import { RecentPaymentsTable } from "@/components/admin/finance/recent-payments-table";
import { PendingPayouts } from "@/components/admin/finance/pending-payouts";
import { TopTeachers } from "@/components/admin/finance/top-teachers";
import { FinanceAlerts } from "@/components/admin/finance/finance-alerts";
import { FinanceExportActions } from "@/components/admin/finance/finance-export-actions";
import { RevenueForecast } from "@/components/admin/finance/revenue-forecast";
import { Skeleton } from "@/components/ui/skeleton";
import { PiggyBank, Receipt, Wallet, Inbox } from "lucide-react";
import { useFinanceForecast } from "@/hooks/use-finance-forecast";

export default function FinancePage() {
  const { data, isLoading } = useFinanceOverview();
  const {
    data: forecastData,
    isLoading: isForecastLoading,
    isError: isForecastError,
  } = useFinanceForecast();

  if (isLoading || !data) {
    return <FinanceSkeleton />;
  }

  const {
    totals,
    revenueTrend,
    paymentMethods,
    recentPayments,
    pendingPayouts,
    topTeachers,
    alerts,
    generatedAt,
  } = data;

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

  const generatedAtLabel = generatedAt
    ? new Intl.DateTimeFormat("tr-TR", {
        dateStyle: "medium",
        timeStyle: "short",
      }).format(new Date(generatedAt))
    : null;

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-100">Finans Paneli</h2>
        <p className="text-sm text-slate-400">
          Gelir, ödeme yöntemleri ve ücret dağılımlarını takip edin.
        </p>
        {generatedAtLabel ? (
          <p className="text-xs text-slate-500">Veriler {generatedAtLabel} itibarıyla güncel.</p>
        ) : null}
      </div>

      <FinanceAlerts alerts={alerts} />

      <FinanceExportActions />

      <SummaryCards metrics={metrics} />

      {!isForecastError && forecastData ? (
        <RevenueForecast data={forecastData} />
      ) : isForecastLoading ? (
        <ForecastSkeleton />
      ) : null}

      <div className="grid gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <RevenueTrend data={revenueTrend} currency={totals.currency} />
        </div>
        <PaymentMethods data={paymentMethods} />
      </div>

      <div className="grid gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <RecentPaymentsTable payments={recentPayments} />
        </div>
        <PendingPayouts payouts={pendingPayouts} />
      </div>

      <TopTeachers data={topTeachers} />
    </div>
  );
}

function FinanceSkeleton() {
  return (
    <div className="space-y-6">
      <Skeleton className="h-6 w-48" />
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, index) => (
          <Skeleton key={index} className="h-32 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
        ))}
      </div>
      <div className="grid gap-4 xl:grid-cols-3">
        <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60 xl:col-span-2" />
        <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
      </div>
      <div className="grid gap-4 xl:grid-cols-3">
        <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60 xl:col-span-2" />
        <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
      </div>
      <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
    </div>
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

