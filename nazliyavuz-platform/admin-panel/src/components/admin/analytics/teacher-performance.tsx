import { Star } from "lucide-react";

type TeacherPerformanceProps = {
  data: Array<{
    name: string;
    reservations_count: number;
    average_rating: number | null | undefined;
  }>;
};

export function TeacherPerformance({ data }: TeacherPerformanceProps) {
  return (
    <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-sm font-semibold text-slate-100">
            Öğretmen Performansı
          </h3>
          <p className="text-xs text-slate-500">
            Rezervasyon sayısı ve ortalama değerlendirme skorları
          </p>
        </div>
      </div>
      <div className="space-y-2 text-sm text-slate-200">
        {data.map((teacher) => (
          <div
            key={teacher.name}
            className="flex items-center justify-between rounded-xl border border-slate-800/60 bg-slate-950/70 px-4 py-3"
          >
            <div>
              <p className="font-medium text-slate-100">{teacher.name}</p>
              <p className="text-xs text-slate-500">
                {teacher.reservations_count} rezervasyon
              </p>
            </div>
            <div className="flex items-center gap-1 text-amber-400">
              <Star className="h-4 w-4 fill-amber-400 text-amber-400" />
              <span className="text-xs font-semibold">
                {typeof teacher.average_rating === "number"
                  ? teacher.average_rating.toFixed(2)
                  : "—"}
              </span>
            </div>
          </div>
        ))}
        {!data.length && (
          <p className="text-xs text-slate-500">
            Performans verileri henüz mevcut değil.
          </p>
        )}
      </div>
    </div>
  );
}

