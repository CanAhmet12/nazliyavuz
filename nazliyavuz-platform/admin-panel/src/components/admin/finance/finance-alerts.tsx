import type React from "react";
import { Badge } from "@/components/ui/badge";
import type { FinanceAlert } from "@/lib/api/finance";
import { AlertTriangle, Info, ShieldAlert } from "lucide-react";

type FinanceAlertsProps = {
  alerts: FinanceAlert[];
};

const severityConfig: Record<FinanceAlert["severity"], { icon: React.ReactElement; className: string }> = {
  error: {
    icon: <ShieldAlert className="h-4 w-4 text-rose-300" />,
    className: "border-rose-500/40 bg-rose-500/10",
  },
  warning: {
    icon: <AlertTriangle className="h-4 w-4 text-amber-300" />,
    className: "border-amber-500/40 bg-amber-500/10",
  },
  info: {
    icon: <Info className="h-4 w-4 text-sky-300" />,
    className: "border-sky-500/40 bg-sky-500/10",
  },
};

export function FinanceAlerts({ alerts }: FinanceAlertsProps) {
  if (!alerts.length) {
    return null;
  }

  return (
    <section className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-5">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 className="text-sm font-semibold text-slate-100">Canlı veri denetimi</h3>
          <p className="text-xs text-slate-400">
            Finansal verilerde tespit edilen olası tutarsızlıkları inceleyin.
          </p>
        </div>
        <Badge variant="default" className="border-slate-700/70 bg-slate-900/60 text-xs text-slate-300">
          {alerts.length} uyarı
        </Badge>
      </div>

      <div className="space-y-3">
        {alerts.map((alert) => {
          const severity = severityConfig[alert.severity];

          return (
            <article
              key={alert.id}
              className={`flex flex-col gap-3 rounded-xl border px-4 py-3 text-sm text-slate-200 ${severity.className}`}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="flex items-start gap-3">
                  <span className="mt-1">{severity.icon}</span>
                  <div className="space-y-1">
                    <p className="font-semibold text-slate-100">{alert.title}</p>
                    <p className="text-xs text-slate-200/80">{alert.message}</p>
                  </div>
                </div>
                {typeof alert.affected === "number" ? (
                  <Badge variant="default" className="bg-slate-900/80 text-xs text-slate-200">
                    {alert.affected} kayıt
                  </Badge>
                ) : null}
              </div>
            </article>
          );
        })}
      </div>
    </section>
  );
}

