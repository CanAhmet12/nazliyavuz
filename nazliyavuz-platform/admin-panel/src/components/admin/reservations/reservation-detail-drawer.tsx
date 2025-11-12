"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import type {
  AdminReservation,
  AdminRescheduleRequest,
  ReservationStatus,
  UpdateReservationStatusPayload,
  RefundReservationPayload,
  HandleReschedulePayload,
  AdminLesson,
  LessonSummary,
  ReminderSummary,
  ReminderPending,
  AdminReminderLog,
  ReminderWorkflowStep,
  ReservationRefund,
} from "@/lib/api/admin";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { format, formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";
import { Bell, Mail, MessageSquare, UserCheck, UserCircle2 } from "lucide-react";

type UpdatePayload = Omit<UpdateReservationStatusPayload, "reservationId">;
type RefundPayload = Omit<RefundReservationPayload, "reservationId">;
type ReschedulePayload = Omit<HandleReschedulePayload, "reservationId">;

type ReservationDetailDrawerProps = {
  reservation: AdminReservation | null;
  open: boolean;
  onClose: () => void;
  onUpdateStatus: (payload: UpdatePayload) => Promise<void>;
  isUpdating?: boolean;
  onRefund: (payload: RefundPayload) => Promise<void>;
  isRefunding?: boolean;
  onHandleReschedule: (payload: ReschedulePayload) => Promise<void>;
  isRescheduleProcessing?: boolean;
  rescheduleHistory?: AdminRescheduleRequest[];
};

const statusOptions: Array<{ value: ReservationStatus; label: string }> = [
  { value: "pending", label: "Beklemede" },
  { value: "accepted", label: "Onaylandı" },
  { value: "in_progress", label: "Ders devam ediyor" },
  { value: "completed", label: "Tamamlandı" },
  { value: "cancelled", label: "İptal edildi" },
];

export function ReservationDetailDrawer({
  reservation,
  open,
  onClose,
  onUpdateStatus,
  isUpdating,
  onRefund,
  isRefunding,
  onHandleReschedule,
  isRescheduleProcessing,
  rescheduleHistory,
}: ReservationDetailDrawerProps) {
  const history = reservation?.reschedule_history ?? rescheduleHistory ?? [];
  const lessons = reservation?.lessons ?? [];
  const lessonSummary = reservation?.lesson_summary ?? null;
  const hasLessons = lessons.length > 0;
  const reminderSummary: ReminderSummary | null = reservation?.reminder_summary ?? null;
  const reminderLogs = reservation?.reminder_logs ?? [];
  const [status, setStatus] = useState<ReservationStatus>("pending");
  const [teacherNotes, setTeacherNotes] = useState("");
  const [adminNotes, setAdminNotes] = useState("");
  const [notifyParticipants, setNotifyParticipants] = useState(true);
  const [cancellationReason, setCancellationReason] = useState("");
  const [refundAmount, setRefundAmount] = useState("");
  const [refundReason, setRefundReason] = useState("");
  const [cancelReservation, setCancelReservation] = useState(false);
  const [notifyRefundParticipants, setNotifyRefundParticipants] = useState(true);
  const [notifyRescheduleParticipants, setNotifyRescheduleParticipants] =
    useState(true);
  const [rescheduleRejectionReason, setRescheduleRejectionReason] = useState("");

  useEffect(() => {
    if (!reservation) {
      return;
    }

    const paymentBaseAmount =
      reservation.price ??
      reservation.payments?.find((payment) =>
        ["success", "processing", "refunded"].includes(payment.status),
      )?.amount ??
      0;

    const remainingRefundable = Math.max(
      paymentBaseAmount - (reservation.refund_amount ?? 0),
      0,
    );

    const defaultRefundValue =
      remainingRefundable > 0 ? remainingRefundable.toString() : "";

    Promise.resolve().then(() => {
      setStatus(reservation.status);
      setTeacherNotes(reservation.teacher_notes ?? "");
      setAdminNotes(reservation.admin_notes ?? "");
      setCancellationReason(reservation.cancelled_reason ?? "");
      setNotifyParticipants(true);
      setRefundAmount(defaultRefundValue);
      setRefundReason(reservation.refund_reason ?? "");
      setCancelReservation(reservation.status === "cancelled");
      setNotifyRefundParticipants(true);
      setNotifyRescheduleParticipants(true);
      setRescheduleRejectionReason(
        reservation.reschedule_request?.rejection_reason ?? "",
      );
    });
  }, [reservation]);

  const proposedDate = useMemo(() => {
    if (!reservation) {
      return null;
    }

    return (
      reservation.scheduled_at ??
      reservation.proposed_datetime ??
      reservation.created_at
    );
  }, [reservation]);

  const refundInfo = useMemo(() => {
    if (!reservation) {
      return {
        total: 0,
        refunded: 0,
        remaining: 0,
        currency: "TRY",
      };
    }

    const candidatePayment = reservation.payments?.find((payment) =>
      ["success", "processing", "refunded"].includes(payment.status),
    );

    const total =
      reservation.price ?? candidatePayment?.amount ?? 0;

    const refunded = reservation.refund_amount ?? 0;
    const remaining = Math.max(total - refunded, 0);
    const currency =
      reservation.currency ?? candidatePayment?.currency ?? "TRY";

    return {
      total,
      refunded,
      remaining,
      currency,
    };
  }, [reservation]);

  const refundAmountValue = Number(refundAmount || 0);
  const refundEligible =
    reservation &&
    reservation.payment_status === "paid";
  const refunds = (reservation?.refunds ?? []).slice().sort((a, b) => {
    const dateA = a.created_at ? new Date(a.created_at).getTime() : 0;
    const dateB = b.created_at ? new Date(b.created_at).getTime() : 0;
    return dateB - dateA;
  });
  const hasPendingRefund = refunds.some((refund) =>
    ["pending", "processing"].includes(refund.status),
  );
  const canRefund =
    !!refundEligible &&
    refundInfo.remaining > 0 &&
    refundAmountValue > 0 &&
    refundAmountValue <= refundInfo.remaining &&
    !hasPendingRefund;
  const showRefundSection = refundInfo.total > 0;
  const reschedule = reservation?.reschedule_request ?? null;
  const rescheduleStatus = reschedule?.status ?? "none";
  const reschedulePending = rescheduleStatus === "pending";
  const hasReschedule = Boolean(reschedule);

  const canSubmit = useMemo(() => {
    if (!reservation) {
      return false;
    }

    const hasStatusChange = status !== reservation.status;
    const hasTeacherNotesChange =
      (reservation.teacher_notes ?? "") !== teacherNotes;
    const hasAdminNotesChange =
      (reservation.admin_notes ?? "") !== adminNotes;
    const cancellationRequested =
      status === "cancelled"
        ? reservation.status === "cancelled" ||
          cancellationReason.trim().length > 0
        : true;

    return (
      cancellationRequested &&
      (hasStatusChange || hasTeacherNotesChange || hasAdminNotesChange)
    );
  }, [reservation, status, teacherNotes, adminNotes, cancellationReason]);

  if (!reservation) {
    return null;
  }

  const handleSubmit = async () => {
    if (!canSubmit) {
      return;
    }

    await onUpdateStatus({
      status,
      notify_participants: notifyParticipants,
      teacher_notes:
        teacherNotes.trim().length > 0 ? teacherNotes.trim() : null,
      admin_notes: adminNotes.trim().length > 0 ? adminNotes.trim() : null,
      cancellation_reason:
        status === "cancelled"
          ? cancellationReason.trim().length > 0
            ? cancellationReason.trim()
            : null
          : null,
    });
  };

  const handleRefund = async () => {
    if (!reservation || !canRefund) {
      return;
    }

    await onRefund({
      refund_amount: refundAmountValue,
      reason: refundReason.trim() ? refundReason.trim() : undefined,
      notify_participants: notifyRefundParticipants,
      cancel_reservation: cancelReservation,
    });

    setRefundAmount("");
    setRefundReason("");
  };

  const handleRescheduleActionInternal = async (
    action: "approve" | "reject" | "clear",
  ) => {
    if (!hasReschedule || !reservation) {
      return;
    }

    if (action === "reject" && rescheduleRejectionReason.trim().length === 0) {
      return;
    }

    await onHandleReschedule({
      action,
      notify_participants: notifyRescheduleParticipants,
      rejection_reason:
        action === "reject"
          ? rescheduleRejectionReason.trim()
          : undefined,
    });
  };

  return (
    <Dialog open={open} onOpenChange={(value) => !value && onClose()}>
      <DialogContent className="top-0 right-0 h-screen max-w-lg translate-x-1/2 translate-y-0 overflow-hidden rounded-none border-l border-slate-800/80 bg-slate-950/95 p-0 sm:max-w-lg">
        <div className="flex h-full flex-col">
          <DialogHeader className="border-b border-slate-800/70 px-6 py-4">
            <DialogTitle>Rezervasyon Detayı</DialogTitle>
            <DialogDescription>
              Ders rezervasyonu ve aksiyon yönetimi
            </DialogDescription>
          </DialogHeader>

          <div className="flex-1 space-y-6 overflow-y-auto px-6 py-6">
            <section className="space-y-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <h3 className="text-lg font-semibold text-slate-100">
                    {reservation.title ??
                      reservation.subject ??
                      reservation.category?.name ??
                      `Rezervasyon #${reservation.id}`}
                  </h3>
                  <p className="text-xs text-slate-500">
                    #{reservation.id} •{" "}
                    {proposedDate ? formatDate(proposedDate, "d MMM yyyy HH:mm") : "-"}
                  </p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Badge variant={statusVariant[reservation.status]}>
                    {statusCopy[reservation.status]}
                  </Badge>
                  {reservation.payment_status && (
                    <Badge variant={paymentStatusVariant[reservation.payment_status] ?? "default"}>
                      {paymentStatusCopy[reservation.payment_status] ??
                        reservation.payment_status}
                    </Badge>
                  )}
                </div>
              </div>
              <p className="text-sm text-slate-300">
                {reservation.category?.name ?? "Kategori belirtilmedi"}
              </p>
            </section>

            <section className="space-y-3 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4 text-sm text-slate-200">
              <InfoRow label="Ders konusu">
                {reservation.subject ?? reservation.title ?? "Belirtilmemiş"}
              </InfoRow>
              <InfoRow label="Ders süresi">
                {reservation.duration_minutes
                  ? `${reservation.duration_minutes} dk`
                  : "-"}
              </InfoRow>
              <InfoRow label="Ücret">
                {typeof reservation.price === "number"
                  ? `${reservation.price.toFixed(2)} ${reservation.currency ?? "TRY"}`
                  : "Belirtilmemiş"}
              </InfoRow>
              <InfoRow label="Planlanan tarih">
                {proposedDate ? formatDate(proposedDate) : "Belirtilmemiş"}
              </InfoRow>
              <InfoRow label="Oluşturma tarihi">
                {formatDate(reservation.created_at)}
              </InfoRow>
            </section>

            <section className="space-y-4">
              <ParticipantCard
                title="Öğrenci"
                name={reservation.student?.name ?? "Bilinmiyor"}
                email={reservation.student?.email ?? "—"}
                accent="student"
              />
              <ParticipantCard
                title="Öğretmen"
                name={reservation.teacher?.name ?? "Bilinmiyor"}
                email={reservation.teacher?.email ?? "—"}
                accent="teacher"
              />
            </section>

            <section className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4">
              <div className="space-y-2">
                <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                  Rezervasyon durumu
                </label>
                <select
                  className="w-full rounded-lg border border-slate-800 bg-slate-950 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
                  value={status}
                  onChange={(event) =>
                    setStatus(event.target.value as ReservationStatus)
                  }
                >
                  {statusOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>

              {status === "cancelled" && (
                <div className="space-y-2">
                  <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                    İptal nedeni
                  </label>
                  <Input
                    placeholder="Bu iptal işlemi neden yapılıyor?"
                    value={cancellationReason}
                    onChange={(event) => setCancellationReason(event.target.value)}
                  />
                </div>
              )}

              <div className="space-y-2">
                <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                  Öğretmen notu
                </label>
                <Textarea
                  placeholder="Öğretmen tarafından görüntülenecek not"
                  value={teacherNotes}
                  onChange={(event) => setTeacherNotes(event.target.value)}
                  rows={3}
                />
              </div>

              <div className="space-y-2">
                <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                  Admin notu
                </label>
                <Textarea
                  placeholder="Sadece adminler tarafından görüntülenir"
                  value={adminNotes}
                  onChange={(event) => setAdminNotes(event.target.value)}
                  rows={3}
                />
              </div>

              <div className="flex items-center justify-between rounded-xl border border-slate-800/70 bg-slate-950/70 px-4 py-3">
                <span className="text-sm text-slate-300">Katılımcılara bildir</span>
                <label className="flex items-center gap-2 text-xs text-slate-400">
                  <input
                    type="checkbox"
                    className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-sky-500 focus:ring-sky-500"
                    checked={notifyParticipants}
                    onChange={(event) => setNotifyParticipants(event.target.checked)}
                  />
                  Bildirim gönder
                </label>
              </div>

              <div className="flex justify-end">
                <Button
                  onClick={handleSubmit}
                  disabled={isUpdating || !canSubmit}
                >
                  {isUpdating ? "Güncelleniyor..." : "Durumu güncelle"}
                </Button>
              </div>
            </section>

            {hasReschedule && (
              <section className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h4 className="text-sm font-semibold text-slate-200">
                    Yeniden planlama talebi
                  </h4>
                  <Badge variant={rescheduleStatusVariant[rescheduleStatus] ?? "default"}>
                    {rescheduleStatusCopy[rescheduleStatus] ?? rescheduleStatus}
                  </Badge>
                </div>

                <InfoRow label="Mevcut tarih">
                  {reschedule?.old_datetime
                    ? formatDate(reschedule.old_datetime)
                    : proposedDate
                      ? formatDate(proposedDate)
                      : "-"}
                </InfoRow>
                <InfoRow label="Talep edilen yeni tarih">
                  {reschedule?.new_datetime ? formatDate(reschedule.new_datetime) : "-"}
                </InfoRow>
                <InfoRow label="Talep tarihi">
                  {reschedule?.requested_at ? formatDate(reschedule.requested_at) : "-"}
                </InfoRow>

                <NoteBox title="Talep gerekçesi" value={reschedule?.reason} />

                {reschedulePending ? (
                  <div className="space-y-3">
                    <div className="flex flex-col gap-3 rounded-xl border border-slate-800/70 bg-slate-950/60 px-4 py-3 text-xs text-slate-400 md:flex-row md:items-center md:justify-between">
                      <label className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-sky-500 focus:ring-sky-500"
                          checked={notifyRescheduleParticipants}
                          onChange={(event) =>
                            setNotifyRescheduleParticipants(event.target.checked)
                          }
                        />
                        Katılımcıları bilgilendir
                      </label>
                    </div>

                    <div className="space-y-2">
                      <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                        Reddetme nedeni
                      </label>
                      <Textarea
                        placeholder="Talebi reddetmek isterseniz nedeni belirtin"
                        value={rescheduleRejectionReason}
                        onChange={(event) => setRescheduleRejectionReason(event.target.value)}
                        rows={3}
                      />
                    </div>

                    <div className="flex flex-wrap items-center justify-end gap-2">
                      <Button
                        variant="ghost"
                        disabled={isRescheduleProcessing}
                        onClick={() => handleRescheduleActionInternal("clear")}
                      >
                        Temizle
                      </Button>
                      <Button
                        variant="destructive"
                        disabled={
                          isRescheduleProcessing ||
                          rescheduleRejectionReason.trim().length === 0
                        }
                        onClick={() => handleRescheduleActionInternal("reject")}
                      >
                        {isRescheduleProcessing ? "İşleniyor..." : "Reddet"}
                      </Button>
                      <Button
                        disabled={isRescheduleProcessing}
                        onClick={() => handleRescheduleActionInternal("approve")}
                      >
                        {isRescheduleProcessing ? "İşleniyor..." : "Onayla"}
                      </Button>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {reschedule?.handled_at && (
                      <InfoRow label="İşleme alınma tarihi">
                        {formatDate(reschedule.handled_at)}
                      </InfoRow>
                    )}
                    {reschedule?.rejection_reason && (
                      <NoteBox title="Reddetme nedeni" value={reschedule.rejection_reason} />
                    )}
                    <div className="flex items-center justify-between rounded-xl border border-slate-800/70 bg-slate-950/60 px-4 py-3 text-xs text-slate-400">
                      <span>Talebi listeden kaldır</span>
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={isRescheduleProcessing}
                        onClick={() => handleRescheduleActionInternal("clear")}
                      >
                        Sil
                      </Button>
                    </div>
                  </div>
                )}
              </section>
            )}

            {showRefundSection && (
              <section className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4">
                <div className="space-y-2">
                  <h4 className="text-sm font-semibold text-slate-200">Ödeme ve iade</h4>
                  <InfoRow label="Toplam ücret">
                    {formatCurrencyValue(refundInfo.total, refundInfo.currency)}
                  </InfoRow>
                  <InfoRow label="İade edilen">
                    {formatCurrencyValue(refundInfo.refunded, refundInfo.currency)}
                  </InfoRow>
                  <InfoRow label="Kalan iade">
                    {formatCurrencyValue(refundInfo.remaining, refundInfo.currency)}
                  </InfoRow>
                </div>

                {hasPendingRefund ? (
                  <div className="rounded-xl border border-amber-500/40 bg-amber-500/10 px-4 py-3 text-xs text-amber-100">
                    Devam eden bir iade talebi bulunuyor. Yeni bir talep oluşturmak için mevcut
                    talebin tamamlanmasını bekleyin.
                  </div>
                ) : null}

                {refundEligible ? (
                  refundInfo.remaining > 0 ? (
                    <>
                      <div className="space-y-2">
                        <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                          İade tutarı
                        </label>
                        <Input
                          type="number"
                          min={0}
                          step="0.01"
                          value={refundAmount}
                          onChange={(event) => setRefundAmount(event.target.value)}
                        />
                        <p className="text-xs text-slate-500">
                          Maksimum {formatCurrencyValue(refundInfo.remaining, refundInfo.currency)} iade edebilirsiniz.
                        </p>
                      </div>

                      <div className="space-y-2">
                        <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                          İade nedeni
                        </label>
                        <Textarea
                          placeholder="İade işlemi hakkında kısa bir açıklama"
                          value={refundReason}
                          onChange={(event) => setRefundReason(event.target.value)}
                          rows={3}
                        />
                      </div>

                      <div className="flex flex-col gap-3 rounded-xl border border-slate-800/70 bg-slate-950/60 px-4 py-3 text-xs text-slate-400 md:flex-row md:items-center md:justify-between">
                        <label className="flex items-center gap-2">
                          <input
                            type="checkbox"
                            className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-sky-500 focus:ring-sky-500"
                            checked={notifyRefundParticipants}
                            onChange={(event) => setNotifyRefundParticipants(event.target.checked)}
                          />
                          Katılımcıları bilgilendir
                        </label>
                        <label className="flex items-center gap-2">
                          <input
                            type="checkbox"
                            className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-sky-500 focus:ring-sky-500"
                            checked={cancelReservation}
                            onChange={(event) => setCancelReservation(event.target.checked)}
                          />
                          Rezervasyonu iptal et
                        </label>
                      </div>

                      <div className="flex justify-end">
                        <Button
                          variant="secondary"
                          onClick={handleRefund}
                          disabled={isRefunding || !canRefund}
                        >
                          {isRefunding ? "İade yapılıyor..." : "İade yap"}
                        </Button>
                      </div>
                    </>
                  ) : (
                    <p className="text-xs text-slate-500">
                      İade edilecek tutar kalmadı.
                    </p>
                  )
                ) : (
                  <p className="text-xs text-slate-500">
                    Bu rezervasyonun ödeme durumu iade için uygun değil.
                  </p>
                )}

                <RefundHistory refunds={refunds} />
              </section>
            )}

            <section className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h4 className="text-sm font-semibold text-slate-200">Ders kayıtları</h4>
                <Badge variant="info">
                  {lessonSummary?.total ?? 0} ders
                </Badge>
              </div>
              {lessonSummary ? <LessonSummaryGrid summary={lessonSummary} /> : null}
              {hasLessons ? (
                <div className="space-y-3">
                  {lessons.map((lesson) => (
                    <LessonCard key={lesson.id} lesson={lesson} />
                  ))}
                </div>
              ) : (
                <p className="text-xs text-slate-500">
                  Bu rezervasyona bağlı ders kaydı bulunmuyor. Öğretmen veya öğrenci ders
                  oluşturduğunda burada görüntülenecek.
                </p>
              )}
            </section>

            <section className="space-y-3 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h4 className="text-sm font-semibold text-slate-200">Hatırlatma durumu</h4>
                <Badge variant="info">
                  {(reminderSummary?.total_sent ?? 0).toString()} gönderim
                </Badge>
              </div>
              {reminderSummary ? (
                <div className="space-y-3">
                  <InfoRow label="Son gönderim">
                    {reminderSummary.last_sent_at
                      ? `${formatDate(reminderSummary.last_sent_at)} (${formatRelativeFromNow(reminderSummary.last_sent_at)})`
                      : "Henüz gönderilmedi"}
                  </InfoRow>
                  <ReminderChannelRow channels={reminderSummary.last_channels ?? []} />
                  {reminderSummary.pending?.length ? (
                    <PendingReminderList pending={reminderSummary.pending} />
                  ) : null}
                </div>
              ) : (
                <p className="text-xs text-slate-500">
                  Hatırlatma özeti mevcut değil. Otomatik hatırlatma kuralları tanımlandığında burada
                  görüntülenir.
                </p>
              )}
              <ReminderLogList logs={reminderLogs} />
            </section>

            <section className="space-y-3 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4">
              <h4 className="text-sm font-semibold text-slate-200">Referans notlar</h4>
              <NoteBox title="Öğrenci notu" value={reservation.notes} />
              <NoteBox title="Mevcut öğretmen notu" value={reservation.teacher_notes} />
              <NoteBox title="Mevcut admin notu" value={reservation.admin_notes} />
              {reservation.refund_amount ? (
                <NoteBox
                  title="Toplam iade"
                  value={formatCurrencyValue(
                    reservation.refund_amount,
                    refundInfo.currency,
                  )}
                />
              ) : null}
              {reservation.refund_reason ? (
                <NoteBox title="Son iade nedeni" value={reservation.refund_reason} />
              ) : null}
              {reservation.cancelled_reason && (
                <NoteBox
                  title="Son iptal nedeni"
                  value={reservation.cancelled_reason}
                />
              )}
            </section>

            <section className="space-y-3">
              <Accordion type="single" collapsible className="w-full">
                <AccordionItem value="reschedule-history">
                  <AccordionTrigger className="text-sm font-semibold text-slate-200">
                    Yeniden planlama geçmişi
                  </AccordionTrigger>
                  <AccordionContent>
                    <RescheduleHistory history={history} />
                  </AccordionContent>
                </AccordionItem>
              </Accordion>
            </section>
          </div>

          <div className="border-t border-slate-800/70 px-6 py-3 text-right">
            <button
              type="button"
              className="text-xs font-medium text-slate-400 hover:text-slate-200"
              onClick={onClose}
            >
              Kapat
            </button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

function InfoRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between text-xs">
      <span className="text-slate-500">{label}</span>
      <span className="font-medium text-slate-200">{children}</span>
    </div>
  );
}

function ParticipantCard({
  title,
  name,
  email,
  accent,
}: {
  title: string;
  name: string;
  email: string;
  accent: "student" | "teacher";
}) {
  const bg =
    accent === "student" ? "bg-sky-500/10 text-sky-200" : "bg-emerald-500/10 text-emerald-200";
  return (
    <div className="rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4">
      <p className={`inline-flex items-center rounded-full px-2 py-1 text-[11px] ${bg}`}>
        {title}
      </p>
      <p className="mt-2 text-sm font-medium text-slate-100">{name}</p>
      <p className="text-xs text-slate-500">{email}</p>
    </div>
  );
}

function NoteBox({ title, value }: { title: string; value?: string | null }) {
  return (
    <div className="rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4">
      <p className="text-xs font-semibold text-slate-400">{title}</p>
      <p className="mt-2 text-sm text-slate-200">
        {value && value.trim().length > 0 ? value : "—"}
      </p>
    </div>
  );
}

function LessonSummaryGrid({ summary }: { summary: LessonSummary }) {
  return (
    <div className="grid grid-cols-2 gap-3 text-xs md:grid-cols-4">
      <LessonSummaryItem label="Toplam ders" value={summary.total} />
      <LessonSummaryItem label="Tamamlanan" value={summary.completed} />
      <LessonSummaryItem label="Devam eden" value={summary.in_progress} />
      <LessonSummaryItem label="Planlanan" value={summary.upcoming} />
      <LessonSummaryItem
        label="Son ders"
        value={formatRelativeFromNow(summary.last_lesson_at)}
      />
      <LessonSummaryItem
        label="Sonraki ders"
        value={formatRelativeFromNow(summary.next_lesson_at)}
      />
    </div>
  );
}

function LessonSummaryItem({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-xl border border-slate-800/70 bg-slate-950/70 p-3">
      <p className="text-[11px] uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-1 text-base font-semibold text-slate-200">{value}</p>
    </div>
  );
}

function LessonCard({ lesson }: { lesson: AdminLesson }) {
  const statusLabel = lessonStatusCopy[lesson.status] ?? lesson.status;
  const badgeVariant = lessonStatusVariant[lesson.status] ?? "default";

  return (
    <div className="space-y-3 rounded-2xl border border-slate-800/70 bg-slate-950/60 p-4 text-xs text-slate-300">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <p className="text-sm font-semibold text-slate-100">Ders #{lesson.id}</p>
          <p className="text-[11px] text-slate-500">
            {lesson.scheduled_at ? formatDate(lesson.scheduled_at) : "Planlanmadı"}{" "}
            {lesson.scheduled_at ? `(${formatRelativeFromNow(lesson.scheduled_at)})` : ""}
          </p>
        </div>
        <Badge variant={badgeVariant}>{statusLabel}</Badge>
      </div>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        <LessonInfo label="Öğretmen" value={lesson.teacher?.name ?? "—"} />
        <LessonInfo label="Öğrenci" value={lesson.student?.name ?? "—"} />
        <LessonInfo
          label="Süre"
          value={lesson.formatted_duration ?? formatDuration(lesson.duration_minutes)}
        />
        <LessonInfo
          label="Başlangıç"
          value={lesson.started_at ? formatDate(lesson.started_at) : "—"}
        />
        <LessonInfo
          label="Bitiş"
          value={lesson.ended_at ? formatDate(lesson.ended_at) : "—"}
        />
        <LessonInfo
          label="Değerlendirme"
          value={
            typeof lesson.rating === "number"
              ? `${lesson.rating.toFixed(1)} / 5`
              : lesson.can_be_rated
                ? "Değerlendirme bekleniyor"
                : "—"
          }
        />
      </div>

      {lesson.notes ? (
        <div className="rounded-xl border border-slate-800/70 bg-slate-950/80 p-3 text-[11px] leading-relaxed text-slate-300">
          <span className="block font-semibold uppercase tracking-wide text-slate-500">
            Ders notu
          </span>
          {lesson.notes}
        </div>
      ) : null}

      {lesson.feedback ? (
        <div className="rounded-xl border border-slate-800/70 bg-slate-950/80 p-3 text-[11px] leading-relaxed text-slate-300">
          <span className="block font-semibold uppercase tracking-wide text-slate-500">
            Geri bildirim
          </span>
          {lesson.feedback}
        </div>
      ) : null}
    </div>
  );
}

function LessonInfo({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-1 rounded-xl border border-slate-800/70 bg-slate-950/80 p-3">
      <span className="text-[11px] uppercase tracking-wide text-slate-500">{label}</span>
      <span className="text-sm font-medium text-slate-100">{value}</span>
    </div>
  );
}

function ReminderChannelRow({
  channels,
}: {
  channels: string[] | ReminderWorkflowStep["channels"];
}) {
  const channelList = Array.isArray(channels)
    ? channels
    : (["student", "teacher"] as const)
        .flatMap((audience) =>
          (["push", "email", "sms"] as const)
            .filter((channel) => channels[audience][channel]?.enabled)
            .map((channel) => `${audience}_${channel}`),
        );

  if (!channelList.length) {
    return null;
  }

  return (
    <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-400">
      <span className="uppercase tracking-wide text-slate-500">Kanallar:</span>
      {channelList.map((channel) => (
        <ChannelTag key={channel} channel={channel} />
      ))}
    </div>
  );
}

function ChannelTag({ channel }: { channel: string }) {
  const iconMap: Record<string, ReactNode> = {
    student_push: <UserCircle2 className="h-3 w-3 text-sky-400" />,
    student_email: <Mail className="h-3 w-3 text-amber-400" />,
    student_sms: <MessageSquare className="h-3 w-3 text-emerald-400" />,
    teacher_push: <UserCheck className="h-3 w-3 text-emerald-400" />,
    teacher_email: <Mail className="h-3 w-3 text-purple-300" />,
    teacher_sms: <MessageSquare className="h-3 w-3 text-purple-300" />,
    email: <Mail className="h-3 w-3 text-amber-400" />,
    push: <Bell className="h-3 w-3 text-sky-400" />,
    sms: <MessageSquare className="h-3 w-3 text-emerald-400" />,
  };

  const labelMap: Record<string, string> = {
    student_push: "Öğrenci push",
    student_email: "Öğrenci e-posta",
    student_sms: "Öğrenci SMS",
    teacher_push: "Öğretmen push",
    teacher_email: "Öğretmen e-posta",
    teacher_sms: "Öğretmen SMS",
    email: "E-posta",
    push: "Push bildirimi",
    sms: "SMS",
  };

  return (
    <span className="inline-flex items-center gap-1 rounded-full border border-slate-800/70 bg-slate-950/70 px-2 py-1">
      {iconMap[channel] ?? <Bell className="h-3 w-3 text-slate-400" />}
      {labelMap[channel] ?? channel}
    </span>
  );
}

function PendingReminderList({ pending }: { pending: ReminderPending[] }) {
  return (
    <div className="space-y-2 rounded-xl border border-slate-800/60 bg-slate-950/60 p-3 text-xs text-slate-300">
      <p className="text-[11px] uppercase tracking-wide text-slate-500">
        Bekleyen hatırlatmalar
      </p>
      <div className="space-y-2">
        {pending.map((item) => (
          <div
            key={item.id}
            className="rounded-lg border border-slate-800/70 bg-slate-950/70 p-3"
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="font-medium text-slate-100">{item.name}</span>
              <span className="text-[11px] text-slate-500">
                {item.scheduled_for
                  ? `${formatDate(item.scheduled_for)} (${formatRelativeFromNow(item.scheduled_for)})`
                  : "Takvimlendirilmemiş"}
              </span>
            </div>
            <div className="mt-2">
              <ReminderChannelRow channels={item.channels} />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function ReminderLogList({ logs }: { logs: AdminReminderLog[] }) {
  if (!logs.length) {
    return (
      <p className="text-[11px] text-slate-500">
        Henüz hatırlatma gönderilmedi.
      </p>
    );
  }

  return (
    <div className="space-y-2 rounded-xl border border-slate-800/60 bg-slate-950/60 p-3 text-xs text-slate-300">
      <p className="text-[11px] uppercase tracking-wide text-slate-500">
        Son gönderimler
      </p>
      <div className="space-y-2">
        {logs.map((log) => (
          <div
            key={log.id}
            className="rounded-lg border border-slate-800/70 bg-slate-950/70 p-3"
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="font-medium text-slate-100">
                {log.setting?.name ?? "Manuel hatırlatma"}
              </span>
              <span className="text-[11px] text-slate-500">
                {log.sent_at
                  ? `${formatDate(log.sent_at)} (${formatRelativeFromNow(log.sent_at)})`
                  : "Tarih bilgisi yok"}
              </span>
            </div>
            <div className="mt-2 flex flex-wrap items-center gap-2 text-[11px] text-slate-500">
              <Badge variant={log.source === "automatic" ? "info" : "default"}>
                {log.source === "automatic" ? "Otomatik" : "Manuel"}
              </Badge>
              <ReminderChannelRow channels={log.channels ?? []} />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function RescheduleHistory({ history }: { history: AdminRescheduleRequest[] }) {
  if (!history.length) {
    return (
      <p className="text-xs text-slate-500">
        Yeniden planlama geçmişi bulunmuyor.
      </p>
    );
  }

  return (
    <div className="space-y-3">
      {history.map((item, index) => (
        <div
          key={`${item.requested_at ?? index}-${item.status ?? index}`}
          className="rounded-xl border border-slate-800/60 bg-slate-950/70 p-4 text-xs text-slate-300"
        >
          <div className="flex items-center justify-between gap-3">
            <span className="font-semibold text-slate-100">
              {item.status === "approved"
                ? "Onaylandı"
                : item.status === "rejected"
                  ? "Reddedildi"
                  : "Talep edildi"}
            </span>
            <span className="text-[11px] text-slate-500">
              {item.handled_at
                ? formatDate(item.handled_at)
                : item.requested_at
                  ? formatDate(item.requested_at)
                  : "-"}
            </span>
          </div>
          <div className="mt-2 space-y-1">
            <p>
              <span className="text-slate-500">Yeni tarih:</span>{" "}
              {item.new_datetime ? formatDate(item.new_datetime) : "—"}
            </p>
            <p>
              <span className="text-slate-500">Talep eden:</span>{" "}
              {item.requested_by ?? "Bilinmiyor"}
            </p>
            {item.reason ? (
              <p>
                <span className="text-slate-500">Talep nedeni:</span> {item.reason}
              </p>
            ) : null}
            {item.rejection_reason ? (
              <p>
                <span className="text-slate-500">Reddetme nedeni:</span>{" "}
                {item.rejection_reason}
              </p>
            ) : null}
          </div>
        </div>
      ))}
    </div>
  );
}

function RefundHistory({ refunds }: { refunds: ReservationRefund[] }) {
  if (!refunds.length) {
    return (
      <p className="text-xs text-slate-500">
        Henüz iade işlemi kaydedilmemiş. Yukarıdan yeni iade talebi oluşturabilirsiniz.
      </p>
    );
  }

  return (
    <div className="space-y-3 rounded-2xl border border-slate-800/60 bg-slate-950/60 p-4 text-xs text-slate-300">
      <h5 className="text-sm font-semibold text-slate-200">İade geçmişi</h5>
      <div className="space-y-3">
        {refunds.map((refund) => (
          <div
            key={refund.id}
            className="space-y-2 rounded-xl border border-slate-800/60 bg-slate-950/70 p-3"
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="space-y-1">
                <p className="text-sm font-semibold text-slate-100">
                  {formatCurrencyValue(refund.amount, refund.currency)}
                </p>
                <p className="text-[11px] text-slate-500">
                  Talep tarihi:{" "}
                  {refund.created_at ? formatDate(refund.created_at) : "—"} •{" "}
                  {refund.created_at ? formatRelativeFromNow(refund.created_at) : "—"}
                </p>
                <p className="text-[11px] text-slate-500">
                  Durum:{" "}
                  <Badge variant={refundStatusVariant[refund.status] ?? "default"}>
                    {refundStatusCopy[refund.status] ?? refund.status}
                  </Badge>
                  {refund.processed_at ? (
                    <span className="ml-2">
                      Tamamlandı: {formatDate(refund.processed_at)} (
                      {formatRelativeFromNow(refund.processed_at)})
                    </span>
                  ) : null}
                </p>
              </div>
              <div className="text-right text-[11px] text-slate-500">
                {refund.created_by ? (
                  <p>
                    <span className="text-slate-400">Oluşturan:</span>{" "}
                    {refund.created_by.name}
                  </p>
                ) : null}
                {refund.payment?.paytr_order_id ? (
                  <p>
                    <span className="text-slate-400">PAYTR OID:</span>{" "}
                    {refund.payment.paytr_order_id}
                  </p>
                ) : null}
              </div>
            </div>

            {refund.reason ? (
              <div className="rounded-lg border border-slate-800/60 bg-slate-950/60 p-3 text-[11px] text-slate-300">
                <span className="font-semibold uppercase tracking-wide text-slate-500">
                  İade nedeni
                </span>
                <p className="mt-1 text-slate-300">{refund.reason}</p>
              </div>
            ) : null}

            {refund.failure_message && refund.status === "failed" ? (
              <div className="rounded-lg border border-rose-500/40 bg-rose-500/10 p-3 text-[11px] text-rose-200">
                <span className="font-semibold uppercase tracking-wide text-rose-300">
                  Hata
                </span>
                <p className="mt-1">
                  {refund.failure_message}
                  {refund.failure_code ? ` (${refund.failure_code})` : ""}
                </p>
              </div>
            ) : null}

            {refund.provider?.response ? (
              <details className="rounded-lg border border-slate-800/60 bg-slate-950/60 p-3 text-[11px] text-slate-400">
                <summary className="cursor-pointer text-slate-300">
                  Sağlayıcı yanıtı
                </summary>
                <pre className="mt-2 overflow-x-auto rounded-lg bg-slate-900/80 p-3 text-[10px] leading-relaxed text-slate-300">
                  {JSON.stringify(refund.provider.response, null, 2)}
                </pre>
              </details>
            ) : refund.provider?.name ? (
              <p className="text-[11px] text-slate-500">
                Sağlayıcı: {refund.provider.name}
                {refund.provider.reference ? ` • Referans: ${refund.provider.reference}` : ""}
              </p>
            ) : null}

            {refund.attempts > 1 ? (
              <p className="text-[11px] text-slate-500">
                Deneme sayısı: {refund.attempts}/{refund.max_attempts}
              </p>
            ) : null}
          </div>
        ))}
      </div>
    </div>
  );
}

const statusCopy: Record<ReservationStatus, string> = {
  pending: "Beklemede",
  accepted: "Onaylandı",
  in_progress: "Ders devam ediyor",
  completed: "Tamamlandı",
  cancelled: "İptal edildi",
};

const statusVariant: Record<
  ReservationStatus,
  "info" | "success" | "warning" | "destructive"
> = {
  pending: "info",
  accepted: "success",
  in_progress: "info",
  completed: "success",
  cancelled: "destructive",
};

const rescheduleStatusCopy: Record<string, string> = {
  pending: "Beklemede",
  approved: "Onaylandı",
  rejected: "Reddedildi",
};

const rescheduleStatusVariant: Record<
  string,
  "default" | "info" | "success" | "warning" | "destructive"
> = {
  pending: "info",
  approved: "success",
  rejected: "destructive",
};

const lessonStatusCopy: Record<string, string> = {
  scheduled: "Planlandı",
  in_progress: "Devam ediyor",
  completed: "Tamamlandı",
  cancelled: "İptal edildi",
};

const lessonStatusVariant: Record<
  string,
  "default" | "info" | "success" | "warning" | "destructive"
> = {
  scheduled: "info",
  in_progress: "info",
  completed: "success",
  cancelled: "destructive",
};

const paymentStatusCopy: Record<string, string> = {
  awaiting_payment: "Ödeme bekleniyor",
  paid: "Ödendi",
  refunded: "İade edildi",
  failed: "Başarısız",
};

const paymentStatusVariant: Record<
  string,
  "info" | "success" | "warning" | "destructive"
> = {
  awaiting_payment: "warning",
  paid: "success",
  refunded: "info",
  failed: "destructive",
};

const refundStatusCopy: Record<ReservationRefund["status"], string> = {
  pending: "Beklemede",
  processing: "İşleniyor",
  completed: "Tamamlandı",
  failed: "Başarısız",
  cancelled: "İptal edildi",
};

const refundStatusVariant: Record<
  ReservationRefund["status"],
  "info" | "success" | "warning" | "destructive" | "default"
> = {
  pending: "info",
  processing: "info",
  completed: "success",
  failed: "destructive",
  cancelled: "default",
};

function formatDate(value: string, template = "d MMM yyyy HH:mm") {
  try {
    return format(new Date(value), template, { locale: tr });
  } catch {
    return "-";
  }
}

function formatCurrencyValue(amount: number, currency: string) {
  try {
    return new Intl.NumberFormat("tr-TR", {
      style: "currency",
      currency,
      minimumFractionDigits: 2,
    }).format(amount);
  } catch {
    return `${amount.toFixed(2)} ${currency}`;
  }
}

function formatRelativeFromNow(value?: string | null) {
  if (!value) {
    return "—";
  }

  try {
    return formatDistanceToNow(new Date(value), { addSuffix: true, locale: tr });
  } catch {
    return "—";
  }
}

function formatDuration(duration?: number | null) {
  if (typeof duration !== "number") {
    return "—";
  }

  const hours = Math.floor(duration / 60);
  const minutes = duration % 60;

  if (hours > 0) {
    return `${hours} sa ${minutes} dk`;
  }

  return `${minutes} dk`;
}

