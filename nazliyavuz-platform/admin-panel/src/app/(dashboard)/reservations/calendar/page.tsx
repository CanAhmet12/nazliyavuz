"use client";

import { useCallback, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  addDays,
  format,
  parseISO,
  startOfWeek,
  endOfWeek,
  compareAsc,
  setHours,
  setMinutes,
  setSeconds,
  isSameDay,
  isEqual,
} from "date-fns";
import { tr } from "date-fns/locale";
import {
  Calendar,
  ChevronLeft,
  ChevronRight,
  RefreshCcw,
  Clock,
  User,
  GraduationCap,
  Pencil,
  AlertTriangle,
} from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";
import { DragDropContext, Droppable, Draggable, type DropResult } from "@hello-pangea/dnd";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { cn } from "@/lib/utils";
import {
  type AdminCalendarReservation,
  type AdminCalendarResponse,
  type AdminReservation,
  type ReservationStatus,
  type UpdateReservationStatusPayload,
  type RefundReservationPayload,
  type HandleReschedulePayload,
  updateReservationStatus,
  refundReservation,
  handleAdminReschedule,
  updateReservationSchedule,
} from "@/lib/api/admin";
import type { UseQueryResult } from "@tanstack/react-query";
import { useAdminReservationCalendar, reservationCalendarKey } from "@/hooks/use-admin-reservation-calendar";
import { ReservationDetailDrawer } from "@/components/admin/reservations/reservation-detail-drawer";
import { useMutationToast } from "@/hooks/use-mutation-toast";

type CalendarRange = {
  start: Date;
  end: Date;
};

type StatusUpdatePayload = Omit<UpdateReservationStatusPayload, "reservationId">;
type RefundActionPayload = Omit<RefundReservationPayload, "reservationId">;
type RescheduleActionPayload = Omit<HandleReschedulePayload, "reservationId">;

const statusFilters: Array<{ label: string; value: ReservationStatus | "" }> = [
  { label: "Tümü", value: "" },
  { label: "Beklemede", value: "pending" },
  { label: "Onaylandı", value: "accepted" },
  { label: "Devam ediyor", value: "in_progress" },
  { label: "Tamamlandı", value: "completed" },
  { label: "İptal edildi", value: "cancelled" },
];

const reservationStatusCopy: Record<ReservationStatus, string> = {
  pending: "Beklemede",
  accepted: "Onaylandı",
  in_progress: "Devam ediyor",
  completed: "Tamamlandı",
  cancelled: "İptal edildi",
};

const reservationStatusBadge: Record<ReservationStatus, "default" | "success" | "warning" | "destructive" | "info"> = {
  pending: "warning",
  accepted: "success",
  in_progress: "info",
  completed: "success",
  cancelled: "destructive",
};

function buildAdminReservation(item: AdminCalendarReservation): AdminReservation {
  return {
    id: item.id,
    title: item.title,
    subject: item.subject,
    status: item.status as ReservationStatus,
    scheduled_at: item.start ?? null,
    proposed_datetime: item.proposed_datetime ?? item.start ?? null,
    created_at: new Date().toISOString(),
    duration_minutes: item.duration_minutes ?? null,
    price: item.price ?? null,
    currency: item.currency ?? null,
    payment_status: (item.payment_status as AdminReservation["payment_status"]) ?? null,
    notes: item.notes ?? null,
    teacher_notes: item.teacher_notes ?? null,
    admin_notes: item.admin_notes ?? null,
    cancelled_reason: null,
    cancelled_at: null,
    refund_amount: null,
    refund_reason: null,
    refunded_at: null,
    student: item.student ?? null,
    teacher: item.teacher ?? null,
    category: item.category ?? null,
    payments: [],
    reschedule_request: item.reschedule_request ?? null,
  };
}

