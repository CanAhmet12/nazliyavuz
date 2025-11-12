"use client";

import { useEffect, useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { format } from "date-fns";
import { tr } from "date-fns/locale";
import {
  AlertCircle,
  CalendarClock,
  Clock,
  Loader2,
  Pencil,
  Play,
  Plus,
  Trash2,
  Sparkles,
  X,
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
import { Skeleton } from "@/components/ui/skeleton";
import { useMutationToast } from "@/hooks/use-mutation-toast";
import {
  createScheduledNotification,
  updateScheduledNotification,
  scheduleScheduledNotification,
  sendScheduledNotificationNow,
  cancelScheduledNotification,
  type ScheduledNotification,
  type ScheduledNotificationPayload,
} from "@/lib/api/admin-notifications";
import {
  scheduledNotificationSchema,
  type ScheduledNotificationFormSchema,
} from "@/lib/validations/notification";
import { scheduledNotificationsQueryKey, useScheduledNotifications } from "@/hooks/use-scheduled-notifications";
import { cn } from "@/lib/utils";
import { useQueryClient } from "@tanstack/react-query";
import { useNotificationTemplates } from "@/hooks/use-notification-templates";
import type { NotificationTemplate } from "@/lib/api/admin-notifications";
import toast from "react-hot-toast";

type ScheduledNotificationsCardProps = {
  onViewLogs?: (notification: ScheduledNotification) => void;
};

type PlaceholderRow = {
  key: string;
  value: string;
};

export function ScheduledNotificationsCard({ onViewLogs }: ScheduledNotificationsCardProps) {
  const queryClient = useQueryClient();
  const { data, isLoading, isRefetching, refetch } = useScheduledNotifications();
  const notifications = useMemo(() => data?.notifications ?? [], [data]);
  const {
    data: templateData,
    isLoading: templatesLoading,
    refetch: refetchTemplates,
  } = useNotificationTemplates();
  const templates = useMemo(() => templateData?.templates ?? [], [templateData]);

  const [isDialogOpen, setDialogOpen] = useState(false);
  const [editingNotification, setEditingNotification] = useState<ScheduledNotification | null>(null);
  const [appliedTemplateId, setAppliedTemplateId] = useState<number | null>(null);
  const [templatePlaceholderRows, setTemplatePlaceholderRows] = useState<PlaceholderRow[]>([]);

  const form = useForm<ScheduledNotificationFormSchema>({
    resolver: zodResolver(scheduledNotificationSchema),
    defaultValues: {
      title: "",
      message: "",
      type: "info",
      priority: "normal",
      targetType: "all",
      channels: {
        push: true,
        email: false,
        in_app: true,
      },
      scheduledAt: undefined,
      status: "draft",
      templateId: undefined,
    },
  });

  const addTemplatePlaceholderRow = (key = "", value = "") => {
    setTemplatePlaceholderRows((rows) => [...rows, { key, value }]);
  };

  const ensureTemplatePlaceholderRow = (key: string) => {
    const normalized = key.trim();
    if (!normalized) {
      return;
    }
    setTemplatePlaceholderRows((rows) => {
      if (rows.some((row) => row.key === normalized)) {
        return rows;
      }
      return [...rows, { key: normalized, value: "" }];
    });
  };

  const updateTemplatePlaceholderRow = (index: number, patch: Partial<PlaceholderRow>) => {
    setTemplatePlaceholderRows((rows) =>
      rows.map((row, i) => (i === index ? { ...row, ...patch } : row)),
    );
  };

  const removeTemplatePlaceholderRow = (index: number) => {
    setTemplatePlaceholderRows((rows) => rows.filter((_, i) => i !== index));
  };

  useEffect(() => {
    if (editingNotification) {
      form.reset({
        title: editingNotification.title,
        message: editingNotification.message,
        type: editingNotification.type as ScheduledNotificationFormSchema["type"],
        priority: editingNotification.priority as ScheduledNotificationFormSchema["priority"],
        targetType: editingNotification.target_type as ScheduledNotificationFormSchema["targetType"],
        channels: {
          push: editingNotification.channels?.push ?? true,
          email: editingNotification.channels?.email ?? false,
          in_app: editingNotification.channels?.in_app ?? true,
        },
        scheduledAt: editingNotification.scheduled_at ?? undefined,
        status: editingNotification.status === "draft" ? "draft" : "scheduled",
        templateId: editingNotification.template_id ?? undefined,
      });
      setAppliedTemplateId(editingNotification.template_id ?? null);
      const existingPlaceholders = (editingNotification.meta?.placeholders ?? {}) as Record<string, unknown>;
      const rows = Object.entries(existingPlaceholders).map(([key, value]) => ({
        key,
        value: value === null || value === undefined ? "" : String(value),
      }));
      setTemplatePlaceholderRows(rows);
    } else {
      form.reset({
        title: "",
        message: "",
        type: "info",
        priority: "normal",
        targetType: "all",
        channels: {
          push: true,
          email: false,
          in_app: true,
        },
        scheduledAt: undefined,
        status: "draft",
        templateId: undefined,
      });
      setAppliedTemplateId(null);
      setTemplatePlaceholderRows([]);
    }
  }, [editingNotification, form]);

  // eslint-disable-next-line react-hooks/incompatible-library
  const templateId = form.watch("templateId") ?? null;
  const selectedTemplate: NotificationTemplate | undefined = useMemo(() => {
    if (!templateId) {
      return undefined;
    }
    return templates.find((template) => template.id === templateId);
  }, [templates, templateId]);
  const requiredTemplateVariables = useMemo(
    () => selectedTemplate?.variables ?? [],
    [selectedTemplate],
  );
  const templatePlaceholderObject = useMemo(() => {
    return templatePlaceholderRows.reduce<Record<string, string>>((acc, row) => {
      const key = row.key.trim();
      if (key) {
        acc[key] = row.value ?? "";
      }
      return acc;
    }, {});
  }, [templatePlaceholderRows]);
  const missingTemplatePlaceholders = useMemo(() => {
    return requiredTemplateVariables.filter((variable) => {
      const value = templatePlaceholderObject[variable];
      return !value || value.trim().length === 0;
    });
  }, [requiredTemplateVariables, templatePlaceholderObject]);

  useEffect(() => {
    if (templateId && appliedTemplateId !== templateId) {
      const template = templates.find((item) => item.id === templateId);
      if (template) {
        form.setValue("title", template.subject ?? template.name ?? "", { shouldValidate: true });
        form.setValue("message", template.body ?? "", { shouldValidate: true });
        setAppliedTemplateId(templateId);
      }
    }
    if (!templateId && appliedTemplateId) {
      setAppliedTemplateId(null);
    }
  }, [templateId, appliedTemplateId, templates, form]);

  useEffect(() => {
    if (!selectedTemplate) {
      setTemplatePlaceholderRows([]);
      return;
    }
    setTemplatePlaceholderRows((prev) => {
      const variables = selectedTemplate.variables ?? [];
      const previousValues = new Map(prev.map((row) => [row.key, row.value]));
      const nextRows = variables.map((variable) => ({
        key: variable,
        value: previousValues.get(variable) ?? "",
      }));
      const extras = prev.filter((row) => !variables.includes(row.key));
      return [...nextRows, ...extras];
    });
  }, [selectedTemplate]);

  const createMutation = useMutationToast(createScheduledNotification, {
    successMessage: "Bildirim taslağı oluşturuldu.",
    onSuccess: () => {
      setDialogOpen(false);
      setEditingNotification(null);
      setTemplatePlaceholderRows([]);
      queryClient.invalidateQueries({ queryKey: scheduledNotificationsQueryKey });
    },
  });

  const updateMutation = useMutationToast(
    ({ id, payload }: { id: number; payload: Partial<ScheduledNotificationPayload> }) =>
      updateScheduledNotification(id, payload),
    {
      successMessage: "Bildiriminiz güncellendi.",
      onSuccess: () => {
        setDialogOpen(false);
        setEditingNotification(null);
        setTemplatePlaceholderRows([]);
        queryClient.invalidateQueries({ queryKey: scheduledNotificationsQueryKey });
      },
    },
  );

  const scheduleMutation = useMutationToast(
    ({ id, scheduled_at, timezone }: { id: number; scheduled_at: string; timezone?: string | null }) =>
      scheduleScheduledNotification(id, { scheduled_at, timezone }),
    {
      successMessage: "Bildirim planlandı.",
      onSuccess: () => {
        setDialogOpen(false);
        setEditingNotification(null);
        queryClient.invalidateQueries({ queryKey: scheduledNotificationsQueryKey });
      },
    },
  );

  const sendNowMutation = useMutationToast(sendScheduledNotificationNow, {
    successMessage: "Bildirim gönderilmek üzere kuyruğa alındı.",
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: scheduledNotificationsQueryKey });
    },
  });

  const cancelMutation = useMutationToast(cancelScheduledNotification, {
    successMessage: "Bildirim iptal edildi.",
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: scheduledNotificationsQueryKey });
    },
  });

  const isProcessing =
    createMutation.isPending ||
    updateMutation.isPending ||
    scheduleMutation.isPending ||
    sendNowMutation.isPending ||
    cancelMutation.isPending;

  const onSubmit = form.handleSubmit((values) => {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const scheduledAtIso = values.scheduledAt ? new Date(values.scheduledAt).toISOString() : null;
    const placeholdersObject = templatePlaceholderRows.reduce<Record<string, string>>((acc, row) => {
      const key = row.key.trim();
      if (!key) {
        return acc;
      }
      acc[key] = row.value ?? "";
      return acc;
    }, {});
    const requiredVariables = selectedTemplate?.variables ?? [];
    const missingRequired = values.templateId
      ? requiredVariables.filter((variable) => {
          const value = placeholdersObject[variable];
          return !value || value.trim().length === 0;
        })
      : [];

    if (missingRequired.length) {
      toast.error(`Lütfen şu değişkenler için değer girin: ${missingRequired.join(", ")}`);
      return;
    }

    const hasPlaceholderValues = Object.keys(placeholdersObject).length > 0;

    const payload: ScheduledNotificationPayload = {
      title: values.title || undefined,
      message: values.message || undefined,
      type: values.type,
      priority: values.priority,
      target_type: values.targetType,
      channels: {
        push: values.channels.push,
        email: values.channels.email,
        in_app: values.channels.in_app,
      },
      scheduled_at: scheduledAtIso,
      timezone,
      status: values.status,
      template_id: values.templateId ?? null,
    };

    if (hasPlaceholderValues) {
      payload.meta = { placeholders: placeholdersObject };
    } else if (editingNotification?.meta?.placeholders) {
      payload.meta = null;
    }

    if (editingNotification) {
      updateMutation.mutate({
        id: editingNotification.id,
        payload,
      });

      if (values.status === "scheduled" && values.scheduledAt) {
        scheduleMutation.mutate({
          id: editingNotification.id,
          scheduled_at: scheduledAtIso ?? new Date().toISOString(),
          timezone,
        });
      }
    } else {
      createMutation.mutate(payload);
    }
  });

  const upcomingNotifications = useMemo(() => {
    return notifications.slice().sort((a, b) => {
      const aTime = a.scheduled_at ? new Date(a.scheduled_at).getTime() : Number.MAX_SAFE_INTEGER;
      const bTime = b.scheduled_at ? new Date(b.scheduled_at).getTime() : Number.MAX_SAFE_INTEGER;
      return aTime - bTime;
    });
  }, [notifications]);

  return (
    <section className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/60 p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="text-lg font-semibold text-slate-100">Planlanmış Bildirimler</h3>
          <p className="text-xs text-slate-400">
            Otomatik olarak gönderilecek bildirimleri oluşturup planlayın.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="ghost"
            size="sm"
            className="text-xs text-slate-300 hover:text-slate-100"
            onClick={() => refetch()}
            disabled={isLoading || isRefetching}
          >
            {isRefetching ? <Loader2 className="mr-2 h-3 w-3 animate-spin" /> : null}
            Yenile
          </Button>
          <Dialog open={isDialogOpen} onOpenChange={(open) => {
            setDialogOpen(open);
            if (!open) {
              setEditingNotification(null);
              setTemplatePlaceholderRows([]);
            }
          }}>
            <DialogTrigger asChild>
              <Button
                size="sm"
                onClick={() => {
                  setEditingNotification(null);
                  setTemplatePlaceholderRows([]);
                  setDialogOpen(true);
                }}
              >
                <Plus className="mr-2 h-4 w-4" />
                Yeni Bildirim
              </Button>
            </DialogTrigger>
            <DialogContent className="max-w-2xl">
              <DialogHeader>
                <DialogTitle>
                  {editingNotification ? "Bildirimi düzenle" : "Yeni planlanmış bildirim"}
                </DialogTitle>
                <DialogDescription>
                  Başlık, mesaj ve hedef kitlenizi belirleyin. İsterseniz taslak olarak kaydedebilir veya tarih seçerek planlayabilirsiniz.
                </DialogDescription>
              </DialogHeader>
              <form onSubmit={onSubmit} className="space-y-4">
                <div className="grid gap-3 md:grid-cols-2">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Başlık
                    </label>
                    <Input
                      placeholder="Örn. Haftalık sistem bakımı"
                      {...form.register("title")}
                    />
                    {form.formState.errors.title ? (
                      <p className="text-xs text-red-400">
                        {form.formState.errors.title.message}
                      </p>
                    ) : null}
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Bildirim tipi
                    </label>
                    <select
                      className="w-full rounded-lg border border-slate-800 bg-slate-950 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
                      {...form.register("type")}
                    >
                      <option value="info">Bilgi</option>
                      <option value="success">Başarı</option>
                      <option value="warning">Uyarı</option>
                      <option value="error">Hata</option>
                    </select>
                  </div>
                </div>

                <div className="grid gap-3 md:grid-cols-2">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Öncelik
                    </label>
                    <select
                      className="w-full rounded-lg border border-slate-800 bg-slate-950 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
                      {...form.register("priority")}
                    >
                      <option value="low">Düşük</option>
                      <option value="normal">Normal</option>
                      <option value="high">Yüksek</option>
                      <option value="urgent">Acil</option>
                    </select>
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Hedef kitle
                    </label>
                    <select
                      className="w-full rounded-lg border border-slate-800 bg-slate-950 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
                      {...form.register("targetType")}
                    >
                      <option value="all">Tüm kullanıcılar</option>
                      <option value="students">Öğrenciler</option>
                      <option value="teachers">Öğretmenler</option>
                      <option value="admins">Adminler</option>
                    </select>
                  </div>
                </div>

                <div className="space-y-2 rounded-xl border border-slate-800/60 bg-slate-950/60 p-3 text-xs text-slate-300">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                      Şablon seçimi (opsiyonel)
                    </p>
                    <Button
                      variant="ghost"
                      size="sm"
                      type="button"
                      className="text-[11px] text-slate-400 hover:text-slate-200"
                      onClick={() => refetchTemplates()}
                      disabled={templatesLoading}
                    >
                      {templatesLoading ? <Loader2 className="mr-1 h-3 w-3 animate-spin" /> : null}
                      Yenile
                    </Button>
                  </div>
                  <div className="flex items-center gap-2">
                    <select
                      className="w-full rounded-lg border border-slate-800 bg-slate-950 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
                      value={templateId ?? ""}
                      onChange={(event) => {
                        const value = event.target.value ? Number(event.target.value) : undefined;
                        form.setValue("templateId", value, { shouldDirty: true, shouldValidate: true });
                      }}
                    >
                      <option value="">Şablon seçin (opsiyonel)</option>
                      {templates.map((template) => (
                        <option key={template.id} value={template.id}>
                          {template.name} • {template.status === "published" ? "Yayınlandı" : "Taslak"}
                        </option>
                      ))}
                    </select>
                    {templateId ? (
                      <Button
                        variant="ghost"
                        size="icon"
                        type="button"
                        className="h-8 w-8 text-slate-400 hover:text-slate-100"
                        onClick={() => form.setValue("templateId", undefined, { shouldDirty: true, shouldValidate: true })}
                      >
                        <X className="h-4 w-4" />
                      </Button>
                    ) : null}
                  </div>
                  {selectedTemplate ? (
                    <div className="rounded-lg border border-slate-800/60 bg-slate-950/70 p-3 text-[11px] text-slate-400">
                      <p className="flex items-center gap-2 text-slate-200">
                        <Sparkles className="h-3 w-3 text-sky-400" />
                        <span>{selectedTemplate.name}</span>
                      </p>
                      {selectedTemplate.subject ? (
                        <p className="mt-1 text-slate-400">
                          <strong>Konu:</strong> {selectedTemplate.subject}
                        </p>
                      ) : null}
                      <p className="mt-1 line-clamp-3 text-slate-400">{selectedTemplate.body}</p>
                    </div>
                  ) : (
                    <p className="text-[11px] text-slate-500">
                      Şablon seçerseniz başlık ve mesaj otomatik doldurulur, dilerseniz üzerinde düzenleme yapabilirsiniz.
                    </p>
                  )}
                </div>

                {(selectedTemplate || templatePlaceholderRows.length > 0) && (
                  <div className="space-y-3 rounded-xl border border-slate-800/60 bg-slate-950/60 p-3 text-xs text-slate-300">
                    <div className="space-y-2">
                      <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                        Şablon değişkenleri
                      </p>
                      {selectedTemplate ? (
                        requiredTemplateVariables.length ? (
                          <div className="flex flex-wrap gap-2">
                            {requiredTemplateVariables.map((variable) => {
                              const isMissing = missingTemplatePlaceholders.includes(variable);
                              return (
                                <Badge
                                  key={variable}
                                  variant="default"
                                  className={cn(
                                    "cursor-pointer border-slate-700 text-slate-200 hover:border-sky-500/40 hover:text-sky-300",
                                    isMissing && "border-amber-500/60 text-amber-300",
                                  )}
                                  onClick={() => ensureTemplatePlaceholderRow(variable)}
                                >
                                  {`{{${variable}}}`}
                                </Badge>
                              );
                            })}
                          </div>
                        ) : (
                          <p className="text-[11px] text-slate-500">
                            Bu şablon herhangi bir dinamik değişken tanımlamıyor. Yine de isteğe bağlı placeholder ekleyebilirsiniz.
                          </p>
                        )
                      ) : (
                        <p className="text-[11px] text-slate-500">
                          Özel placeholder ekleyerek meta bilgileri gönderebilirsiniz.
                        </p>
                      )}
                    </div>

                    <div className="space-y-2">
                      {templatePlaceholderRows.length ? (
                        templatePlaceholderRows.map((row, index) => {
                          const isRequired = requiredTemplateVariables.includes(row.key);
                          const isMissing = isRequired && (!row.value || row.value.trim().length === 0);

                          return (
                            <div
                              key={`${row.key}-${index}`}
                              className="grid gap-2 sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto]"
                            >
                              <Input
                                value={row.key}
                                placeholder="ör. reservation.date"
                                disabled={isRequired}
                                className={cn(
                                  "bg-slate-950 text-xs text-slate-200",
                                  isRequired && "cursor-not-allowed opacity-90",
                                )}
                                onChange={(event) =>
                                  updateTemplatePlaceholderRow(index, { key: event.target.value })
                                }
                              />
                              <Input
                                value={row.value}
                                placeholder={isRequired ? "Gerekli değer" : "Opsiyonel değer"}
                                className={cn(
                                  "bg-slate-950 text-xs text-slate-200",
                                  isMissing && "border-amber-500/60 text-amber-200 focus:border-amber-500/60 focus:ring-amber-400/40",
                                )}
                                onChange={(event) =>
                                  updateTemplatePlaceholderRow(index, { value: event.target.value })
                                }
                              />
                              <Button
                                variant="ghost"
                                size="icon"
                                type="button"
                                className={cn("h-8 w-8 text-slate-400 hover:text-slate-100", isRequired && "opacity-40")}
                                disabled={isRequired}
                                onClick={() => removeTemplatePlaceholderRow(index)}
                                aria-label="Placeholder kaldır"
                              >
                                <Trash2 className="h-4 w-4" />
                              </Button>
                              {isMissing ? (
                                <div className="col-span-2 text-[11px] text-amber-400">
                                  Bu değişken için değer girmeniz gerekiyor.
                                </div>
                              ) : null}
                            </div>
                          );
                        })
                      ) : (
                        <p className="text-[11px] text-slate-500">
                          {selectedTemplate
                            ? "Şablon değişkenleri için değer girin."
                            : "Placeholder eklemek için aşağıdaki butonu kullanın."}
                        </p>
                      )}
                    </div>

                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-xs"
                        onClick={() => addTemplatePlaceholderRow()}
                      >
                        <Plus className="mr-2 h-4 w-4" />
                        Özel placeholder ekle
                      </Button>
                      {selectedTemplate && requiredTemplateVariables.length ? (
                        <p
                          className={cn(
                            "text-[11px]",
                            missingTemplatePlaceholders.length ? "text-amber-400" : "text-emerald-400",
                          )}
                        >
                          {missingTemplatePlaceholders.length
                            ? `Eksik değer: ${missingTemplatePlaceholders.join(", ")}`
                            : "Tüm zorunlu değişkenler için değer girildi."}
                        </p>
                      ) : null}
                    </div>
                  </div>
                )}

                <div className="space-y-2">
                  <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                    Mesaj içeriği
                  </label>
                  <Textarea
                    rows={5}
                    placeholder="Kullanıcılarınıza iletmek istediğiniz bilgilendirme mesajını yazın."
                    {...form.register("message")}
                  />
                  {form.formState.errors.message ? (
                    <p className="text-xs text-red-400">
                      {form.formState.errors.message.message}
                    </p>
                  ) : null}
                </div>

                <div className="space-y-2 rounded-xl border border-slate-800/60 bg-slate-950/60 p-3 text-xs text-slate-300">
                  <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                    Bildirim kanalları
                  </p>
                  <div className="flex flex-wrap gap-3">
                    <label className="flex items-center gap-2">
                      <Checkbox
                        checked={form.watch("channels.push")}
                        onCheckedChange={(checked) => form.setValue("channels.push", Boolean(checked))}
                      />
                      Push bildirimi gönder
                    </label>
                    <label className="flex items-center gap-2">
                      <Checkbox
                        checked={form.watch("channels.email")}
                        onCheckedChange={(checked) => form.setValue("channels.email", Boolean(checked))}
                      />
                      E-posta gönder
                    </label>
                    <label className="flex items-center gap-2">
                      <Checkbox
                        checked={form.watch("channels.in_app")}
                        onCheckedChange={(checked) => form.setValue("channels.in_app", Boolean(checked))}
                      />
                      Uygulama içi bildirim oluştur
                    </label>
                  </div>
                </div>

                <div className="grid gap-3 md:grid-cols-2">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Planlanan tarih (opsiyonel)
                    </label>
                    <Input
                      type="datetime-local"
                      className="bg-slate-950 text-sm text-slate-100"
                      {...form.register("scheduledAt")}
                    />
                    <p className="text-[11px] text-slate-500">
                      Boş bırakırsanız taslak olarak kaydedilir.
                    </p>
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Durum
                    </label>
                    <select
                      className="w-full rounded-lg border border-slate-800 bg-slate-950 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
                      {...form.register("status")}
                    >
                      <option value="draft">Taslak</option>
                      <option value="scheduled">Planlandı</option>
                    </select>
                  </div>
                </div>

                <div className="flex items-center justify-end gap-2">
                  <Button
                    type="button"
                    variant="ghost"
                    onClick={() => {
                      setDialogOpen(false);
                      setEditingNotification(null);
                    }}
                    disabled={isProcessing}
                  >
                    İptal
                  </Button>
                  <Button type="submit" disabled={isProcessing}>
                    {isProcessing ? "Kaydediliyor..." : "Kaydet"}
                  </Button>
                </div>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {isLoading ? (
        <ScheduledNotificationsSkeleton />
      ) : upcomingNotifications.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="space-y-3">
          {upcomingNotifications.map((notification) => (
            <div
              key={notification.id}
              className={cn(
                "rounded-2xl border border-slate-800/60 bg-slate-950/60 p-4 text-xs text-slate-300 transition-colors",
                notification.status === "failed" ? "border-red-500/40 bg-red-500/10" : "",
                notification.status === "sent" ? "border-emerald-500/30 bg-emerald-500/5" : "",
              )}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="space-y-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <h4 className="text-sm font-semibold text-slate-100">
                      {notification.title || notification.template?.subject || notification.template?.name}
                    </h4>
                    <Badge variant="default" className="border-slate-700 text-slate-300">
                      {notification.type.toUpperCase()}
                    </Badge>
                    <Badge variant="default">{notification.priority}</Badge>
                    {notification.template ? (
                      <Badge variant="default" className="border-sky-500/40 text-sky-300">
                        Şablon: {notification.template.name}
                      </Badge>
                    ) : null}
                  </div>
                  <p className="text-slate-400">
                    {(notification.message ?? "").length > 140
                      ? `${(notification.message ?? "").slice(0, 140)}…`
                      : notification.message ?? "—"}
                  </p>
                  <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-500">
                    <span className="inline-flex items-center gap-1">
                      <CalendarClock className="h-3 w-3" />
                      {notification.scheduled_at
                        ? format(new Date(notification.scheduled_at), "d MMM yyyy HH:mm", { locale: tr })
                        : "Planlanmamış"}
                    </span>
                    <span className="inline-flex items-center gap-1">
                      <Clock className="h-3 w-3" />
                      {notification.status.toUpperCase()}
                    </span>
                    <span>
                      Hedef: {notification.target_type === "all" ? "Tümü" : notification.target_type}
                    </span>
                  </div>
                </div>
                <div className="flex flex-col gap-2">
                  <div className="flex gap-1">
                    <Badge variant="default" className={notification.channels?.push ? "" : "opacity-50"}>
                      Push
                    </Badge>
                    <Badge variant="default" className={notification.channels?.email ? "" : "opacity-50"}>
                      Email
                    </Badge>
                    <Badge variant="default" className={notification.channels?.in_app ? "" : "opacity-50"}>
                      In-App
                    </Badge>
                  </div>
                  <div className="flex flex-wrap justify-end gap-2">
                    <Button
                      size="sm"
                      variant="outline"
                      className="text-xs"
                      onClick={() => {
                        setEditingNotification(notification);
                        setDialogOpen(true);
                      }}
                    >
                      <Pencil className="mr-1 h-3 w-3" />
                      Düzenle
                    </Button>
                    {notification.status === "draft" ? (
                      <Button
                        size="sm"
                        variant="outline"
                        className="text-xs"
                        onClick={() =>
                          scheduleMutation.mutate({
                            id: notification.id,
                            scheduled_at: notification.scheduled_at ?? new Date().toISOString(),
                            timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
                          })
                        }
                      >
                        <CalendarClock className="mr-1 h-3 w-3" />
                        Planla
                      </Button>
                    ) : null}
                    {notification.status === "scheduled" || notification.status === "draft" ? (
                      <Button
                        size="sm"
                        variant="outline"
                        className="text-xs text-red-400 hover:text-red-300"
                        onClick={() => cancelMutation.mutate(notification.id)}
                      >
                        <Trash2 className="mr-1 h-3 w-3" />
                        İptal Et
                      </Button>
                    ) : null}
                    <Button
                      size="sm"
                      className="text-xs"
                      variant="secondary"
                      onClick={() => sendNowMutation.mutate(notification.id)}
                    >
                      <Play className="mr-1 h-3 w-3" />
                      Hemen gönder
                    </Button>
                    {onViewLogs ? (
                      <Button
                        size="sm"
                        variant="ghost"
                        className="text-xs text-slate-300 hover:text-slate-100"
                        onClick={() => onViewLogs(notification)}
                      >
                        Loglar
                      </Button>
                    ) : null}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

function ScheduledNotificationsSkeleton() {
  return (
    <div className="space-y-3">
      {Array.from({ length: 3 }).map((_, index) => (
        <div key={index} className="rounded-2xl border border-slate-800/70 bg-slate-950/60 p-4">
          <Skeleton className="h-5 w-64" />
          <Skeleton className="mt-3 h-4 w-full" />
          <div className="mt-3 flex gap-2">
            <Skeleton className="h-6 w-16" />
            <Skeleton className="h-6 w-16" />
            <Skeleton className="h-6 w-16" />
          </div>
        </div>
      ))}
    </div>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-2xl border border-dashed border-slate-800/60 bg-slate-950/50 p-8 text-center">
      <div className="rounded-full border border-slate-800/60 bg-slate-900/70 p-3">
        <AlertCircle className="h-6 w-6 text-slate-400" />
      </div>
      <div>
        <h4 className="text-sm font-semibold text-slate-200">
          Henüz planlanmış bildirim yok
        </h4>
        <p className="text-xs text-slate-500">
          Yeni bir hatırlatma veya bilgilendirme oluşturup gelecekte otomatik gönderilmesini sağlayabilirsiniz.
        </p>
      </div>
    </div>
  );
}

