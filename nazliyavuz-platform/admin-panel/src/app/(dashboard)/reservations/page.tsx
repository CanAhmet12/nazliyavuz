"use client";

import { useEffect, useMemo, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import {
  CalendarClock,
  RefreshCcw,
  Search,
  User,
  CheckSquare,
  Undo2,
  BellRing,
  Ban,
} from "lucide-react";
import { useAdminReservations, reservationsQueryKey } from "@/hooks/use-admin-reservations";
import { ReservationsTable } from "@/components/admin/reservations/reservations-table";
import { ReservationReminderSettingsCard } from "@/components/admin/reservations/reservation-reminder-settings-card";
import { ReservationDetailDrawer } from "@/components/admin/reservations/reservation-detail-drawer";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type {
  AdminReservation,
  AdminReservationsFilters,
  AdminReservationsResponse,
  AdminUser,
  ReservationStatus,
  UpdateReservationStatusPayload,
  RefundReservationPayload,
  HandleReschedulePayload,
  BulkReservationUndoItem,
  ReminderWorkflowPayload,
  ReminderWorkflowStepPayload,
} from "@/lib/api/admin";
import type { UseQueryResult } from "@tanstack/react-query";
import {
  searchAdminUsers,
  updateReservationStatus,
  refundReservation,
  handleAdminReschedule,
  bulkUpdateReservationStatus,
  bulkCancelReservations,
  bulkSendReservationReminders,
  bulkUndoReservationActions,
  createReminderWorkflow,
  updateReminderWorkflow,
  deleteReminderWorkflow,
  createReminderWorkflowStep,
  updateReminderWorkflowStep,
  deleteReminderWorkflowStep,
  reorderReminderWorkflowSteps,
} from "@/lib/api/admin";
import { useMutationToast } from "@/hooks/use-mutation-toast";
import {
  useAdminReservationReminderSettings,
  reminderSettingsQueryKey,
} from "@/hooks/use-admin-reminder-settings";

const DEFAULT_FILTERS = {
  status: "",
  search: "",
  date_from: "",
  date_to: "",
  teacher_id: undefined as number | undefined,
  student_id: undefined as number | undefined,
  page: 1,
  per_page: 10,
} as const;

const MIN_QUERY_LENGTH = 2;

const reservationStatusFilters: Array<{
  label: string;
  value: "" | ReservationStatus;
}> = [
  { label: "Tümü", value: "" },
  { label: "Beklemede", value: "pending" },
  { label: "Onaylandı", value: "accepted" },
  { label: "Ders devam ediyor", value: "in_progress" },
  { label: "Tamamlandı", value: "completed" },
  { label: "İptal edildi", value: "cancelled" },
];

const bulkStatusOptions: Array<{ label: string; value: ReservationStatus }> = [
  { label: "Beklemeye al", value: "pending" },
  { label: "Onayla", value: "accepted" },
  { label: "Ders devam ediyor", value: "in_progress" },
  { label: "Tamamlandı", value: "completed" },
];

type StatusUpdateInput = Omit<
  UpdateReservationStatusPayload,
  "reservationId"
>;

type RefundInput = Omit<RefundReservationPayload, "reservationId">;

type RescheduleActionInput = Omit<HandleReschedulePayload, "reservationId">;

export default function ReservationsPage() {
  const queryClient = useQueryClient();
  const [filters, setFilters] = useState<AdminReservationsFilters>({
    ...DEFAULT_FILTERS,
  });
  const [selectedReservation, setSelectedReservation] = useState<AdminReservation | null>(null);
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);

  const [teacherQuery, setTeacherQuery] = useState("");
  const [studentQuery, setStudentQuery] = useState("");
  const [teacherResults, setTeacherResults] = useState<AdminUser[]>([]);
  const [studentResults, setStudentResults] = useState<AdminUser[]>([]);
  const [isSearchingTeacher, setIsSearchingTeacher] = useState(false);
  const [isSearchingStudent, setIsSearchingStudent] = useState(false);
  const [selectedTeacher, setSelectedTeacher] = useState<AdminUser | null>(null);
  const [selectedStudent, setSelectedStudent] = useState<AdminUser | null>(null);
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [bulkOptions, setBulkOptions] = useState({ notifyParticipants: true });
  const [isBulkCancelOpen, setIsBulkCancelOpen] = useState(false);
  const [bulkCancelReason, setBulkCancelReason] = useState("");
  const [bulkCancelNotify, setBulkCancelNotify] = useState(true);
  const [isBulkReminderOpen, setIsBulkReminderOpen] = useState(false);
  const [bulkReminderOptions, setBulkReminderOptions] = useState({
    notifyStudent: true,
    notifyTeacher: true,
    sendEmail: true,
  });
  const [lastBulkAction, setLastBulkAction] = useState<{
    description: string;
    undo: BulkReservationUndoItem[];
  } | null>(null);

  const reservationsQuery = useAdminReservations(filters) as UseQueryResult<
    AdminReservationsResponse,
    Error
  >;
  const { data, isLoading, isFetching, refetch } = reservationsQuery;
  const statusMutation = useMutationToast(updateReservationStatus, {
    successMessage: "Rezervasyon durumu güncellendi.",
    onSuccess: (response) => {
      if (response?.reservation) {
        setSelectedReservation(response.reservation);
      }
      queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
    },
  });
  const refundMutation = useMutationToast(refundReservation, {
    successMessage: "İade talebi işleme alındı.",
    onSuccess: (response) => {
      if (response?.reservation) {
        setSelectedReservation(response.reservation);
      }
      queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
    },
  });
  const rescheduleMutation = useMutationToast(handleAdminReschedule, {
    successMessage: "Yeniden planlama talebi güncellendi.",
    onSuccess: (response) => {
      if (response?.reservation) {
        setSelectedReservation(response.reservation);
      }
      queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
    },
  });

  const reminderSettingsQuery = useAdminReservationReminderSettings();
  const reminderWorkflows = reminderSettingsQuery.data?.workflows ?? [];

  const createWorkflowMutation = useMutationToast(
    (payload: ReminderWorkflowPayload) => createReminderWorkflow(payload),
    {
      successMessage: "Hatırlatma akışı oluşturuldu.",
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: reminderSettingsQueryKey });
        queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
      },
    },
  );

  const updateWorkflowMutation = useMutationToast(
    ({
      workflowId,
      payload,
    }: {
      workflowId: number;
      payload: Partial<ReminderWorkflowPayload>;
    }) => updateReminderWorkflow(workflowId, payload),
    {
      successMessage: "Hatırlatma akışı güncellendi.",
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: reminderSettingsQueryKey });
        queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
      },
    },
  );

  const deleteWorkflowMutation = useMutationToast(
    (workflowId: number) => deleteReminderWorkflow(workflowId),
    {
      successMessage: "Hatırlatma akışı silindi.",
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: reminderSettingsQueryKey });
        queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
      },
    },
  );

  const createWorkflowStepMutation = useMutationToast(
    ({
      workflowId,
      payload,
    }: {
      workflowId: number;
      payload: ReminderWorkflowStepPayload;
    }) => createReminderWorkflowStep(workflowId, payload),
    {
      successMessage: "Hatırlatma adımı eklendi.",
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: reminderSettingsQueryKey });
        queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
      },
    },
  );

  const updateWorkflowStepMutation = useMutationToast(
    ({
      workflowId,
      stepId,
      payload,
    }: {
      workflowId: number;
      stepId: number;
      payload: Partial<ReminderWorkflowStepPayload>;
    }) => updateReminderWorkflowStep(workflowId, stepId, payload),
    {
      successMessage: "Hatırlatma adımı güncellendi.",
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: reminderSettingsQueryKey });
        queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
      },
    },
  );

  const deleteWorkflowStepMutation = useMutationToast(
    ({ workflowId, stepId }: { workflowId: number; stepId: number }) =>
      deleteReminderWorkflowStep(workflowId, stepId),
    {
      successMessage: "Hatırlatma adımı silindi.",
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: reminderSettingsQueryKey });
        queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
      },
    },
  );

  const reorderWorkflowStepsMutation = useMutationToast(
    ({ workflowId, order }: { workflowId: number; order: number[] }) =>
      reorderReminderWorkflowSteps(workflowId, { order }),
    {
      successMessage: "Adım sıralaması güncellendi.",
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: reminderSettingsQueryKey });
        queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
      },
    },
  );

  const bulkStatusMutation = useMutationToast(bulkUpdateReservationStatus, {
    successMessage: "Toplu durum güncellendi.",
    onSuccess: (response) => {
      if (response?.undo?.length) {
        setLastBulkAction({
          description: `${response.updated_count ?? response.reservations?.length ?? 0} rezervasyon için durum güncellendi`,
          undo: response.undo,
        });
      } else {
        setLastBulkAction(null);
      }
      setSelectedIds(new Set());
      queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
    },
  });

  const bulkCancelMutation = useMutationToast(bulkCancelReservations, {
    successMessage: "Seçili rezervasyonlar iptal edildi.",
    onSuccess: (response) => {
      if (response?.undo?.length) {
        setLastBulkAction({
          description: `${response.updated_count ?? response.reservations?.length ?? 0} rezervasyon iptal edildi`,
          undo: response.undo,
        });
      } else {
        setLastBulkAction(null);
      }
      setSelectedIds(new Set());
      setIsBulkCancelOpen(false);
      setBulkCancelReason("");
      queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
    },
  });

  const bulkReminderMutation = useMutationToast(bulkSendReservationReminders, {
    successMessage: "Hatırlatmalar gönderildi.",
    onSuccess: () => {
      setIsBulkReminderOpen(false);
      setSelectedIds(new Set());
      queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
    },
  });

  const bulkUndoMutation = useMutationToast(bulkUndoReservationActions, {
    successMessage: "Toplu işlem geri alındı.",
    onSuccess: () => {
      setLastBulkAction(null);
      queryClient.invalidateQueries({ queryKey: reservationsQueryKey });
    },
  });

  const handleWorkflowCreate = async (payload: ReminderWorkflowPayload) => {
    await createWorkflowMutation.mutateAsync(payload);
  };

  const handleWorkflowUpdate = async (
    workflowId: number,
    payload: Partial<ReminderWorkflowPayload>,
  ) => {
    await updateWorkflowMutation.mutateAsync({ workflowId, payload });
  };

  const handleWorkflowDelete = async (workflowId: number) => {
    await deleteWorkflowMutation.mutateAsync(workflowId);
  };

  const handleWorkflowStepCreate = async (
    workflowId: number,
    payload: ReminderWorkflowStepPayload,
  ) => {
    await createWorkflowStepMutation.mutateAsync({ workflowId, payload });
  };

  const handleWorkflowStepUpdate = async (
    workflowId: number,
    stepId: number,
    payload: Partial<ReminderWorkflowStepPayload>,
  ) => {
    await updateWorkflowStepMutation.mutateAsync({ workflowId, stepId, payload });
  };

  const handleWorkflowStepDelete = async (workflowId: number, stepId: number) => {
    await deleteWorkflowStepMutation.mutateAsync({ workflowId, stepId });
  };

  const handleWorkflowStepReorder = async (workflowId: number, order: number[]) => {
    await reorderWorkflowStepsMutation.mutateAsync({ workflowId, order });
  };

  const isReminderMutationPending =
    createWorkflowMutation.isPending ||
    updateWorkflowMutation.isPending ||
    deleteWorkflowMutation.isPending ||
    createWorkflowStepMutation.isPending ||
    updateWorkflowStepMutation.isPending ||
    deleteWorkflowStepMutation.isPending ||
    reorderWorkflowStepsMutation.isPending;

  useEffect(() => {
    if (teacherQuery.trim().length < MIN_QUERY_LENGTH) {
      setTeacherResults([]);
      setIsSearchingTeacher(false);
      return;
    }

    let active = true;
    setIsSearchingTeacher(true);

    const handler = setTimeout(async () => {
      try {
        const results = await searchAdminUsers(teacherQuery.trim());
        if (active) {
          setTeacherResults(results.filter((user) => user.role === "teacher"));
        }
      } finally {
        if (active) {
          setIsSearchingTeacher(false);
        }
      }
    }, 300);

    return () => {
      active = false;
      clearTimeout(handler);
    };
  }, [teacherQuery]);

  useEffect(() => {
    if (studentQuery.trim().length < MIN_QUERY_LENGTH) {
      setStudentResults([]);
      setIsSearchingStudent(false);
      return;
    }

    let active = true;
    setIsSearchingStudent(true);

    const handler = setTimeout(async () => {
      try {
        const results = await searchAdminUsers(studentQuery.trim());
        if (active) {
          setStudentResults(results.filter((user) => user.role === "student"));
        }
      } finally {
        if (active) {
          setIsSearchingStudent(false);
        }
      }
    }, 300);

    return () => {
      active = false;
      clearTimeout(handler);
    };
  }, [studentQuery]);

  const reservations = data?.reservations ?? [];
  const pagination = data?.pagination;

  const selectionCount = selectedIds.size;
  const hasSelection = selectionCount > 0;
  const selectedIdsArray = useMemo(
    () => Array.from(selectedIds),
    [selectedIds],
  );

  useEffect(() => {
    if (!hasSelection) {
      setIsBulkCancelOpen(false);
      setIsBulkReminderOpen(false);
    }
  }, [hasSelection]);

  const clearSelection = () => setSelectedIds(new Set());

  const handleSelectionChange = (next: Set<number>) => {
    setSelectedIds(new Set(next));
  };

  const handleBulkStatusUpdate = (status: ReservationStatus) => {
    if (!selectedIdsArray.length || bulkStatusMutation.isPending) {
      return;
    }

    setLastBulkAction(null);
    bulkStatusMutation.mutate({
      reservation_ids: selectedIdsArray,
      status,
      notify_participants: bulkOptions.notifyParticipants,
    });
  };

  const handleBulkCancelConfirm = () => {
    if (!selectedIdsArray.length || bulkCancelMutation.isPending) {
      return;
    }

    setLastBulkAction(null);
    bulkCancelMutation.mutate({
      reservation_ids: selectedIdsArray,
      reason: bulkCancelReason.trim() ? bulkCancelReason.trim() : undefined,
      notify_participants: bulkCancelNotify,
    });
  };

  const handleBulkReminderSend = () => {
    if (!selectedIdsArray.length || bulkReminderMutation.isPending) {
      return;
    }

    bulkReminderMutation.mutate({
      reservation_ids: selectedIdsArray,
      notify_student: bulkReminderOptions.notifyStudent,
      notify_teacher: bulkReminderOptions.notifyTeacher,
      send_email: bulkReminderOptions.sendEmail,
    });
  };

  const handleBulkUndo = () => {
    if (!lastBulkAction || bulkUndoMutation.isPending) {
      return;
    }

    const items = lastBulkAction.undo;

    if (!items.length) {
      setLastBulkAction(null);
      return;
    }

    bulkUndoMutation.mutate({ items });
  };

  const hasActiveFilters = useMemo(() => {
    return (
      !!filters.status ||
      !!filters.search ||
      !!filters.date_from ||
      !!filters.date_to ||
      typeof filters.teacher_id === "number" ||
      typeof filters.student_id === "number"
    );
  }, [filters]);

  const handleReservationStatusUpdate = async (
    payload: StatusUpdateInput,
  ) => {
    if (!selectedReservation) {
      return;
    }

    await statusMutation.mutateAsync({
      reservationId: selectedReservation.id,
      ...payload,
    });
  };

  const handleReservationRefund = async (payload: RefundInput) => {
    if (!selectedReservation) {
      return;
    }

    await refundMutation.mutateAsync({
      reservationId: selectedReservation.id,
      ...payload,
    });
  };

  const handleRescheduleAction = async (payload: RescheduleActionInput) => {
    if (!selectedReservation) {
      return;
    }

    await rescheduleMutation.mutateAsync({
      reservationId: selectedReservation.id,
      ...payload,
    });
  };

  const handleResetFilters = () => {
    setFilters({ ...DEFAULT_FILTERS });
    setTeacherQuery("");
    setStudentQuery("");
    setTeacherResults([]);
    setStudentResults([]);
    setSelectedTeacher(null);
    setSelectedStudent(null);
  };

  return (
    <div className="space-y-4 md:space-y-6">
      <header className="flex flex-col gap-3 rounded-xl border border-slate-800/80 bg-slate-950/60 p-4 md:rounded-2xl md:gap-4 md:p-5 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h2 className="text-base font-semibold text-slate-100 md:text-lg">
            Rezervasyon Yönetimi
          </h2>
          <p className="mt-1 text-xs text-slate-400 md:text-sm">
            Öğrenci ve öğretmenler arasındaki ders rezervasyonlarını takip edin.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant="info" className="gap-2 text-xs md:text-sm">
            <CalendarClock className="h-4 w-4" />
            {pagination?.total ?? 0} rezervasyon
          </Badge>
          <Button
            variant="outline"
            className="border-slate-800 bg-slate-950 text-slate-300 hover:bg-slate-900/80"
            onClick={() => refetch()}
            disabled={isFetching}
          >
            <RefreshCcw className="mr-2 h-4 w-4" />
            Yenile
          </Button>
        </div>
      </header>

      {reminderSettingsQuery.isLoading ? (
        <ReminderSettingsSkeleton />
      ) : reminderSettingsQuery.isError ? (
        <div className="rounded-2xl border border-amber-500/40 bg-amber-500/10 p-4 text-sm text-amber-100">
          Hatırlatma ayarları yüklenirken bir hata oluştu. Lütfen sayfayı yenileyin.
        </div>
      ) : (
        <ReservationReminderSettingsCard
          workflows={reminderWorkflows}
          onCreateWorkflow={handleWorkflowCreate}
          onUpdateWorkflow={handleWorkflowUpdate}
          onDeleteWorkflow={handleWorkflowDelete}
          onCreateStep={handleWorkflowStepCreate}
          onUpdateStep={handleWorkflowStepUpdate}
          onDeleteStep={handleWorkflowStepDelete}
          onReorderSteps={handleWorkflowStepReorder}
          isProcessing={isReminderMutationPending}
        />
      )}

      <section className="grid gap-3 rounded-xl border border-slate-800/60 bg-slate-950/60 p-4 md:rounded-2xl md:gap-4 md:p-5 md:grid-cols-2 xl:grid-cols-4">
        <div className="space-y-2 md:col-span-2">
          <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
            Arama
          </label>
          <div className="mt-2 flex min-h-[44px] items-center gap-2 rounded-xl border border-slate-800/60 bg-slate-950/80 px-3">
            <Search className="h-3.5 w-3.5 shrink-0 text-slate-600 md:h-4 md:w-4" />
            <Input
              className="min-h-[44px] border-none bg-transparent px-0 text-base focus-visible:ring-0 md:min-h-0 md:text-sm"
              placeholder="Ders, kategori veya notlarda ara..."
              value={filters.search}
              onChange={(event) =>
                setFilters((prev) => ({
                  ...prev,
                  search: event.target.value,
                  page: 1,
                }))
              }
            />
          </div>
        </div>

        <div className="space-y-2">
          <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
            Başlangıç tarihi
          </label>
          <Input
            type="date"
            value={filters.date_from}
            onChange={(event) =>
              setFilters((prev) => ({
                ...prev,
                date_from: event.target.value,
                page: 1,
              }))
            }
          />
        </div>

        <div className="space-y-2">
          <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
            Bitiş tarihi
          </label>
          <Input
            type="date"
            value={filters.date_to}
            onChange={(event) =>
              setFilters((prev) => ({
                ...prev,
                date_to: event.target.value,
                page: 1,
              }))
            }
          />
        </div>

        <TeacherStudentSelector
          label="Öğretmen"
          query={teacherQuery}
          setQuery={(value) => {
            setTeacherQuery(value);
            if (!value) {
              setSelectedTeacher(null);
              setFilters((prev) => ({ ...prev, teacher_id: undefined, page: 1 }));
            }
          }}
          results={teacherResults}
          isSearching={isSearchingTeacher}
          selectedUser={selectedTeacher}
          onSelect={(user) => {
            setSelectedTeacher(user);
            setFilters((prev) => ({ ...prev, teacher_id: user.id, page: 1 }));
            setTeacherResults([]);
            setTeacherQuery(`${user.name} (${user.email})`);
          }}
          onClear={() => {
            setSelectedTeacher(null);
            setFilters((prev) => ({ ...prev, teacher_id: undefined, page: 1 }));
            setTeacherQuery("");
            setTeacherResults([]);
          }}
        />

        <TeacherStudentSelector
          label="Öğrenci"
          query={studentQuery}
          setQuery={(value) => {
            setStudentQuery(value);
            if (!value) {
              setSelectedStudent(null);
              setFilters((prev) => ({ ...prev, student_id: undefined, page: 1 }));
            }
          }}
          results={studentResults}
          isSearching={isSearchingStudent}
          selectedUser={selectedStudent}
          onSelect={(user) => {
            setSelectedStudent(user);
            setFilters((prev) => ({ ...prev, student_id: user.id, page: 1 }));
            setStudentResults([]);
            setStudentQuery(`${user.name} (${user.email})`);
          }}
          onClear={() => {
            setSelectedStudent(null);
            setFilters((prev) => ({ ...prev, student_id: undefined, page: 1 }));
            setStudentQuery("");
            setStudentResults([]);
          }}
        />

        <div className="md:col-span-2 xl:col-span-4">
          <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
            Durum
          </label>
          <div className="mt-2 flex flex-wrap items-center gap-2">
            {reservationStatusFilters.map((status) => (
              <FilterChip
                key={status.value}
                active={filters.status === status.value}
                onClick={() =>
                  setFilters((prev) => ({
                    ...prev,
                    status: prev.status === status.value ? "" : status.value,
                    page: 1,
                  }))
                }
              >
                {status.label}
              </FilterChip>
            ))}
            {hasActiveFilters && (
              <Button
                variant="ghost"
                className="text-xs text-slate-400 hover:text-slate-200"
                onClick={handleResetFilters}
              >
                Filtreleri temizle
              </Button>
            )}
          </div>
        </div>
      </section>

      <section className="space-y-4">
        {hasSelection ? (
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-sky-500/40 bg-sky-500/10 p-4 text-sm text-sky-100">
            <div className="flex items-center gap-2">
              <CheckSquare className="h-4 w-4" />
              <span>{selectionCount} rezervasyon seçildi.</span>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    size="sm"
                    variant="secondary"
                    className="border-slate-700 bg-slate-900/70 text-xs"
                    disabled={
                      bulkStatusMutation.isPending ||
                      bulkCancelMutation.isPending ||
                      bulkReminderMutation.isPending
                    }
                  >
                    Durumu değiştir
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-48">
                  {bulkStatusOptions.map((option) => (
                    <DropdownMenuItem
                      key={option.value}
                      onSelect={(event) => {
                        event.preventDefault();
                        handleBulkStatusUpdate(option.value);
                      }}
                      disabled={bulkStatusMutation.isPending}
                    >
                      {option.label}
                    </DropdownMenuItem>
                  ))}
                </DropdownMenuContent>
              </DropdownMenu>
              <Button
                size="sm"
                variant="secondary"
                className="border-slate-700 bg-slate-900/70 text-xs"
                onClick={() => setIsBulkCancelOpen(true)}
                disabled={bulkCancelMutation.isPending}
              >
                <Ban className="mr-1 h-3 w-3" />
                İptal et
              </Button>
              <Button
                size="sm"
                variant="secondary"
                className="border-slate-700 bg-slate-900/70 text-xs"
                onClick={() => setIsBulkReminderOpen(true)}
                disabled={bulkReminderMutation.isPending}
              >
                <BellRing className="mr-1 h-3 w-3" />
                Hatırlatma gönder
              </Button>
              <label className="flex items-center gap-2 rounded-full border border-slate-700/80 bg-slate-900/70 px-3 py-1 text-xs text-slate-200">
                <input
                  type="checkbox"
                  className="h-3 w-3 rounded border-slate-600 bg-slate-950 text-sky-500 focus:ring-sky-500"
                  checked={bulkOptions.notifyParticipants}
                  onChange={(event) =>
                    setBulkOptions((prev) => ({
                      ...prev,
                      notifyParticipants: event.target.checked,
                    }))
                  }
                />
                Bildirim gönder
              </label>
              <Button
                size="sm"
                variant="ghost"
                className="text-xs text-slate-300 hover:text-slate-100"
                onClick={clearSelection}
              >
                <Undo2 className="mr-1 h-3 w-3" />
                Seçimi temizle
              </Button>
            </div>
          </div>
        ) : null}

        {lastBulkAction ? (
          <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-amber-500/40 bg-amber-500/10 p-4 text-xs text-amber-100">
            <span>{lastBulkAction.description}</span>
            <Button
              size="sm"
              variant="ghost"
              className="text-xs text-amber-200 hover:text-amber-50"
              onClick={handleBulkUndo}
              disabled={bulkUndoMutation.isPending}
            >
              <Undo2 className="mr-1 h-3 w-3" />
              Geri al
            </Button>
          </div>
        ) : null}

        {isLoading ? (
          <ReservationsTableSkeleton />
        ) : (
          <ReservationsTable
            reservations={reservations}
            onSelect={(reservation) => {
              setSelectedReservation(reservation);
              setIsDrawerOpen(true);
            }}
            selectedReservationId={selectedReservation?.id ?? null}
            selectable
            selectedIds={selectedIds}
            onSelectionChange={handleSelectionChange}
          />
        )}

        {pagination && (
          <div className="flex items-center justify-between text-xs text-slate-500">
            <span>
              Toplam {pagination.total} sonuç • Sayfa {pagination.current_page} /{" "}
              {pagination.last_page}
            </span>
            <div className="flex items-center gap-2">
              <Button
                variant="ghost"
                className="text-xs"
                onClick={() =>
                  setFilters((prev) => ({
                    ...prev,
                    page: Math.max(1, (prev.page ?? 1) - 1),
                  }))
                }
                disabled={(filters.page ?? 1) <= 1 || isFetching}
              >
                Önceki
              </Button>
              <Button
                variant="ghost"
                className="text-xs"
                onClick={() =>
                  setFilters((prev) => ({
                    ...prev,
                    page: Math.min(
                      pagination.last_page,
                      (prev.page ?? 1) + 1,
                    ),
                  }))
                }
                disabled={
                  (filters.page ?? 1) >= pagination.last_page || isFetching
                }
              >
                Sonraki
              </Button>
            </div>
          </div>
        )}
      </section>

      <ReservationDetailDrawer
        reservation={selectedReservation}
        open={isDrawerOpen}
        onClose={() => setIsDrawerOpen(false)}
        onUpdateStatus={handleReservationStatusUpdate}
        isUpdating={statusMutation.isPending}
        onRefund={handleReservationRefund}
        isRefunding={refundMutation.isPending}
        onHandleReschedule={handleRescheduleAction}
        isRescheduleProcessing={rescheduleMutation.isPending}
        rescheduleHistory={selectedReservation?.reschedule_history ?? []}
      />

      <Dialog
        open={isBulkCancelOpen}
        onOpenChange={(open) => {
          setIsBulkCancelOpen(open);
          if (!open) {
            setBulkCancelReason("");
          }
        }}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Seçili rezervasyonları iptal et</DialogTitle>
            <DialogDescription>
              Öğrenci ve öğretmenleri bilgilendirerek tüm seçili rezervasyonları iptal edin.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                İptal nedeni (isteğe bağlı)
              </label>
              <Textarea
                placeholder="İptal nedenini açıklayın"
                value={bulkCancelReason}
                onChange={(event) => setBulkCancelReason(event.target.value)}
                rows={4}
              />
            </div>
            <label className="flex items-center gap-2 text-sm text-slate-300">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-slate-600 bg-slate-950 text-sky-500 focus:ring-sky-500"
                checked={bulkCancelNotify}
                onChange={(event) => setBulkCancelNotify(event.target.checked)}
              />
              Katılımcılara bildirim gönder
            </label>
          </div>
          <div className="flex justify-end gap-2">
            <Button
              variant="ghost"
              onClick={() => {
                setIsBulkCancelOpen(false);
                setBulkCancelReason("");
              }}
            >
              Vazgeç
            </Button>
            <Button
              variant="destructive"
              onClick={handleBulkCancelConfirm}
              disabled={bulkCancelMutation.isPending}
            >
              {bulkCancelMutation.isPending ? "İptal ediliyor..." : "İptal et"}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      <Dialog
        open={isBulkReminderOpen}
        onOpenChange={(open) => {
          setIsBulkReminderOpen(open);
        }}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Hatırlatma gönder</DialogTitle>
            <DialogDescription>
              Seçili rezervasyonlar için hatırlatma bildirimlerini ve e-postaları tetikleyin.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3 text-sm text-slate-200">
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-slate-600 bg-slate-950 text-sky-500 focus:ring-sky-500"
                checked={bulkReminderOptions.notifyStudent}
                onChange={(event) =>
                  setBulkReminderOptions((prev) => ({
                    ...prev,
                    notifyStudent: event.target.checked,
                  }))
                }
              />
              Öğrencilere push bildirimi gönder
            </label>
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-slate-600 bg-slate-950 text-sky-500 focus:ring-sky-500"
                checked={bulkReminderOptions.notifyTeacher}
                onChange={(event) =>
                  setBulkReminderOptions((prev) => ({
                    ...prev,
                    notifyTeacher: event.target.checked,
                  }))
                }
              />
              Öğretmenlere push bildirimi gönder
            </label>
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-slate-600 bg-slate-950 text-sky-500 focus:ring-sky-500"
                checked={bulkReminderOptions.sendEmail}
                onChange={(event) =>
                  setBulkReminderOptions((prev) => ({
                    ...prev,
                    sendEmail: event.target.checked,
                  }))
                }
              />
              Hatırlatma e-postası gönder
            </label>
            {!bulkReminderOptions.notifyStudent &&
            !bulkReminderOptions.notifyTeacher &&
            !bulkReminderOptions.sendEmail ? (
              <p className="text-xs text-red-400">
                En az bir bildirim kanalı seçmelisiniz.
              </p>
            ) : null}
          </div>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setIsBulkReminderOpen(false)}>
              Vazgeç
            </Button>
            <Button
              onClick={handleBulkReminderSend}
              disabled={
                bulkReminderMutation.isPending ||
                (!bulkReminderOptions.notifyStudent &&
                  !bulkReminderOptions.notifyTeacher &&
                  !bulkReminderOptions.sendEmail)
              }
            >
              {bulkReminderMutation.isPending ? "Gönderiliyor..." : "Hatırlatma gönder"}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