export default function ReservationCalendarPage() {
  const initialRange = useMemo<CalendarRange>(() => {
    const start = startOfWeek(new Date(), { weekStartsOn: 1 });
    const end = endOfWeek(new Date(), { weekStartsOn: 1 });
    return { start, end };
  }, []);

  const [range, setRange] = useState<CalendarRange>(initialRange);
  const [status, setStatus] = useState<ReservationStatus | "">("");
  const [selectedReservation, setSelectedReservation] = useState<AdminReservation | null>(null);
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const router = useRouter();
  const queryClient = useQueryClient();

  const filters = {
    start_date: format(range.start, "yyyy-MM-dd"),
    end_date: format(range.end, "yyyy-MM-dd"),
    status: status || undefined,
  };

  const calendarQuery = useAdminReservationCalendar(filters) as UseQueryResult<
    AdminCalendarResponse,
    Error
  >;
  const { data, isLoading, isFetching, refetch } = calendarQuery;

  const statusMutation = useMutationToast(updateReservationStatus, {
    successMessage: "Rezervasyon güncellendi.",
    onSuccess: (response) => {
      if (response?.reservation) {
        setSelectedReservation(response.reservation);
      }
      queryClient.invalidateQueries({ queryKey: reservationCalendarKey });
    },
  });

  const refundMutation = useMutationToast(refundReservation, {
    successMessage: "İade işlemi tamamlandı.",
    onSuccess: (response) => {
      if (response?.reservation) {
        setSelectedReservation(response.reservation);
      }
      queryClient.invalidateQueries({ queryKey: reservationCalendarKey });
    },
  });

  const rescheduleMutation = useMutationToast(handleAdminReschedule, {
    successMessage: "Yeniden planlama talebi güncellendi.",
    onSuccess: (response) => {
      if (response?.reservation) {
        setSelectedReservation(response.reservation);
      }
      queryClient.invalidateQueries({ queryKey: reservationCalendarKey });
    },
  });

  const [quickEditReservation, setQuickEditReservation] = useState<AdminReservation | null>(null);
  const [quickEditDate, setQuickEditDate] = useState("");
  const [quickEditDuration, setQuickEditDuration] = useState("");
  const [quickEditStatus, setQuickEditStatus] = useState<ReservationStatus>("pending");
  const [quickEditTeacherNotes, setQuickEditTeacherNotes] = useState("");
  const [quickEditNotifyParticipants, setQuickEditNotifyParticipants] = useState(true);

  const resetQuickEditForm = useCallback(() => {
    setQuickEditReservation(null);
    setQuickEditDate("");
    setQuickEditDuration("");
    setQuickEditStatus("pending");
    setQuickEditTeacherNotes("");
    setQuickEditNotifyParticipants(true);
  }, []);

  const scheduleMutation = useMutationToast(updateReservationSchedule, {
    successMessage: "Rezervasyon takvimde güncellendi.",
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: reservationCalendarKey });
    },
  });

  const quickStatusMutation = useMutationToast(updateReservationStatus, {
    successMessage: "Rezervasyon durumu güncellendi.",
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: reservationCalendarKey });
    },
  });

  const groupedReservations = useMemo(() => {
    if (!data) {
      return [];
    }

    const map = new Map<string, AdminCalendarReservation[]>();

    for (const reservation of data.reservations) {
      const start = reservation.start ?? reservation.proposed_datetime ?? null;
      const key = start ? format(parseISO(start), "yyyy-MM-dd") : "unscheduled";
      const current = map.get(key) ?? [];
      current.push(reservation);
      map.set(key, current);
    }

    return Array.from(map.entries())
      .map(([date, items]) => ({
        date,
        items: items.sort((a, b) => {
          const dateA = a.start ?? a.proposed_datetime ?? "";
          const dateB = b.start ?? b.proposed_datetime ?? "";
          if (!dateA || !dateB) return 0;
          return compareAsc(parseISO(dateA), parseISO(dateB));
        }),
      }))
      .sort((a, b) => {
        if (a.date === "unscheduled") {
          return 1;
        }
        if (b.date === "unscheduled") {
          return -1;
        }
        return compareAsc(parseISO(a.date), parseISO(b.date));
      });
  }, [data]);

  const reservationMap = useMemo(() => {
    const map = new Map<number, AdminCalendarReservation>();

    if (data?.reservations) {
      data.reservations.forEach((reservation) => {
        map.set(reservation.id, reservation);
      });
    }

    return map;
  }, [data]);

  const calendarGroups = useMemo(() => {
    return groupedReservations.map(({ date, items }) => {
      const isUnscheduled = date === "unscheduled";
      const parsedDate = !isUnscheduled ? parseISO(date) : null;

      return {
        date,
        items,
        isUnscheduled,
        isToday: parsedDate ? isSameDay(parsedDate, new Date()) : false,
        dayLabel: isUnscheduled ? "Plan bekliyor" : format(parsedDate!, "EEEE", { locale: tr }),
        dateLabel: isUnscheduled ? "Tarih atanmamış" : format(parsedDate!, "d MMM yyyy", { locale: tr }),
      };
    });
  }, [groupedReservations]);

  const handleShift = (days: number) => {
    setRange((prev) => ({
      start: addDays(prev.start, days),
      end: addDays(prev.end, days),
    }));
  };

  const handleToday = () => {
    const start = startOfWeek(new Date(), { weekStartsOn: 1 });
    const end = endOfWeek(new Date(), { weekStartsOn: 1 });
    setRange({ start, end });
  };

  const openDrawer = (item: AdminCalendarReservation) => {
    setSelectedReservation(buildAdminReservation(item));
    setIsDrawerOpen(true);
  };

  const openQuickEdit = (item: AdminCalendarReservation) => {
    const reservation = buildAdminReservation(item);
    const iso = reservation.proposed_datetime ?? reservation.scheduled_at ?? null;

    setQuickEditReservation(reservation);
    setQuickEditDate(iso ? format(parseISO(iso), "yyyy-MM-dd'T'HH:mm") : "");
    setQuickEditDuration(String(reservation.duration_minutes ?? 60));
    setQuickEditStatus(reservation.status);
    setQuickEditTeacherNotes(reservation.teacher_notes ?? "");
    setQuickEditNotifyParticipants(true);
  };

  const handleStatusUpdate = async (payload: StatusUpdatePayload) => {
    if (!selectedReservation) return;
    await statusMutation.mutateAsync({
      reservationId: selectedReservation.id,
      ...payload,
    });
  };

  const handleRefund = async (payload: RefundActionPayload) => {
    if (!selectedReservation) return;
    await refundMutation.mutateAsync({
      reservationId: selectedReservation.id,
      ...payload,
    });
  };

  const handleReschedule = async (payload: RescheduleActionPayload) => {
    if (!selectedReservation) return;
    await rescheduleMutation.mutateAsync({
      reservationId: selectedReservation.id,
      ...payload,
    });
  };

  const isQuickEditSaving = scheduleMutation.isPending || quickStatusMutation.isPending;

  const handleQuickEditClose = () => {
    if (isQuickEditSaving) {
      return;
    }
    resetQuickEditForm();
  };

  const handleQuickEditSave = async () => {
    if (!quickEditReservation) {
      return;
    }

    const operations: Array<Promise<unknown>> = [];

    const parsedDuration = quickEditDuration ? Number.parseInt(quickEditDuration, 10) : undefined;
    const normalizedDuration = Number.isFinite(parsedDuration ?? NaN) ? parsedDuration : undefined;

    const originalIso =
      quickEditReservation.proposed_datetime ??
      quickEditReservation.scheduled_at ??
      null;

    const editedIso = quickEditDate ? new Date(quickEditDate).toISOString() : null;

    const scheduleChanged =
      editedIso !== null &&
      (!originalIso || !isEqual(parseISO(editedIso), parseISO(originalIso)));

    const durationChanged =
      normalizedDuration !== undefined &&
      normalizedDuration !== (quickEditReservation.duration_minutes ?? undefined);

    if (scheduleChanged || durationChanged) {
      const payload = {
        reservationId: quickEditReservation.id,
        proposed_datetime: editedIso ?? new Date().toISOString(),
        duration_minutes: normalizedDuration ?? undefined,
        notify_participants: quickEditNotifyParticipants,
      };

      operations.push(scheduleMutation.mutateAsync(payload));
    }

    const notesChanged =
      (quickEditTeacherNotes ?? "").trim() !==
      (quickEditReservation.teacher_notes ?? "").trim();

    const statusChanged = quickEditStatus !== quickEditReservation.status;

    if (statusChanged || notesChanged) {
      operations.push(
        quickStatusMutation.mutateAsync({
          reservationId: quickEditReservation.id,
          status: quickEditStatus,
          teacher_notes: quickEditTeacherNotes || null,
          notify_participants: quickEditNotifyParticipants,
        }),
      );
    }

    if (operations.length === 0) {
      handleQuickEditClose();
      return;
    }

    try {
      await Promise.all(operations);
      await refetch();
      if (selectedReservation?.id === quickEditReservation.id) {
        setSelectedReservation(null);
        setIsDrawerOpen(false);
      }
      resetQuickEditForm();
    } catch {
      // errors handled by useMutationToast
    }
  };

  const handleDragEnd = useCallback(
    async (result: DropResult) => {
      if (scheduleMutation.isPending) {
        return;
      }

      const { destination, source, draggableId } = result;

      if (!destination) {
        return;
      }

      if (destination.droppableId === source.droppableId) {
        return;
      }

      if (destination.droppableId === "unscheduled") {
        return;
      }

      const reservationId = Number.parseInt(draggableId, 10);
      const reservation = reservationMap.get(reservationId);

      if (!reservation) {
        return;
      }

      const referenceIso = reservation.proposed_datetime ?? reservation.start ?? null;

      if (!referenceIso) {
        return;
      }

      try {
        const origin = parseISO(referenceIso);
        const targetDate = parseISO(destination.droppableId);
        const updated = setSeconds(
          setMinutes(setHours(targetDate, origin.getHours()), origin.getMinutes()),
          origin.getSeconds(),
        );

        await scheduleMutation.mutateAsync({
          reservationId,
          proposed_datetime: updated.toISOString(),
          duration_minutes: reservation.duration_minutes ?? undefined,
        });

        await refetch();
      } catch {
        // hata durumunda toast useMutationToast tarafından gösterilir
      }
    },
    [reservationMap, scheduleMutation, refetch],
  );

  return (
    <div className="space-y-4 md:space-y-6">
      <header className="flex flex-col gap-3 rounded-xl border border-slate-800/80 bg-slate-950/60 p-4 md:rounded-2xl md:gap-4 md:p-6 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex items-start gap-2 md:gap-3">
          <div className="rounded-xl border border-slate-800/60 bg-slate-950/60 p-1.5 md:p-2">
            <Calendar className="h-4 w-4 text-sky-400 md:h-5 md:w-5" />
          </div>
          <div>
            <h2 className="text-base font-semibold text-slate-100 md:text-lg">Rezervasyon Takvimi</h2>
            <p className="mt-1 text-xs text-slate-400 md:text-sm">
              {format(range.start, "d MMM yyyy", { locale: tr })} -{" "}
              {format(range.end, "d MMM yyyy", { locale: tr })} tarihleri arası rezervasyonlar.
            </p>
            {data && (
              <p className="mt-1 text-[10px] text-slate-500 md:text-xs">
                {data.count} etkinlik bulunuyor.
              </p>
            )}
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            className="min-h-[36px] border-slate-800 bg-slate-950 text-slate-300 active:scale-[0.98] hover:bg-slate-900/80 md:min-h-0"
            onClick={() => {
              refetch();
            }}
            disabled={isFetching}
          >
            <RefreshCcw className="mr-2 h-3.5 w-3.5 md:h-4 md:w-4" />
            <span className="text-xs md:text-sm">Yenile</span>
          </Button>
          <Button
            variant="ghost"
            size="sm"
            className="min-h-[36px] text-xs text-slate-400 active:scale-[0.98] hover:text-slate-200 md:min-h-0"
            onClick={() => router.push("/reservations")}
          >
            Liste görünümüne dön
          </Button>
        </div>
      </header>

      <section className="flex flex-col gap-3 rounded-xl border border-slate-800/60 bg-slate-950/60 p-4 md:rounded-2xl md:gap-4 md:flex-row md:items-center md:justify-between md:p-5">
        <div className="flex items-center gap-2">
          <Button
            variant="ghost"
            size="icon"
            className="min-h-[36px] min-w-[36px] rounded-full border border-slate-800/70 bg-slate-950/70 text-slate-300 active:scale-[0.98] hover:bg-slate-900/60 md:min-h-0 md:min-w-0"
            onClick={() => handleShift(-7)}
          >
            <ChevronLeft className="h-3.5 w-3.5 md:h-4 md:w-4" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="min-h-[36px] min-w-[36px] rounded-full border border-slate-800/70 bg-slate-950/70 text-slate-300 active:scale-[0.98] hover:bg-slate-900/60 md:min-h-0 md:min-w-0"
            onClick={() => handleShift(7)}
          >
            <ChevronRight className="h-3.5 w-3.5 md:h-4 md:w-4" />
          </Button>
          <Button
            variant="secondary"
            size="sm"
            className="min-h-[36px] border-slate-700 bg-slate-900/70 text-xs text-slate-200 active:scale-[0.98] hover:bg-slate-800/80 md:min-h-0"
            onClick={handleToday}
          >
            Bugün
          </Button>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {statusFilters.map((option) => (
            <Button
              key={option.label}
              variant={status === option.value ? "secondary" : "ghost"}
              size="sm"
              className={cn(
                "min-h-[36px] rounded-full border border-slate-800/70 bg-slate-950/70 text-xs active:scale-[0.98]",
                status === option.value && "border-sky-500/40 bg-sky-500/10 text-sky-200",
                "md:min-h-0",
              )}
              onClick={() =>
                setStatus((prev) => (prev === option.value ? "" : option.value))
              }
            >
              {option.label}
            </Button>
          ))}
        </div>
      </section>

      <section className="space-y-3 md:space-y-4">
        {isLoading ? (
          <CalendarSkeleton />
        ) : calendarGroups.length === 0 ? (
          <Card className="border border-slate-800/70 bg-slate-950/60 p-6 text-center md:p-8">
            <p className="text-xs font-medium text-slate-200 md:text-sm">
              Bu tarih aralığında rezervasyon bulunamadı.
            </p>
            <p className="mt-2 text-[10px] text-slate-500 md:text-xs">
              Tarih aralığını veya filtreleri değiştirerek tekrar deneyebilirsiniz.
            </p>
          </Card>
        ) : (
          <DragDropContext onDragEnd={handleDragEnd}>
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
              {calendarGroups.map((group) => (
                <Droppable
                  key={group.date}
                  droppableId={group.date}
                  isDropDisabled={group.isUnscheduled}
                >
                  {(provided, snapshot) => (
                    <div
                      ref={provided.innerRef}
                      {...provided.droppableProps}
                      className={cn(
                        "flex flex-col gap-3 rounded-2xl border border-slate-800/70 bg-slate-950/60 p-4 transition",
                        snapshot.isDraggingOver && "border-sky-500/40 bg-sky-500/10",
                        group.isToday && "border-sky-500/40",
                      )}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-xs uppercase tracking-wide text-slate-500">
                            {group.dayLabel}
                          </p>
                          <h3 className="text-sm font-semibold text-slate-100">
                            {group.dateLabel}
                          </h3>
                        </div>
                        <Badge variant="default" className="bg-slate-900/60 text-xs">
                          {group.items.length} rezervasyon
                        </Badge>
                      </div>

                      <div className="space-y-2">
                        {group.items.map((reservation, index) => (
                          <Draggable
                            key={reservation.id}
                            draggableId={reservation.id.toString()}
                            index={index}
                          >
                            {(dragProvided, dragSnapshot) => (
                              <div
                                ref={dragProvided.innerRef}
                                {...dragProvided.draggableProps}
                                {...dragProvided.dragHandleProps}
                              >
                                <CalendarReservationCard
                                  reservation={reservation}
                                  onOpenDetails={openDrawer}
                                  onOpenQuickEdit={openQuickEdit}
                                  isDragging={dragSnapshot.isDragging}
                                />
                              </div>
                            )}
                          </Draggable>
                        ))}
                        {provided.placeholder}
                        {group.items.length === 0 ? (
                          <p className="text-[11px] text-slate-500">
                            {group.isUnscheduled
                              ? "Rezervasyonu takvime eklemek için bir tarihe sürükleyin."
                              : "Bu günde planlanan rezervasyon yok."}
                          </p>
                        ) : null}
                      </div>
                    </div>
                  )}
                </Droppable>
              ))}
            </div>
          </DragDropContext>
        )}
      </section>

      <ReservationDetailDrawer
        reservation={selectedReservation}
        open={isDrawerOpen}
        onClose={() => setIsDrawerOpen(false)}
        onUpdateStatus={handleStatusUpdate}
        onRefund={handleRefund}
        onHandleReschedule={handleReschedule}
        isUpdating={statusMutation.isPending}
        isRefunding={refundMutation.isPending}
        isRescheduleProcessing={rescheduleMutation.isPending}
      />
      <QuickEditDialog
        reservation={quickEditReservation}
        dateValue={quickEditDate}
        durationValue={quickEditDuration}
        statusValue={quickEditStatus}
        teacherNotesValue={quickEditTeacherNotes}
        notifyParticipants={quickEditNotifyParticipants}
        onChangeDate={setQuickEditDate}
        onChangeDuration={setQuickEditDuration}
        onChangeStatus={setQuickEditStatus}
        onChangeTeacherNotes={setQuickEditTeacherNotes}
        onToggleNotifyParticipants={setQuickEditNotifyParticipants}
        onClose={handleQuickEditClose}
        onSave={handleQuickEditSave}
        isSaving={isQuickEditSaving}
      />
    </div>
  );
}

