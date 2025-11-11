"use client";

import type { CSSProperties } from "react";
import { cn } from "@/lib/utils";

type RevenueTrendProps = {
  data: Array<{ month: string; value: number }>;
  currency: string;
};

export function RevenueTrend({ data, currency }: RevenueTrendProps) {
  const max = Math.max(...data.map((item) => item.value), 1);

  return (
    <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-semibold text-slate-100">
            Gelir Trend Analizi
          </p>
          <p className="text-xs text-slate-500">
            Son 6 aya ait tahsilat verileri
          </p>
        </div>
      </div>
      <div className="flex items-end gap-4">
        {data.map((item) => {
          const percentage = (item.value / max) * 100;
          return (
            <div key={item.month} className="flex flex-1 flex-col items-center">
              <div className="flex h-40 w-full flex-col justify-end rounded-xl bg-slate-900/60 p-2">
                <div
                  className={cn(
                    "relative w-full rounded-lg bg-gradient-to-t from-emerald-500/80 to-sky-400/60 shadow-[0_4px_24px_rgba(14,165,233,0.35)] transition-all",
                  )}
                  style={{ height: `${percentage || 5}%` } as CSSProperties}
                >
                  <span className="absolute -top-6 left-1/2 -translate-x-1/2 text-[11px] font-semibold text-slate-100">
                    {formatCurrency(item.value, currency)}
                  </span>
                </div>
              </div>
              <span className="mt-2 text-xs font-medium uppercase text-slate-500">
                {item.month}
              </span>
            </div>
          );
        })}
      </div>
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

