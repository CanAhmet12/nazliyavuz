import { useEffect, useState } from "react";
import type { AdminReservation } from "@/lib/api/admin";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { format, formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";

type ReservationsTableProps = {
  reservations: AdminReservation[];
  onSelect?: (reservation: AdminReservation) => void;
  selectedReservationId?: number | null;
  selectable?: boolean;
  selectedIds?: Set<number>;
  onSelectionChange?: (selected: Set<number>) => void;
};

export function ReservationsTable({
  reservations,
  onSelect,
  selectedReservationId,
  selectable = false,
  selectedIds,
  onSelectionChange,
}: ReservationsTableProps) {
  const [internalSelection, setInternalSelection] = useState<Set<number>>(
    () => selectedIds ?? new Set(),
  );

  useEffect(() => {
    if (selectedIds) {
      Promise.resolve().then(() => setInternalSelection(new Set(selectedIds)));
    }
  }, [selectedIds]);

  const toggleAll = (checked: boolean) => {
    const next = new Set<number>();

    if (checked) {
      reservations.forEach((reservation) => {
        next.add(reservation.id);
      });
    }

    if (!selectedIds) {
      setInternalSelection(next);
    }
    onSelectionChange?.(next);
  };

  const toggleOne = (id: number, checked: boolean) => {
    const next = new Set(selectedIds ?? internalSelection);
    if (checked) {
      next.add(id);
    } else {
      next.delete(id);
    }

    if (!selectedIds) {
      setInternalSelection(next);
    }
    onSelectionChange?.(next);
  };

  const currentSelection = selectedIds ?? internalSelection;
  const allSelected = reservations.length > 0 && currentSelection.size === reservations.length;
  const indeterminate =
    currentSelection.size > 0 && currentSelection.size < reservations.length;

  if (!reservations.length) {
    return (
      <div className="flex h-48 flex-col items-center justify-center rounded-xl border border-slate-800/60 bg-slate-950/60 text-center">
        <p className="text-sm font-medium text-slate-200">
          Listelenecek rezervasyon bulunamadı
        </p>
        <p className="mt-1 text-xs text-slate-500">
          Filtreleri değiştirerek farklı sonuçlar deneyebilirsiniz.
        </p>
      </div>
    );
  }

  return (
    <>
      {/* Mobile Card View */}
      <div className="space-y-3 md:hidden">
        {reservations.map((reservation) => {
          const isSelected = currentSelection.has(reservation.id);
          const scheduled = reservation.scheduled_at ?? reservation.proposed_datetime;
          return (
            <div
              key={reservation.id}
              onClick={(event) => {
                if ((event.target as HTMLElement).closest("input[type='checkbox']")) {
                  return;
                }
                onSelect?.(reservation);
              }}
              className={cn(
                "cursor-pointer rounded-xl border border-slate-800/60 bg-slate-950/70 p-4 transition-all active:scale-[0.98]",
                selectedReservationId === reservation.id && "border-sky-500/40 bg-sky-500/10",
              )}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1 space-y-2">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                      <h3 className="truncate text-sm font-semibold text-slate-100">
                        {reservation.title ?? reservation.subject ?? `Rezervasyon #${reservation.id}`}
                      </h3>
                      {reservation.category?.name && (
                        <p className="mt-0.5 text-xs text-slate-500">{reservation.category.name}</p>
                      )}
                    </div>
                    {selectable && (
                      <input
                        type="checkbox"
                        className="h-4 w-4 shrink-0 rounded border-slate-700 bg-slate-900 text-sky-500 focus:ring-sky-500"
                        checked={isSelected}
                        onChange={(event) => toggleOne(reservation.id, event.target.checked)}
                        onClick={(e) => e.stopPropagation()}
                      />
                    )}
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge variant={reservationStatusVariants[reservation.status]} className="text-xs">
                      {reservationStatusCopy[reservation.status]}
                    </Badge>
                    {reservation.payment_status && (
                      <Badge
                        variant={paymentStatusVariants[reservation.payment_status] ?? "default"}
                        className="text-xs"
                      >
                        {paymentStatusCopy[reservation.payment_status]}
                      </Badge>
                    )}
                  </div>
                  <div className="space-y-1.5 text-xs text-slate-400">
                    {reservation.student && (
                      <div>
                        <span className="text-slate-500">Öğrenci: </span>
                        <span className="text-slate-300">{reservation.student.name}</span>
                      </div>
                    )}
                    {reservation.teacher && (
                      <div>
                        <span className="text-slate-500">Öğretmen: </span>
                        <span className="text-slate-300">{reservation.teacher.name}</span>
                      </div>
                    )}
                    {scheduled && (
                      <div>
                        <span className="text-slate-500">Planlanan: </span>
                        <span className="text-slate-300">
                          {formatDate(scheduled)} • {formatRelativeDistance(scheduled)}
                        </span>
                      </div>
                    )}
                    {typeof reservation.price === "number" && (
                      <div>
                        <span className="text-slate-500">Ücret: </span>
                        <span className="text-slate-300">
                          {reservation.price.toFixed(2)} {reservation.currency ?? "TRY"}
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Desktop Table View */}
      <div className="hidden overflow-hidden rounded-xl border border-slate-800/60 bg-slate-950/70 md:block">
        <table className="w-full table-fixed border-collapse text-sm text-slate-200">
        <thead className="bg-slate-950/80 text-xs uppercase tracking-wide text-slate-400">
          <tr>
            {selectable ? (
              <th className="w-10 px-3 py-3 text-left">
                <input
                  type="checkbox"
                  className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-sky-500 focus:ring-sky-500"
                  checked={allSelected}
                  ref={(input) => {
                    if (input) {
                      input.indeterminate = indeterminate;
                    }
                  }}
                  onChange={(event) => toggleAll(event.target.checked)}
                />
              </th>
            ) : null}
            <th className="px-4 py-3 text-left font-medium">Ders / Başlık</th>
            <th className="px-4 py-3 text-left font-medium">Öğrenci</th>
            <th className="px-4 py-3 text-left font-medium">Öğretmen</th>
            <th className="px-4 py-3 text-left font-medium">Durum</th>
            <th className="px-4 py-3 text-left font-medium">Planlanan</th>
            <th className="px-4 py-3 text-left font-medium">Ücret</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-800/70">
          {reservations.map((reservation) => (
            <tr
              key={reservation.id}
              className={cn(
                "cursor-pointer transition-colors hover:bg-slate-900/50",
                selectedReservationId === reservation.id && "bg-sky-500/10",
              )}
              onClick={(event) => {
                if ((event.target as HTMLElement).closest("input[type='checkbox']")) {
                  return;
                }
                onSelect?.(reservation);
              }}
            >
              {selectable ? (
                <td className="w-10 px-3 py-4">
                  <input
                    type="checkbox"
                    className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-sky-500 focus:ring-sky-500"
                    checked={currentSelection.has(reservation.id)}
                    onChange={(event) => toggleOne(reservation.id, event.target.checked)}
                  />
                </td>
              ) : null}
              <td className="px-4 py-4">
                <div className="flex flex-col gap-1">
                  <span className="font-medium text-slate-100">
                    {reservation.title ?? reservation.subject ?? `Rezervasyon #${reservation.id}`}
                  </span>
                  {reservation.category?.name && (
                    <span className="text-xs text-slate-500">
                      {reservation.category.name}
                    </span>
                  )}
                  <span className="text-[11px] uppercase tracking-wide text-slate-600">
                    Oluşturma: {formatDate(reservation.created_at)}
                  </span>
                </div>
              </td>
              <td className="px-4 py-4">
                {reservation.student ? (
                  <div className="flex flex-col">
                    <span className="text-slate-100">
                      {reservation.student.name}
                    </span>
                    <span className="text-xs text-slate-500">
                      {reservation.student.email}
                    </span>
                  </div>
                ) : (
                  <span className="text-xs text-slate-500">Belirtilmemiş</span>
                )}
              </td>
              <td className="px-4 py-4">
                {reservation.teacher ? (
                  <div className="flex flex-col">
                    <span className="text-slate-100">
                      {reservation.teacher.name}
                    </span>
                    <span className="text-xs text-slate-500">
                      {reservation.teacher.email}
                    </span>
                  </div>
                ) : (
                  <span className="text-xs text-slate-500">Belirtilmemiş</span>
                )}
              </td>
              <td className="px-4 py-4">
                <div className="flex flex-col gap-2">
                  <Badge variant={reservationStatusVariants[reservation.status]}>
                    {reservationStatusCopy[reservation.status]}
                  </Badge>
                  {reservation.payment_status && (
                    <Badge
                      variant={
                        paymentStatusVariants[reservation.payment_status] ??
                        "default"
                      }
                    >
                      {paymentStatusCopy[reservation.payment_status]}
                    </Badge>
                  )}
                </div>
              </td>
              <td className="px-4 py-4 text-xs text-slate-400">
                {(() => {
                  const scheduled =
                    reservation.scheduled_at ?? reservation.proposed_datetime;
                  return scheduled
                    ? `${formatDate(scheduled)} • ${formatRelativeDistance(scheduled)}`
                    : "Planlanmamış";
                })()}
              </td>
              <td className="px-4 py-4 text-xs text-slate-400">
                {typeof reservation.price === "number"
                  ? `${reservation.price.toFixed(2)} ${
                      reservation.currency ?? "TRY"
                    }`
                  : "Belirtilmemiş"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      </div>
    </>
  );
}

const reservationStatusCopy: Record<AdminReservation["status"], string> = {
  pending: "Beklemede",
  accepted: "Onaylandı",
  in_progress: "Devam ediyor",
  completed: "Tamamlandı",
  cancelled: "İptal edildi",
};

const reservationStatusVariants: Record<
  AdminReservation["status"],
  "info" | "success" | "warning" | "destructive"
> = {
  pending: "info",
  accepted: "success",
  in_progress: "info",
  completed: "success",
  cancelled: "destructive",
};

const paymentStatusCopy: Record<string, string> = {
  awaiting_payment: "Ödeme bekleniyor",
  paid: "Ödendi",
  refunded: "İade edildi",
  failed: "Ödeme başarısız",
};

const paymentStatusVariants: Record<
  string,
  "info" | "success" | "warning" | "destructive"
> = {
  awaiting_payment: "warning",
  paid: "success",
  refunded: "info",
  failed: "destructive",
};

function formatDate(date: string) {
  try {
    return format(new Date(date), "d MMM yyyy HH:mm", { locale: tr });
  } catch {
    return "-";
  }
}

function formatRelativeDistance(date: string) {
  try {
    return formatDistanceToNow(new Date(date), { addSuffix: true, locale: tr });
  } catch {
    return "";
  }
}

