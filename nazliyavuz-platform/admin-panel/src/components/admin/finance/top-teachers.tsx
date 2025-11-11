"use client";

import { Trophy } from "lucide-react";

type TopTeacher = {
  teacher: string;
  amount: number;
  currency: string;
  lessons: number;
};

type TopTeachersProps = {
  data: TopTeacher[];
};

export function TopTeachers({ data }: TopTeachersProps) {
  return (
    <div className="space-y-3 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <h3 className="text-sm font-semibold text-slate-100 flex items-center gap-2">
        <Trophy className="h-4 w-4 text-amber-400" />
        Gelire Göre En İyi Öğretmenler
      </h3>
      <div className="space-y-2 text-sm text-slate-200">
        {data.map((item, index) => (
          <div
            key={item.teacher}
            className="flex items-center justify-between rounded-xl border border-slate-800/60 bg-slate-950/70 px-4 py-3"
          >
            <div className="flex items-center gap-3">
              <span className="flex h-7 w-7 items-center justify-center rounded-full bg-amber-500/10 text-xs font-semibold text-amber-300">
                #{index + 1}
              </span>
              <div>
                <p className="font-medium text-slate-100">{item.teacher}</p>
                <p className="text-xs text-slate-500">
                  {item.lessons} ders tamamlandı
                </p>
              </div>
            </div>
            <p className="text-sm font-semibold text-emerald-300">
              {formatCurrency(item.amount, item.currency)}
            </p>
          </div>
        ))}
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