function CalendarSkeleton() {
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {Array.from({ length: 4 }).map((_, index) => (
        <Card key={index} className="space-y-4 border border-slate-800/60 bg-slate-950/60 p-4">
          <div className="flex items-center justify-between">
            <div>
              <Skeleton className="h-3 w-24 bg-slate-800/60" />
              <Skeleton className="mt-2 h-4 w-32 bg-slate-800/60" />
            </div>
            <Skeleton className="h-6 w-16 rounded-full bg-slate-800/60" />
          </div>
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, itemIndex) => (
              <div key={itemIndex} className="rounded-xl border border-slate-800/60 bg-slate-950/70 p-4">
                <Skeleton className="h-3 w-20 bg-slate-800/60" />
                <Skeleton className="mt-2 h-4 w-40 bg-slate-800/60" />
                <Skeleton className="mt-2 h-3 w-32 bg-slate-800/60" />
              </div>
            ))}
          </div>
        </Card>
      ))}
    </div>
  );
}

type CalendarReservationCardProps = {
  reservation: AdminCalendarReservation;
  onOpenDetails: (reservation: AdminCalendarReservation) => void;
  onOpenQuickEdit: (reservation: AdminCalendarReservation) => void;
  isDragging?: boolean;
};

function CalendarReservationCard({
  reservation,
  onOpenDetails,
  onOpenQuickEdit,
  isDragging,
}: CalendarReservationCardProps) {
  const status = reservation.status as ReservationStatus;
  const startIso = reservation.start ?? reservation.proposed_datetime ?? null;
  const endIso = reservation.end ?? null;

  const startTime = startIso ? format(parseISO(startIso), "HH:mm", { locale: tr }) : "Planlanmadı";
  const endTime = endIso ? format(parseISO(endIso), "HH:mm", { locale: tr }) : null;

  const durationLabel = reservation.duration_minutes
    ? `${reservation.duration_minutes} dk`
    : null;

  const title = reservation.subject ?? reservation.title ?? `Rezervasyon #${reservation.id}`;

  return (
    <div
      className={cn(
        "relative overflow-hidden rounded-xl border border-slate-800/70 bg-slate-950/70 transition hover:border-sky-500/40 hover:bg-slate-900/60",
        isDragging && "border-sky-500/60 shadow-lg shadow-sky-900/50",
      )}
    >
      <button
        type="button"
        onClick={() => onOpenDetails(reservation)}
        className="flex w-full flex-col gap-3 px-4 py-3 text-left"
      >
        <div className="flex items-start justify-between gap-3">
          <div className="space-y-1">
            <p className="flex items-center gap-2 text-xs uppercase tracking-wide text-slate-500">
              <Clock className="h-3.5 w-3.5 text-slate-400" />
              <span>
                {startTime}
                {endTime ? ` • ${endTime}` : ""}
              </span>
              {durationLabel ? <span className="text-slate-600">({durationLabel})</span> : null}
            </p>
            <p className="text-sm font-semibold text-slate-100">{title}</p>
            <div className="flex flex-wrap items-center gap-3 text-[11px] text-slate-500">
              <span className="flex items-center gap-1.5">
                <GraduationCap className="h-3 w-3 text-slate-500" />
                <span>{reservation.teacher?.name ?? "Öğretmen yok"}</span>
              </span>
              <span className="flex items-center gap-1.5">
                <User className="h-3 w-3 text-slate-500" />
                <span>{reservation.student?.name ?? "Öğrenci yok"}</span>
              </span>
              {reservation.category?.name ? (
                <span className="flex items-center gap-1.5">
                  <Calendar className="h-3 w-3 text-slate-500" />
                  <span>{reservation.category.name}</span>
                </span>
              ) : null}
            </div>
          </div>
          <div className="flex flex-col items-end gap-2">
            <Badge variant={reservationStatusBadge[status] ?? "secondary"} className="text-[11px]">
              {reservationStatusCopy[status] ?? status}
            </Badge>
            <div className="flex items-center gap-1">
              <Button
                type="button"
                size="icon"
                variant="ghost"
                className="h-8 w-8 text-slate-400 hover:text-slate-100"
                onClick={(event) => {
                  event.stopPropagation();
                  onOpenQuickEdit(reservation);
                }}
              >
                <Pencil className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>
        {reservation.is_reschedule_pending ? (
          <div className="flex items-center gap-2 rounded-lg border border-amber-400/30 bg-amber-500/10 px-3 py-2 text-[11px] text-amber-300">
            <AlertTriangle className="h-3.5 w-3.5" />
            <span>Yeniden planlama talebi bekliyor.</span>
          </div>
        ) : null}
        {reservation.admin_notes ? (
          <p className="line-clamp-2 text-[11px] text-slate-400">
            {reservation.admin_notes}
          </p>
        ) : null}
      </button>
    </div>
  );
}