type FilterChipProps = {
  children: React.ReactNode;
  active: boolean;
  onClick: () => void;
};

function FilterChip({ children, active, onClick }: FilterChipProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="rounded-full border border-slate-800/70 bg-slate-950/70 px-3 py-1 text-xs text-slate-300 transition-colors hover:bg-slate-900/60 data-[active=true]:border-sky-500/40 data-[active=true]:bg-sky-500/10 data-[active=true]:text-sky-300"
      data-active={active}
    >
      {children}
    </button>
  );
}

function TeacherStudentSelector({
  label,
  query,
  setQuery,
  results,
  isSearching,
  selectedUser,
  onSelect,
  onClear,
}: {
  label: string;
  query: string;
  setQuery: (value: string) => void;
  results: AdminUser[];
  isSearching: boolean;
  selectedUser: AdminUser | null;
  onSelect: (user: AdminUser) => void;
  onClear: () => void;
}) {
  return (
    <div className="space-y-2">
      <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
        {label}
      </label>
      <div className="relative">
        <Input
          placeholder={`${label} ad veya e-posta`}
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
        {selectedUser && (
          <Badge className="absolute right-2 top-2 flex items-center gap-1 bg-sky-500/10 text-sky-200">
            <User className="h-3 w-3" />
            {selectedUser.name}
            <button
              type="button"
              className="ml-1 text-[11px] text-sky-200/80"
              onClick={onClear}
            >
              kaldır
            </button>
          </Badge>
        )}
      </div>
      {isSearching && (
        <p className="text-xs text-slate-500">Kullanıcılar aranıyor...</p>
      )}
      {!isSearching && results.length > 0 && (
        <div className="max-h-48 space-y-1 overflow-y-auto rounded-xl border border-slate-800/70 bg-slate-950/70 p-2 text-xs">
          {results.map((user) => (
            <button
              key={user.id}
              type="button"
              className="w-full rounded-lg px-3 py-2 text-left transition-colors hover:bg-slate-900/60"
              onClick={() => onSelect(user)}
            >
              <span className="font-medium text-slate-100">{user.name}</span>
              <span className="block text-[11px] text-slate-500">
                {user.email}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function ReminderSettingsSkeleton() {
  return (
    <div className="space-y-3 rounded-2xl border border-slate-800/60 bg-slate-950/70 p-5">
      <div className="flex items-center justify-between">
        <Skeleton className="h-5 w-40" />
        <Skeleton className="h-9 w-32" />
      </div>
      <div className="grid gap-3 md:grid-cols-2">
        {Array.from({ length: 2 }).map((_, index) => (
          <div
            key={index}
            className="space-y-2 rounded-xl border border-slate-800/60 bg-slate-950/60 p-4"
          >
            <Skeleton className="h-4 w-3/4" />
            <Skeleton className="h-3 w-2/3" />
            <div className="flex gap-2">
              <Skeleton className="h-6 w-20" />
              <Skeleton className="h-6 w-20" />
            </div>
            <div className="flex justify-end gap-2">
              <Skeleton className="h-8 w-16" />
              <Skeleton className="h-8 w-16" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function ReservationsTableSkeleton() {
  return (
    <div className="space-y-4">
      <Skeleton className="h-4 w-24" />
      <div className="overflow-hidden rounded-xl border border-slate-800/60 bg-slate-950/70">
        <table className="w-full table-fixed border-collapse">
          <thead className="bg-slate-950/80">
            <tr>
              {Array.from({ length: 6 }).map((_, index) => (
                <th key={index} className="px-4 py-3 text-left text-xs">
                  <Skeleton className="h-3 w-16 bg-slate-800/60" />
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800/70">
            {Array.from({ length: 5 }).map((_, index) => (
              <tr key={index}>
                {Array.from({ length: 6 }).map((__, cellIndex) => (
                  <td key={cellIndex} className="px-4 py-4">
                    <Skeleton className="h-4 w-24 bg-slate-800/60" />
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

