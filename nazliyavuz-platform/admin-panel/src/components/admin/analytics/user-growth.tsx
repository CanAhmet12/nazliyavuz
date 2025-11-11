import { cn } from "@/lib/utils";

type UserGrowthProps = {
  data: Array<{ month: string; count: number }>;
};

export function UserGrowth({ data }: UserGrowthProps) {
  const max = Math.max(...data.map((item) => item.count), 1);

  return (
    <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <div>
        <h3 className="text-sm font-semibold text-slate-100">
          Kullanıcı Büyümesi
        </h3>
        <p className="text-xs text-slate-500">
          Son 12 ayda platforma katılan kullanıcı sayısı
        </p>
      </div>
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        {data.map((item) => (
          <div
            key={item.month}
            className="rounded-xl border border-slate-800/60 bg-slate-950/70 p-4"
          >
            <div className="flex items-center justify-between text-xs text-slate-500">
              <span className="font-medium text-slate-100">{item.month}</span>
              <span>{item.count.toLocaleString("tr-TR")} kişi</span>
            </div>
            <div className="mt-3 h-2 rounded-full bg-slate-900/70">
              <div
                className={cn(
                  "h-full rounded-full bg-gradient-to-r from-sky-400 to-emerald-400",
                )}
                style={{ width: `${(item.count / max) * 100 || 5}%` }}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

