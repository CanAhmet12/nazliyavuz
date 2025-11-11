import { useMemo, useState } from "react";
import { addMinutes, formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";
import {
  Plus,
  Workflow,
  Settings2,
  Trash2,
  ArrowUp,
  ArrowDown,
  UserCircle2,
  UserCheck,
  Mail,
  MessageSquare,
  BellRing,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";

import type {
  ReminderWorkflow,
  ReminderWorkflowPayload,
  ReminderWorkflowStep,
  ReminderWorkflowStepPayload,
} from "@/lib/api/admin";

type ReservationReminderSettingsCardProps = {
  workflows: ReminderWorkflow[];
  onCreateWorkflow: (payload: ReminderWorkflowPayload) => Promise<void>;
  onUpdateWorkflow: (
    workflowId: number,
    payload: Partial<ReminderWorkflowPayload>,
  ) => Promise<void>;
  onDeleteWorkflow: (workflowId: number) => Promise<void>;
  onCreateStep: (
    workflowId: number,
    payload: ReminderWorkflowStepPayload,
  ) => Promise<void>;
  onUpdateStep: (
    workflowId: number,
    stepId: number,
    payload: Partial<ReminderWorkflowStepPayload>,
  ) => Promise<void>;
  onDeleteStep: (workflowId: number, stepId: number) => Promise<void>;
  onReorderSteps: (workflowId: number, order: number[]) => Promise<void>;
  isProcessing?: boolean;
};

const STATUS_LABEL: Record<ReminderWorkflow["status"], string> = {
  draft: "Taslak",
  active: "Aktif",
  archived: "Arşivlendi",
};

const STATUS_VARIANT: Record<ReminderWorkflow["status"], "secondary" | "success" | "info"> = {
  draft: "secondary",
  active: "success",
  archived: "info",
};

type WorkflowDialogState =
  | {
      mode: "create";
    }
  | {
      mode: "edit";
      workflow: ReminderWorkflow;
    };

type StepDialogState =
  | {
      mode: "create";
      workflow: ReminderWorkflow;
    }
  | {
      mode: "edit";
      workflow: ReminderWorkflow;
      step: ReminderWorkflowStep;
    };

type ReservationStatus = ReminderWorkflow["target_statuses"][number];

type WorkflowFormState = {
  name: string;
  description: string;
  status: ReminderWorkflow["status"];
  targetStatuses: Record<ReservationStatus, boolean>;
  targetRoles: Record<"student" | "teacher", boolean>;
};

type ChannelOptionState = {
  enabled: boolean;
  templateId: string;
};

type StepFormState = {
  name: string;
  offsetMinutes: number;
  offsetDirection: "before" | "after";
  sendWindow: number;
  stepOrder: number;
  enabled: boolean;
  stopOnSuccess: boolean;
  channels: {
    student: {
      push: ChannelOptionState;
      email: ChannelOptionState;
      sms: ChannelOptionState;
    };
    teacher: {
      push: ChannelOptionState;
      email: ChannelOptionState;
      sms: ChannelOptionState;
    };
  };
};

const DEFAULT_WORKFLOW_FORM: WorkflowFormState = {
  name: "",
  description: "",
  status: "active",
  targetStatuses: {
    pending: false,
    accepted: true,
    in_progress: true,
    completed: false,
    cancelled: false,
  },
  targetRoles: {
    student: true,
    teacher: true,
  },
};

const DEFAULT_CHANNEL_OPTION: ChannelOptionState = {
  enabled: false,
  templateId: "",
};

const DEFAULT_STEP_FORM: StepFormState = {
  name: "",
  offsetMinutes: 120,
  offsetDirection: "before",
  sendWindow: 10,
  stepOrder: 1,
  enabled: true,
  stopOnSuccess: true,
  channels: {
    student: {
      push: { ...DEFAULT_CHANNEL_OPTION },
      email: { ...DEFAULT_CHANNEL_OPTION },
      sms: { ...DEFAULT_CHANNEL_OPTION },
    },
    teacher: {
      push: { ...DEFAULT_CHANNEL_OPTION },
      email: { ...DEFAULT_CHANNEL_OPTION },
      sms: { ...DEFAULT_CHANNEL_OPTION },
    },
  },
};

const WORKFLOW_STATUS_OPTIONS: ReminderWorkflow["status"][] = ["draft", "active", "archived"];

const WORKFLOW_STATUS_ORDER: ReservationStatus[] = [
  "pending",
  "accepted",
  "in_progress",
  "completed",
  "cancelled",
];

const ROLE_OPTIONS: Array<{ value: "student" | "teacher"; label: string }> = [
  { value: "student", label: "Öğrenci" },
  { value: "teacher", label: "Öğretmen" },
];

export function ReservationReminderSettingsCard({
  workflows,
  onCreateWorkflow,
  onUpdateWorkflow,
  onDeleteWorkflow,
  onCreateStep,
  onUpdateStep,
  onDeleteStep,
  onReorderSteps,
  isProcessing = false,
}: ReservationReminderSettingsCardProps) {
  const [workflowDialog, setWorkflowDialog] = useState<WorkflowDialogState | null>(null);
  const [workflowForm, setWorkflowForm] = useState<WorkflowFormState>(DEFAULT_WORKFLOW_FORM);

  const [stepDialog, setStepDialog] = useState<StepDialogState | null>(null);
  const [stepForm, setStepForm] = useState<StepFormState>(DEFAULT_STEP_FORM);

  const isWorkflowDialogOpen = Boolean(workflowDialog);
  const isStepDialogOpen = Boolean(stepDialog);

  const openCreateWorkflowDialog = () => {
    setWorkflowForm(DEFAULT_WORKFLOW_FORM);
    setWorkflowDialog({ mode: "create" });
  };

  const openEditWorkflowDialog = (workflow: ReminderWorkflow) => {
    setWorkflowForm({
      name: workflow.name,
      description: workflow.description ?? "",
      status: workflow.status,
      targetStatuses: WORKFLOW_STATUS_ORDER.reduce<Record<ReservationStatus, boolean>>(
        (acc, status) => {
          acc[status] = workflow.target_statuses.includes(status);
          return acc;
        },
        {
          pending: false,
          accepted: false,
          in_progress: false,
          completed: false,
          cancelled: false,
        },
      ),
      targetRoles: {
        student: workflow.target_roles.includes("student"),
        teacher: workflow.target_roles.includes("teacher"),
      },
    });
    setWorkflowDialog({ mode: "edit", workflow });
  };

  const openCreateStepDialog = (workflow: ReminderWorkflow) => {
    const stepOrder = (workflow.steps?.length ?? 0) + 1;
    setStepForm({
      ...DEFAULT_STEP_FORM,
      stepOrder,
      name: `Hatırlatma ${stepOrder}`,
    });
    setStepDialog({ mode: "create", workflow });
  };

  const openEditStepDialog = (workflow: ReminderWorkflow, step: ReminderWorkflowStep) => {
    setStepForm({
      name: step.name,
      offsetMinutes: step.offset_minutes,
      offsetDirection: step.offset_direction,
      sendWindow: step.send_window,
      stepOrder: step.step_order,
      enabled: step.enabled,
      stopOnSuccess: step.stop_on_success,
      channels: {
        student: {
          push: toChannelOptionState(step.channels.student.push),
          email: toChannelOptionState(step.channels.student.email),
          sms: toChannelOptionState(step.channels.student.sms),
        },
        teacher: {
          push: toChannelOptionState(step.channels.teacher.push),
          email: toChannelOptionState(step.channels.teacher.email),
          sms: toChannelOptionState(step.channels.teacher.sms),
        },
      },
    });
    setStepDialog({ mode: "edit", workflow, step });
  };

  const closeWorkflowDialog = () => {
    setWorkflowDialog(null);
    setWorkflowForm(DEFAULT_WORKFLOW_FORM);
  };

  const closeStepDialog = () => {
    setStepDialog(null);
    setStepForm(DEFAULT_STEP_FORM);
  };

  const handleWorkflowSubmit = async () => {
    if (!workflowDialog) {
      return;
    }

    const payload: ReminderWorkflowPayload = {
      name: workflowForm.name.trim(),
      description: workflowForm.description.trim() || undefined,
      status: workflowForm.status,
      target_statuses: WORKFLOW_STATUS_ORDER.filter(
        (status) => workflowForm.targetStatuses[status],
      ),
      target_roles: (ROLE_OPTIONS.map(({ value }) => value) as Array<"student" | "teacher">).filter(
        (role) => workflowForm.targetRoles[role],
      ),
      meta: {},
    };

    if (workflowDialog.mode === "create") {
      await onCreateWorkflow(payload);
    } else {
      await onUpdateWorkflow(workflowDialog.workflow.id, payload);
    }

    closeWorkflowDialog();
  };

  const handleWorkflowDelete = async (workflow: ReminderWorkflow) => {
    if (isProcessing) {
      return;
    }
    await onDeleteWorkflow(workflow.id);
  };

  const handleStepSubmit = async () => {
    if (!stepDialog) {
      return;
    }

    const payload: ReminderWorkflowStepPayload = {
      name: stepForm.name.trim(),
      offset_minutes: Number(stepForm.offsetMinutes),
      offset_direction: stepForm.offsetDirection,
      send_window: Number(stepForm.sendWindow),
      step_order: Number(stepForm.stepOrder),
      enabled: stepForm.enabled,
      stop_on_success: stepForm.stopOnSuccess,
      channels: toChannelPayload(stepForm.channels),
    };

    if (stepDialog.mode === "create") {
      await onCreateStep(stepDialog.workflow.id, payload);
    } else {
      await onUpdateStep(stepDialog.workflow.id, stepDialog.step.id, payload);
    }

    closeStepDialog();
  };

  const handleStepDelete = async (workflow: ReminderWorkflow, step: ReminderWorkflowStep) => {
    if (isProcessing) {
      return;
    }

    await onDeleteStep(workflow.id, step.id);
  };

  const handleToggleStepEnabled = async (
    workflow: ReminderWorkflow,
    step: ReminderWorkflowStep,
  ) => {
    await onUpdateStep(workflow.id, step.id, { enabled: !step.enabled });
  };

  const handleToggleStopOnSuccess = async (
    workflow: ReminderWorkflow,
    step: ReminderWorkflowStep,
  ) => {
    await onUpdateStep(workflow.id, step.id, { stop_on_success: !step.stop_on_success });
  };

  const handleReorderStep = async (
    workflow: ReminderWorkflow,
    step: ReminderWorkflowStep,
    direction: "up" | "down",
  ) => {
    const steps = workflow.steps ?? [];
    const currentIndex = steps.findIndex((item) => item.id === step.id);

    if (currentIndex === -1) {
      return;
    }

    const targetIndex = direction === "up" ? currentIndex - 1 : currentIndex + 1;

    if (targetIndex < 0 || targetIndex >= steps.length) {
      return;
    }

    const newOrder = [...steps];
    const [removed] = newOrder.splice(currentIndex, 1);
    newOrder.splice(targetIndex, 0, removed);

    await onReorderSteps(
      workflow.id,
      newOrder.map((item) => item.id),
    );
  };

  return (
    <section className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/60 p-5">
      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="text-lg font-semibold text-slate-100">Hatırlatma Akışları</h3>
          <p className="text-xs text-slate-400">
            Rezervasyon öncesi ve sonrasında otomatik gönderilecek çok adımlı hatırlatma
            akışlarını yönetin.
          </p>
        </div>
        <Dialog open={isWorkflowDialogOpen} onOpenChange={(open) => !open && closeWorkflowDialog()}>
          <DialogTrigger asChild>
            <Button
              size="sm"
              onClick={openCreateWorkflowDialog}
              disabled={isProcessing}
              className="gap-2"
            >
              <Plus className="h-4 w-4" />
              Yeni akış
            </Button>
          </DialogTrigger>
          {workflowDialog ? (
            <WorkflowDialogContent
              formState={workflowForm}
              setFormState={setWorkflowForm}
              onCancel={closeWorkflowDialog}
              onSubmit={handleWorkflowSubmit}
              isSubmitting={isProcessing}
              mode={workflowDialog.mode}
            />
          ) : null}
        </Dialog>
      </header>

      {workflows.length === 0 ? (
        <div className="rounded-xl border border-dashed border-slate-800/70 bg-slate-950/40 p-6 text-center text-sm text-slate-400">
          Henüz oluşturulmuş bir hatırlatma akışı yok.{" "}
          <button
            type="button"
            className="font-semibold text-slate-100 hover:underline"
            onClick={openCreateWorkflowDialog}
            disabled={isProcessing}
          >
            İlk akışı ekleyin.
          </button>
        </div>
      ) : (
        <div className="grid gap-4 lg:grid-cols-2">
          {workflows.map((workflow) => {
            const steps = [...(workflow.steps ?? [])].sort(
              (a, b) => a.step_order - b.step_order,
            );

            return (
              <article
                key={workflow.id}
                className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4"
              >
                <header className="flex flex-wrap items-start justify-between gap-3">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <Workflow className="h-4 w-4 text-sky-400" />
                      <h4 className="text-base font-semibold text-slate-100">
                        {workflow.name}
                      </h4>
                    </div>
                    {workflow.description ? (
                      <p className="text-xs text-slate-400">{workflow.description}</p>
                    ) : null}
                    <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-500">
                      <Badge variant={STATUS_VARIANT[workflow.status]}>
                        {STATUS_LABEL[workflow.status]}
                      </Badge>
                      <span>
                        Hedef durumlar:{" "}
                        {workflow.target_statuses.length
                          ? workflow.target_statuses
                              .map((status) => WORKFLOW_STATUS_LABELS[status] ?? status)
                              .join(", ")
                          : "Belirtilmedi"}
                      </span>
                      <span>
                        Hedef roller:{" "}
                        {workflow.target_roles.length
                          ? workflow.target_roles
                              .map((role) => (role === "student" ? "Öğrenci" : "Öğretmen"))
                              .join(", ")
                          : "Belirtilmedi"}
                      </span>
                    </div>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={isProcessing}
                      onClick={() => openEditWorkflowDialog(workflow)}
                    >
                      Düzenle
                    </Button>
                    <Button
                      size="icon"
                      variant="ghost"
                      className="text-destructive hover:text-destructive"
                      disabled={isProcessing}
                      onClick={() => handleWorkflowDelete(workflow)}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </header>

                <div className="space-y-3">
                  {steps.length === 0 ? (
                    <div className="rounded-lg border border-dashed border-slate-800/60 bg-slate-950/60 p-4 text-xs text-slate-400">
                      Bu akışta henüz hatırlatma adımı yok.
                    </div>
                  ) : (
                    steps.map((step, index) => {
                      const previewDate =
                        step.offset_direction === "before"
                          ? addMinutes(new Date(), step.offset_minutes)
                          : addMinutes(new Date(), -step.offset_minutes);

                      const previewLabel = formatDistanceToNow(previewDate, {
                        addSuffix: true,
                        locale: tr,
                      });

                      const canMoveUp = index > 0;
                      const canMoveDown = index < steps.length - 1;

                      return (
                        <div
                          key={step.id}
                          className="space-y-3 rounded-xl border border-slate-800/60 bg-slate-950/75 p-4 text-xs text-slate-300"
                        >
                          <div className="flex flex-wrap items-start justify-between gap-2">
                            <div className="space-y-1">
                              <div className="flex items-center gap-2">
                                <h5 className="text-sm font-semibold text-slate-100">
                                  {step.name}
                                </h5>
                                <Badge variant={step.enabled ? "success" : "secondary"}>
                                  {step.enabled ? "Aktif" : "Pasif"}
                                </Badge>
                                {step.stop_on_success ? (
                                  <Badge variant="info">Başarılıysa diğer adımları atla</Badge>
                                ) : null}
                              </div>
                              <p className="text-[11px] text-slate-500">
                                {step.offset_human} • {previewLabel}
                              </p>
                              <p className="text-[11px] text-slate-500">
                                Gönderim penceresi: ±{step.send_window} dk • Adım sırası:{" "}
                                {step.step_order}
                              </p>
                            </div>
                            <div className="flex flex-wrap items-center gap-2">
                              <Button
                                size="icon"
                                variant="ghost"
                                disabled={!canMoveUp || isProcessing}
                                onClick={() => handleReorderStep(workflow, step, "up")}
                              >
                                <ArrowUp className="h-4 w-4" />
                              </Button>
                              <Button
                                size="icon"
                                variant="ghost"
                                disabled={!canMoveDown || isProcessing}
                                onClick={() => handleReorderStep(workflow, step, "down")}
                              >
                                <ArrowDown className="h-4 w-4" />
                              </Button>
                              <Button
                                size="icon"
                                variant="ghost"
                                disabled={isProcessing}
                                onClick={() => handleToggleStepEnabled(workflow, step)}
                                title={step.enabled ? "Devre dışı bırak" : "Etkinleştir"}
                              >
                                <Settings2 className="h-4 w-4" />
                              </Button>
                              <Button
                                size="icon"
                                variant="ghost"
                                disabled={isProcessing}
                                onClick={() => handleToggleStopOnSuccess(workflow, step)}
                                title={
                                  step.stop_on_success
                                    ? "Başarılı olursa sonraki adımları gönder"
                                    : "Başarılı olursa diğer adımları atla"
                                }
                              >
                                <BellIcon active={!step.stop_on_success} />
                              </Button>
                              <Dialog
                                open={
                                  isStepDialogOpen &&
                                  stepDialog?.mode === "edit" &&
                                  stepDialog.workflow.id === workflow.id &&
                                  stepDialog.step.id === step.id
                                }
                                onOpenChange={(open) => !open && closeStepDialog()}
                              >
                                <DialogTrigger asChild>
                                  <Button
                                    size="sm"
                                    variant="ghost"
                                    disabled={isProcessing}
                                    onClick={() => openEditStepDialog(workflow, step)}
                                  >
                                    Düzenle
                                  </Button>
                                </DialogTrigger>
                                {stepDialog?.mode === "edit" &&
                                stepDialog.workflow.id === workflow.id &&
                                stepDialog.step.id === step.id ? (
                                  <StepDialogContent
                                    formState={stepForm}
                                    setFormState={setStepForm}
                                    onCancel={closeStepDialog}
                                    onSubmit={handleStepSubmit}
                                    isSubmitting={isProcessing}
                                  />
                                ) : null}
                              </Dialog>
                              <Button
                                size="icon"
                                variant="ghost"
                                className="text-destructive hover:text-destructive"
                                disabled={isProcessing}
                                onClick={() => handleStepDelete(workflow, step)}
                              >
                                <Trash2 className="h-4 w-4" />
                              </Button>
                            </div>
                          </div>

                          <ChannelPreview channels={step.channels} />
                        </div>
                      );
                    })
                  )}
                </div>

                <Dialog
                  open={
                    isStepDialogOpen &&
                    stepDialog?.mode === "create" &&
                    stepDialog.workflow.id === workflow.id
                  }
                  onOpenChange={(open) => !open && closeStepDialog()}
                >
                  <DialogTrigger asChild>
                    <Button
                      size="sm"
                      variant="outline"
                      className="gap-2"
                      disabled={isProcessing}
                      onClick={() => openCreateStepDialog(workflow)}
                    >
                      <Plus className="h-4 w-4" />
                      Adım ekle
                    </Button>
                  </DialogTrigger>
                  {stepDialog?.mode === "create" && stepDialog.workflow.id === workflow.id ? (
                    <StepDialogContent
                      formState={stepForm}
                      setFormState={setStepForm}
                      onCancel={closeStepDialog}
                      onSubmit={handleStepSubmit}
                      isSubmitting={isProcessing}
                    />
                  ) : null}
                </Dialog>
              </article>
            );
          })}
        </div>
      )}
    </section>
  );
}

function WorkflowDialogContent({
  formState,
  setFormState,
  onCancel,
  onSubmit,
  isSubmitting,
  mode,
}: {
  formState: WorkflowFormState;
  setFormState: (next: WorkflowFormState) => void;
  onCancel: () => void;
  onSubmit: () => Promise<void>;
  isSubmitting: boolean;
  mode: "create" | "edit";
}) {
  return (
    <DialogContent className="max-w-xl">
      <DialogHeader>
        <DialogTitle>
          {mode === "create" ? "Yeni hatırlatma akışı" : "Hatırlatma akışını düzenle"}
        </DialogTitle>
        <DialogDescription>
          Rezervasyon sürecine özel hatırlatma adımlarını tanımlayın ve hangi durumlarda tetikleneceğini
          belirleyin.
        </DialogDescription>
      </DialogHeader>

      <div className="space-y-4 py-2">
        <div className="space-y-2">
          <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
            Akış adı
          </label>
          <Input
            placeholder="Örn. Ders öncesi hatırlatmalar"
            value={formState.name}
            onChange={(event) =>
              setFormState({
                ...formState,
                name: event.target.value,
              })
            }
          />
        </div>
        <div className="space-y-2">
          <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
            Açıklama (isteğe bağlı)
          </label>
          <Textarea
            rows={3}
            placeholder="Akışın amacı ve içeriği hakkında kısa bilgi ekleyin."
            value={formState.description}
            onChange={(event) =>
              setFormState({
                ...formState,
                description: event.target.value,
              })
            }
          />
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Durum
            </label>
            <select
              className="h-10 w-full rounded-md border border-slate-800 bg-slate-950 px-3 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
              value={formState.status}
              onChange={(event) =>
                setFormState({
                  ...formState,
                  status: event.target.value as ReminderWorkflow["status"],
                })
              }
            >
              {WORKFLOW_STATUS_OPTIONS.map((status) => (
                <option key={status} value={status}>
                  {STATUS_LABEL[status]}
                </option>
              ))}
            </select>
          </div>

          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Hedef roller
            </label>
            <div className="space-y-1 rounded-lg border border-slate-800/60 bg-slate-950/70 p-3 text-xs">
              {ROLE_OPTIONS.map((role) => (
                <label key={role.value} className="flex items-center gap-2">
                  <Checkbox
                    checked={formState.targetRoles[role.value]}
                    onCheckedChange={(checked) =>
                      setFormState({
                        ...formState,
                        targetRoles: {
                          ...formState.targetRoles,
                          [role.value]: Boolean(checked),
                        },
                      })
                    }
                  />
                  {role.label}
                </label>
              ))}
            </div>
          </div>
        </div>

        <div className="space-y-2">
          <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
            Hedef rezervasyon durumları
          </label>
          <div className="grid gap-2 sm:grid-cols-2">
            {WORKFLOW_STATUS_ORDER.map((status) => (
              <label
                key={status}
                className="flex items-center gap-2 rounded-lg border border-slate-800/60 bg-slate-950/70 px-3 py-2 text-xs"
              >
                <Checkbox
                  checked={formState.targetStatuses[status]}
                  onCheckedChange={(checked) =>
                    setFormState({
                      ...formState,
                      targetStatuses: {
                        ...formState.targetStatuses,
                        [status]: Boolean(checked),
                      },
                    })
                  }
                />
                {WORKFLOW_STATUS_LABELS[status] ?? status}
              </label>
            ))}
          </div>
        </div>
      </div>

      <div className="flex justify-end gap-2">
        <Button variant="ghost" onClick={onCancel} disabled={isSubmitting}>
          Vazgeç
        </Button>
        <Button onClick={onSubmit} disabled={isSubmitting || !formState.name.trim()}>
          {isSubmitting ? "Kaydediliyor..." : "Kaydet"}
        </Button>
      </div>
    </DialogContent>
  );
}

function StepDialogContent({
  formState,
  setFormState,
  onCancel,
  onSubmit,
  isSubmitting,
}: {
  formState: StepFormState;
  setFormState: (next: StepFormState) => void;
  onCancel: () => void;
  onSubmit: () => Promise<void>;
  isSubmitting: boolean;
}) {
  const updateChannel = (
    audience: "student" | "teacher",
    channel: "push" | "email" | "sms",
    changes: Partial<ChannelOptionState>,
  ) => {
    setFormState({
      ...formState,
      channels: {
        ...formState.channels,
        [audience]: {
          ...formState.channels[audience],
          [channel]: {
            ...formState.channels[audience][channel],
            ...changes,
          },
        },
      },
    });
  };

  return (
    <DialogContent className="max-w-2xl">
      <DialogHeader>
        <DialogTitle>Hatırlatma adımı</DialogTitle>
        <DialogDescription>
          Ders öncesi veya sonrası için gönderilecek hatırlatmanın zamanlamasını ve kullanılacak
          kanalları belirleyin.
        </DialogDescription>
      </DialogHeader>

      <div className="space-y-4 py-2">
        <div className="grid gap-4 md:grid-cols-2">
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Adım adı
            </label>
            <Input
              placeholder="Örn. 24 saat önce"
              value={formState.name}
              onChange={(event) =>
                setFormState({
                  ...formState,
                  name: event.target.value,
                })
              }
            />
          </div>
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Adım sırası
            </label>
            <Input
              type="number"
              min={1}
              value={formState.stepOrder}
              onChange={(event) =>
                setFormState({
                  ...formState,
                  stepOrder: Number.parseInt(event.target.value || "1", 10),
                })
              }
            />
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Offset (dakika)
            </label>
            <Input
              type="number"
              min={0}
              step={5}
              value={formState.offsetMinutes}
              onChange={(event) =>
                setFormState({
                  ...formState,
                  offsetMinutes: Number.parseInt(event.target.value || "0", 10),
                })
              }
            />
            <p className="text-[11px] text-slate-500">
              0 değerini girerek rezervasyon anında hatırlatma gönderilmesini sağlayabilirsiniz.
            </p>
          </div>
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Gönderim yönü
            </label>
            <select
              className="h-10 w-full rounded-md border border-slate-800 bg-slate-950 px-3 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
              value={formState.offsetDirection}
              onChange={(event) =>
                setFormState({
                  ...formState,
                  offsetDirection: event.target.value as "before" | "after",
                })
              }
            >
              <option value="before">Rezervasyondan önce</option>
              <option value="after">Rezervasyondan sonra</option>
            </select>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Gönderim penceresi (dakika)
            </label>
            <Input
              type="number"
              min={1}
              value={formState.sendWindow}
              onChange={(event) =>
                setFormState({
                  ...formState,
                  sendWindow: Number.parseInt(event.target.value || "1", 10),
                })
              }
            />
          </div>
          <div className="space-y-2 rounded-lg border border-slate-800/60 bg-slate-950/70 p-3 text-xs">
            <label className="flex items-center gap-2">
              <Checkbox
                checked={formState.enabled}
                onCheckedChange={(checked) =>
                  setFormState({
                    ...formState,
                    enabled: Boolean(checked),
                  })
                }
              />
              Adım aktif olsun
            </label>
            <label className="flex items-center gap-2">
              <Checkbox
                checked={formState.stopOnSuccess}
                onCheckedChange={(checked) =>
                  setFormState({
                    ...formState,
                    stopOnSuccess: Boolean(checked),
                  })
                }
              />
              Adım başarılı olursa diğer adımları geç (stop-on-success)
            </label>
          </div>
        </div>

        <div className="space-y-3">
          <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
            Bildirim kanalları
          </label>
          <div className="grid gap-3 md:grid-cols-2">
            {(["student", "teacher"] as const).map((audience) => (
              <div
                key={audience}
                className="space-y-2 rounded-lg border border-slate-800/60 bg-slate-950/70 p-3 text-xs"
              >
                <p className="font-semibold text-slate-300">
                  {audience === "student" ? "Öğrenciler" : "Öğretmenler"}
                </p>
                {(["push", "email", "sms"] as const).map((channel) => (
                  <div
                    key={channel}
                    className="rounded-lg border border-slate-800/60 bg-slate-950/60 p-3"
                  >
                    <label className="flex items-center gap-2">
                      <Checkbox
                        checked={formState.channels[audience][channel].enabled}
                        onCheckedChange={(checked) =>
                          updateChannel(audience, channel, { enabled: Boolean(checked) })
                        }
                      />
                      {CHANNEL_LABELS[`${audience}_${channel}`] ?? channel}
                    </label>
                    <Input
                      type="number"
                      min={1}
                      placeholder="Şablon ID (isteğe bağlı)"
                      className="mt-2"
                      value={formState.channels[audience][channel].templateId}
                      onChange={(event) =>
                        updateChannel(audience, channel, {
                          templateId: event.target.value,
                        })
                      }
                      disabled={!formState.channels[audience][channel].enabled}
                    />
                    <p className="mt-1 text-[11px] text-slate-500">
                      {channel === "push"
                        ? "Push bildirimi için şablon belirtmezseniz varsayılan içerik kullanılır."
                        : channel === "email"
                          ? "E-posta şablonu belirtmek isteğe bağlıdır."
                          : "SMS gönderimi için entegrasyon gerektiğini unutmayın."}
                    </p>
                  </div>
                ))}
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="flex justify-end gap-2">
        <Button variant="ghost" onClick={onCancel} disabled={isSubmitting}>
          Vazgeç
        </Button>
        <Button onClick={onSubmit} disabled={isSubmitting || !formState.name.trim()}>
          {isSubmitting ? "Kaydediliyor..." : "Kaydet"}
        </Button>
      </div>
    </DialogContent>
  );
}

function ChannelPreview({
  channels,
}: {
  channels: ReminderWorkflowStep["channels"];
}) {
  const channelEntries = useMemo(() => {
    const entries: Array<{ key: string; label: string }> = [];

    (["student", "teacher"] as const).forEach((audience) => {
      (["push", "email", "sms"] as const).forEach((channel) => {
        if (channels[audience][channel]?.enabled) {
          const key = `${audience}_${channel}`;
          entries.push({
            key,
            label: CHANNEL_LABELS[key] ?? key,
          });
        }
      });
    });

    return entries;
  }, [channels]);

  if (channelEntries.length === 0) {
    return (
      <p className="text-[11px] text-slate-500">
        Bu adım için etkin kanal bulunmuyor. Bir kanalı etkinleştirmek için adımı düzenleyin.
      </p>
    );
  }

  return (
    <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-400">
      <span className="uppercase tracking-wide text-slate-500">Kanallar:</span>
      {channelEntries.map(({ key, label }) => (
        <span
          key={key}
          className="inline-flex items-center gap-1 rounded-full border border-slate-800/60 bg-slate-950/60 px-2 py-1 text-xs"
        >
          {renderChannelIcon(key)}
          {label}
        </span>
      ))}
    </div>
  );
}

function BellIcon({ active }: { active: boolean }) {
  return <BellRing className={active ? "h-4 w-4 text-sky-400" : "h-4 w-4 text-slate-500"} />;
}

function renderChannelIcon(channel: string) {
  if (channel.startsWith("student")) {
    if (channel.endsWith("push")) {
      return <UserCircle2 className="h-3 w-3 text-sky-400" />;
    }
    if (channel.endsWith("email")) {
      return <Mail className="h-3 w-3 text-amber-400" />;
    }
    if (channel.endsWith("sms")) {
      return <MessageSquare className="h-3 w-3 text-emerald-400" />;
    }
  }

  if (channel.startsWith("teacher")) {
    if (channel.endsWith("push")) {
      return <UserCheck className="h-3 w-3 text-emerald-400" />;
    }
    if (channel.endsWith("email")) {
      return <Mail className="h-3 w-3 text-purple-300" />;
    }
    if (channel.endsWith("sms")) {
      return <MessageSquare className="h-3 w-3 text-purple-300" />;
    }
  }

  if (channel === "email") {
    return <Mail className="h-3 w-3 text-amber-400" />;
  }

  return <BellRing className="h-3 w-3 text-slate-400" />;
}

const CHANNEL_LABELS: Record<string, string> = {
  student_push: "Öğrenci push",
  student_email: "Öğrenci e-posta",
  student_sms: "Öğrenci SMS",
  teacher_push: "Öğretmen push",
  teacher_email: "Öğretmen e-posta",
  teacher_sms: "Öğretmen SMS",
};

const WORKFLOW_STATUS_LABELS: Record<ReservationStatus, string> = {
  pending: "Beklemede",
  accepted: "Onaylandı",
  in_progress: "Devam ediyor",
  completed: "Tamamlandı",
  cancelled: "İptal edildi",
};

function toChannelOptionState(channel?: { enabled?: boolean | null; template_id?: number | null }) {
  return {
    enabled: Boolean(channel?.enabled),
    templateId: channel?.template_id ? String(channel.template_id) : "",
  };
}

function toChannelPayload(channels: StepFormState["channels"]): ReminderWorkflowStepPayload["channels"] {
  const serialize = (option: ChannelOptionState) => ({
    enabled: option.enabled,
    template_id: option.templateId.trim()
      ? Number.parseInt(option.templateId.trim(), 10)
      : null,
  });

  return {
    student: {
      push: serialize(channels.student.push),
      email: serialize(channels.student.email),
      sms: serialize(channels.student.sms),
    },
    teacher: {
      push: serialize(channels.teacher.push),
      email: serialize(channels.teacher.email),
      sms: serialize(channels.teacher.sms),
    },
  };
}