type QuickEditDialogProps = {
  reservation: AdminReservation | null;
  dateValue: string;
  durationValue: string;
  statusValue: ReservationStatus;
  teacherNotesValue: string;
  notifyParticipants: boolean;
  onChangeDate: (value: string) => void;
  onChangeDuration: (value: string) => void;
  onChangeStatus: (value: ReservationStatus) => void;
  onChangeTeacherNotes: (value: string) => void;
  onToggleNotifyParticipants: (value: boolean) => void;
  onClose: () => void;
  onSave: () => void;
  isSaving: boolean;
};

function QuickEditDialog({
  reservation,
  dateValue,
  durationValue,
  statusValue,
  teacherNotesValue,
  notifyParticipants,
  onChangeDate,
  onChangeDuration,
  onChangeStatus,
  onChangeTeacherNotes,
  onToggleNotifyParticipants,
  onClose,
  onSave,
  isSaving,
}: QuickEditDialogProps) {
  return (
    <Dialog open={Boolean(reservation)} onOpenChange={(open) => (!open ? onClose() : null)}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle>Hızlı rezervasyon düzenleme</DialogTitle>
          <DialogDescription>
            Tarih, süre ve durum bilgilerini güncelleyin. Katılımcılar için bilgilendirme
            gönderimini isteğe bağlı olarak kapatabilirsiniz.
          </DialogDescription>
        </DialogHeader>

        {reservation ? (
          <div className="space-y-5">
            <div className="rounded-xl border border-slate-800/70 bg-slate-950/60 p-4 text-xs text-slate-400">
              <p className="font-medium text-slate-200">{reservation.subject ?? reservation.title}</p>
              <p className="mt-1">
                Öğretmen:{" "}
                <span className="text-slate-100">{reservation.teacher?.name ?? "Seçilmemiş"}</span>{" "}
                • Öğrenci:{" "}
                <span className="text-slate-100">{reservation.student?.name ?? "Seçilmemiş"}</span>
              </p>
              {reservation.category?.name ? (
                <p className="mt-1">Kategori: {reservation.category.name}</p>
              ) : null}
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="reservation-date">Tarih &amp; saat</Label>
                <Input
                  id="reservation-date"
                  type="datetime-local"
                  value={dateValue}
                  onChange={(event) => onChangeDate(event.target.value)}
                  disabled={isSaving}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="reservation-duration">Süre (dakika)</Label>
                <Input
                  id="reservation-duration"
                  type="number"
                  min={15}
                  step={5}
                  value={durationValue}
                  onChange={(event) => onChangeDuration(event.target.value)}
                  disabled={isSaving}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="reservation-status">Durum</Label>
                <select
                  id="reservation-status"
                  className="h-11 w-full rounded-lg border border-slate-800 bg-slate-900/80 px-3 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/70 disabled:cursor-not-allowed disabled:opacity-60"
                  value={statusValue}
                  onChange={(event) => onChangeStatus(event.target.value as ReservationStatus)}
                  disabled={isSaving}
                >
                  {Object.entries(reservationStatusCopy).map(([value, label]) => (
                    <option key={value} value={value}>
                      {label}
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-2">
                <Label>Katılımcı bilgilendirmesi</Label>
                <label className="flex h-11 cursor-pointer items-center gap-3 rounded-lg border border-slate-800/80 bg-slate-950/60 px-3 text-sm text-slate-300">
                  <input
                    type="checkbox"
                    className="h-4 w-4 rounded border-slate-700 bg-slate-900/80 text-sky-500 focus:ring-sky-500"
                    checked={notifyParticipants}
                    onChange={(event) => onToggleNotifyParticipants(event.target.checked)}
                    disabled={isSaving}
                  />
                  <span>Öğrenci ve öğretmene güncelleme bildirimi gönder</span>
                </label>
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="reservation-notes">Not</Label>
              <Textarea
                id="reservation-notes"
                value={teacherNotesValue}
                onChange={(event) => onChangeTeacherNotes(event.target.value)}
                placeholder="Öğretmen notu veya yönetici açıklaması ekleyin."
                rows={4}
                disabled={isSaving}
              />
            </div>

            <div className="flex flex-col gap-3 text-xs text-slate-500">
              <p>
                Hızlı düzenleme kaydedildiğinde takvim güncellenecek ve seçtiyseniz
                katılımcılara bilgilendirme gönderilecek.
              </p>
            </div>

            <div className="flex items-center justify-end gap-3">
              <Button
                type="button"
                variant="ghost"
                className="text-slate-400 hover:text-slate-100"
                onClick={onClose}
                disabled={isSaving}
              >
                Vazgeç
              </Button>
              <Button type="button" onClick={onSave} disabled={isSaving}>
                {isSaving ? "Kaydediliyor..." : "Kaydet"}
              </Button>
            </div>
          </div>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}

