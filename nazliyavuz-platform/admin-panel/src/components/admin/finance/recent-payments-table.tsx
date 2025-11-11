"use client";

import { formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";

type RecentPayment = {
  id: string;
  student: string;
  teacher: string;
  amount: number;
  currency: string;
  status: "paid" | "refunded" | "failed";
  date: string;
};

type RecentPaymentsTableProps = {
  payments: RecentPayment[];
};

export function RecentPaymentsTable({ payments }: RecentPaymentsTableProps) {
  if (!payments.length) {
    return (
      <div
        role="status"
        aria-live="polite"
        className="flex flex-col items-center justify-center gap-3 rounded-2xl border border-dashed border-slate-800/70 bg-slate-950/60 p-10 text-center"
      >
        <div className="rounded-full border border-slate-800/70 bg-slate-900/60 px-3 py-1 text-xs font-medium uppercase tracking-wide text-slate-400">
          Ödeme geçmişi
        </div>
        <h3 className="text-base font-semibold text-slate-100">
          Henüz ödeme kaydı yok
        </h3>
        <p className="max-w-xs text-sm text-slate-400">
          Tamamlanan ve iade edilen tüm ödemeler burada listelenecek. İlk
          ödemenizi aldıktan sonra bu tablo otomatik olarak dolacaktır.
        </p>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-800/80 bg-slate-950/60">
      <table
        className="w-full border-collapse text-sm text-slate-200"
        aria-describedby="recent-payments-caption"
      >
        <caption id="recent-payments-caption" className="sr-only">
          Son 30 güne ait ödeme hareketleri listesi
        </caption>
        <thead className="bg-slate-950/80 text-xs uppercase tracking-wide text-slate-400">
          <tr>
            <th scope="col" className="px-4 py-3 text-left font-medium">
              Ödeme No
            </th>
            <th scope="col" className="px-4 py-3 text-left font-medium">
              Öğrenci
            </th>
            <th scope="col" className="px-4 py-3 text-left font-medium">
              Öğretmen
            </th>
            <th scope="col" className="px-4 py-3 text-left font-medium">
              Tutar
            </th>
            <th scope="col" className="px-4 py-3 text-left font-medium">
              Durum
            </th>
            <th scope="col" className="px-4 py-3 text-left font-medium">
              Zaman
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-800/70">
          {payments.map((payment) => (
            <tr key={payment.id} className="hover:bg-slate-900/40">
              <td className="px-4 py-4 text-xs text-slate-400">{payment.id}</td>
              <td className="px-4 py-4">
                <div className="text-sm font-medium text-slate-100">
                  {payment.student}
                </div>
              </td>
              <td className="px-4 py-4 text-sm text-slate-300">
                {payment.teacher}
              </td>
              <td className="px-4 py-4 text-sm text-slate-100">
                {formatCurrency(payment.amount, payment.currency)}
              </td>
              <td className="px-4 py-4">
                <StatusPill status={payment.status} />
              </td>
              <td className="px-4 py-4 text-xs text-slate-500">
                {formatDistanceToNow(new Date(payment.date), {
                  addSuffix: true,
                  locale: tr,
                })}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function StatusPill({ status }: { status: RecentPayment["status"] }) {
  const map: Record<
    RecentPayment["status"],
    { label: string; className: string }
  > = {
    paid: { label: "Ödendi", className: "bg-emerald-500/10 text-emerald-300" },
    refunded: { label: "İade edildi", className: "bg-sky-500/10 text-sky-300" },
    failed: { label: "Başarısız", className: "bg-rose-500/10 text-rose-300" },
  };

  const item = map[status];
  return (
    <span
      className={`rounded-full px-3 py-1 text-xs font-medium ${item.className}`}
      aria-label={`Durum: ${item.label}`}
    >
      {item.label}
    </span>
  );
}

function formatCurrency(value: number, currency: string) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(value);
}

