import { cn } from "@/lib/utils";

type ReservationTrendProps = {
  data: Array<{ date: string; count: number }>;
};

export function ReservationTrend({ data }: ReservationTrendProps) {
  const max = Math.max(...data.map((item) => item.count), 1);

  return (
    <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-sm font-semibold text-slate-100">
            Rezervasyon Aktivitesi
          </h3>
          <p className="text-xs text-slate-500">
            Son 7 günün günlük rezervasyon sayıları
          </p>
        </div>
      </div>
      <div className="flex items-end gap-3">
        {data.map((item) => (
          <div key={item.date} className="flex flex-1 flex-col items-center">
            <div className="flex h-32 w-full flex-col justify-end rounded-lg bg-slate-900/70">
              <div
                className={cn(
                  "relative mx-auto w-8 rounded-t-lg bg-sky-400/70 shadow-[0_4px_20px_rgba(56,189,248,0.35)]",
                )}
                style={{ height: `${(item.count / max) * 100 || 5}%` }}
              >
                <span className="absolute -top-5 left-1/2 -translate-x-1/2 text-[11px] text-slate-200">
                  {item.count}
                </span>
              </div>
            </div>
            <span className="mt-2 text-xs text-slate-500">
              {formatDay(item.date)}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function formatDay(date: string) {
  const d = new Date(date);
  return d.toLocaleDateString("tr-TR", { day: "numeric", month: "short" });
}

