"use client";

import { format } from "date-fns";
import { tr } from "date-fns/locale";

type PendingPayout = {
  id: string;
  teacher: string;
  amount: number;
  currency: string;
  scheduledDate: string;
  status: "scheduled" | "processing";
};

type PendingPayoutsProps = {
  payouts: PendingPayout[];
};

export function PendingPayouts({ payouts }: PendingPayoutsProps) {
  if (!payouts.length) {
    return (
      <div className="rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6 text-sm text-slate-400">
        Yaklaşan ödeme bulunmuyor.
      </div>
    );
  }

  return (
    <div className="space-y-3 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <h3 className="text-sm font-semibold text-slate-100">
        Planlanan Ödemeler
      </h3>
      <div className="space-y-3 text-sm text-slate-200">
        {payouts.map((payout) => (
          <div
            key={payout.id}
            className="flex items-center justify-between rounded-xl border border-slate-800/60 bg-slate-950/70 px-4 py-3"
          >
            <div>
              <p className="font-medium text-slate-100">{payout.teacher}</p>
              <p className="text-xs text-slate-500">
                {format(new Date(payout.scheduledDate), "d MMM yyyy", {
                  locale: tr,
                })}
              </p>
            </div>
            <div className="text-right">
              <p className="font-semibold text-slate-100">
                {formatCurrency(payout.amount, payout.currency)}
              </p>
              <span className="text-xs text-slate-500">
                {payoutStatusCopy[payout.status]}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

const payoutStatusCopy: Record<PendingPayout["status"], string> = {
  scheduled: "Planlandı",
  processing: "İşleniyor",
};

function formatCurrency(value: number, currency: string) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(value);
}

