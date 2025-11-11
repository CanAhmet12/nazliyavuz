import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import type { ReactNode } from "react";

type SummaryMetric = {
  label: string;
  value: string;
  trend?: string;
  icon: ReactNode;
  subLabel: string;
};

type SummaryCardsProps = {
  metrics: SummaryMetric[];
};

export function SummaryCards({ metrics }: SummaryCardsProps) {
  return (
    <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      {metrics.map((metric) => (
        <Card key={metric.label} className="relative overflow-hidden p-5">
          <div className="absolute inset-y-0 right-0 w-1/3 rounded-l-full bg-emerald-500/5" />
          <div className="relative z-10 space-y-3">
            <div className="flex items-center justify-between">
              <CardTitle className="text-xs uppercase tracking-wide text-slate-400">
                {metric.label}
              </CardTitle>
              <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-500/10 text-emerald-300">
                {metric.icon}
              </span>
            </div>
            <p className="text-2xl font-semibold text-slate-100">
              {metric.value}
            </p>
            <CardDescription className="text-xs text-slate-500">
              {metric.subLabel}
            </CardDescription>
            {metric.trend && (
              <span className={cn("text-xs font-medium text-emerald-300")}>
                {metric.trend}
              </span>
            )}
          </div>
        </Card>
      ))}
    </div>
  );
}

