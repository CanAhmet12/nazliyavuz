"use client";

import type { FinanceForecastResponse } from "@/lib/api/finance";
import { cn } from "@/lib/utils";

type RevenueForecastProps = {
  data: FinanceForecastResponse;
};

const SVG_WIDTH = 640;
const SVG_HEIGHT = 220;

export function RevenueForecast({ data }: RevenueForecastProps) {
  const combined = [...data.actual, ...data.forecast];
  const maxValue = Math.max(...combined.map((item) => item.value), 1);

  const pointFor = (value: number) => {
    const clamped = Math.max(value, 0);
    const ratio = clamped / maxValue;
    const y = SVG_HEIGHT - ratio * (SVG_HEIGHT - 20) - 10;
    return Math.round(y * 100) / 100;
  };

  const step = combined.length > 1 ? SVG_WIDTH / (combined.length - 1) : SVG_WIDTH;

  const actualPoints = data.actual
    .map((item, index) => `${Math.round(index * step)},${pointFor(item.value)}`)
    .join(" ");

  const forecastPoints = data.forecast
    .map((item, index) => `${Math.round((data.actual.length - 1 + index) * step)},${pointFor(item.value)}`)
    .join(" ");

  const forecastUpper = data.forecast
    .map((item, index) => `${Math.round((data.actual.length - 1 + index) * step)},${pointFor(item.upper ?? item.value)}`)
    .join(" ");

  const forecastLower = data.forecast
    .map((item, index) => `${Math.round((data.actual.length - 1 + index) * step)},${pointFor(item.lower ?? item.value)}`)
    .join(" ");

  const summaryCards = [
    {
      label: "Günlük Ortalama",
      value: formatCurrency(data.summary.averageDailyRevenue, data.currency),
      description: `Son ${data.historyDays} gün ortalaması`,
    },
    {
      label: "Projeksiyon (30 gün)",
      value: formatCurrency(data.summary.projected30DayRevenue, data.currency),
      description: "Önümüzdeki 30 gün için tahmini toplam gelir",
    },
    {
      label: "Trend (Sonraki 7 gün)",
      value: `${data.summary.trendPercentage > 0 ? "+" : ""}${data.summary.trendPercentage.toFixed(2)}%`,
      description: "Kısa vadeli trend tahmini",
      className: data.summary.trendPercentage >= 0 ? "text-emerald-300" : "text-rose-300",
    },
  ];

  return (
    <section className="space-y-5 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-slate-100">Gelir Tahmini</p>
          <p className="text-xs text-slate-500">
            Tarihsel veriler baz alınarak oluşturulmuş gelir tahmini (son {data.historyDays} gün + {data.forecastDays} gün).
          </p>
        </div>
        <div className="flex flex-wrap gap-2 text-[11px] text-slate-400">
          <LegendItem className="bg-emerald-400/80 text-slate-900">Gerçekleşen</LegendItem>
          <LegendItem className="border border-sky-400/60 text-slate-200">Tahmin</LegendItem>
          <LegendItem className="border border-sky-300/40 bg-sky-300/10 text-slate-200">Tahmin aralığı</LegendItem>
        </div>
      </div>

      <div className="overflow-hidden rounded-2xl border border-slate-800/70 bg-slate-950/70">
        <svg width={SVG_WIDTH} height={SVG_HEIGHT} viewBox={`0 0 ${SVG_WIDTH} ${SVG_HEIGHT}`} className="w-full">
          {/* Confidence band */}
          <polyline
            points={`${forecastUpper} ${reversePoints(forecastLower)}`}
            fill="rgba(56, 189, 248, 0.12)"
            stroke="none"
          />
          {/* Forecast line */}
          <polyline
            points={forecastPoints}
            fill="none"
            stroke="rgba(56, 189, 248, 0.7)"
            strokeWidth={2}
            strokeDasharray="6 4"
          />
          {/* Actual line */}
          <polyline
            points={actualPoints}
            fill="none"
            stroke="rgba(16, 185, 129, 0.9)"
            strokeWidth={2.5}
          />
        </svg>
      </div>

      <div className="grid gap-3 md:grid-cols-3">
        {summaryCards.map((card) => (
          <div
            key={card.label}
            className="space-y-2 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4 text-sm text-slate-200"
          >
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{card.label}</p>
            <p className={cn("text-lg font-semibold", card.className)}>{card.value}</p>
            <p className="text-xs text-slate-400">{card.description}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

function LegendItem({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-3 py-1 font-medium",
        className ?? "border border-slate-600/60 bg-slate-900/70",
      )}
    >
      {children}
    </span>
  );
}

function reversePoints(points: string) {
  return points
    .split(" ")
    .filter(Boolean)
    .reverse()
    .join(" ");
}

function formatCurrency(value: number, currency: string) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(value);
}

