"use client";

import { useEffect, useMemo, useState, type Dispatch, type SetStateAction } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { format } from "date-fns";
import { tr } from "date-fns/locale";
import {
  Archive,
  Eye,
  Check,
  Copy,
  FileText,
  Loader2,
  Pencil,
  Plus,
  Rocket,
  Send,
  Trash2,
  Mail,
  Bell,
  MessageSquare,
  Monitor,
  AlertCircle,
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
import {
  useNotificationTemplates,
  notificationTemplatesQueryKey,
} from "@/hooks/use-notification-templates";
import {
  createNotificationTemplate,
  updateNotificationTemplate,
  publishNotificationTemplate,
  archiveNotificationTemplate,
  duplicateNotificationTemplate,
  renderNotificationTemplate,
  testSendNotificationTemplate,
  type NotificationTemplate,
  type NotificationTemplatePayload,
} from "@/lib/api/admin-notifications";
import {
  notificationTemplateSchema,
  type NotificationTemplateFormSchema,
} from "@/lib/validations/notification";
import { useMutationToast } from "@/hooks/use-mutation-toast";
import { useNotificationTemplateVariables } from "@/hooks/use-notification-template-variables";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";

type NotificationTemplatesCardProps = {
  onSelectTemplate?: (template: NotificationTemplate) => void;
};

type PlaceholderRow = {
  key: string;
  value: string;
};

const channelLabels: Record<NotificationTemplate["channel"], string> = {
  email: "E-posta",
  push: "Push",
  sms: "SMS",
  in_app: "In-App",
};

const isChannelSupported = (
  template: NotificationTemplate | null | undefined,
  channel: NotificationTemplate["channel"],
) => {
  if (!template) {
    return true;
  }
  return template.channel === channel;
};

const variableGroupLabels: Record<string, string> = {
  user: "Kullanıcı",
  reservation: "Rezervasyon",
  teacher: "Öğretmen",
  student: "Öğrenci",
  system: "Sistem",
};

export function NotificationTemplatesCard({ onSelectTemplate }: NotificationTemplatesCardProps) {
  const queryClient = useQueryClient();
  const { data, isLoading, isRefetching, refetch } = useNotificationTemplates();
  const templates = useMemo(() => data?.templates ?? [], [data]);
  const {
    data: templateVariablesData,
    isLoading: templateVariablesLoading,
  } = useNotificationTemplateVariables();
  const variableGroups = useMemo(() => templateVariablesData?.groups ?? {}, [templateVariablesData]);

  const [isDialogOpen, setDialogOpen] = useState(false);
  const [editingTemplate, setEditingTemplate] = useState<NotificationTemplate | null>(null);
  const [activeChannelFilter, setActiveChannelFilter] = useState<NotificationTemplate["channel"] | "all">("all");
  const [statusFilter, setStatusFilter] = useState<NotificationTemplate["status"] | "all">("all");
  const [previewDialogOpen, setPreviewDialogOpen] = useState(false);
  const [testDialogOpen, setTestDialogOpen] = useState(false);
  const [previewTemplate, setPreviewTemplate] = useState<NotificationTemplate | null>(null);
  const [testTemplate, setTestTemplate] = useState<NotificationTemplate | null>(null);
  const [previewPlaceholders, setPreviewPlaceholders] = useState<PlaceholderRow[]>([]);
  const [testPlaceholders, setTestPlaceholders] = useState<PlaceholderRow[]>([]);
  const [previewChannel, setPreviewChannel] = useState<NotificationTemplate["channel"]>("email");
  const [previewGroupFilter, setPreviewGroupFilter] = useState<string>("all");
  const [testGroupFilter, setTestGroupFilter] = useState<string>("all");
  const [previewResult, setPreviewResult] = useState<{
    subject: string;
    body: string;
    channel: NotificationTemplate["channel"];
  } | null>(null);
  const [testResult, setTestResult] = useState<{
    subject: string;
    body: string;
    channel: NotificationTemplate["channel"];
  } | null>(null);
  const [testMessage, setTestMessage] = useState<string | null>(null);
  const [testChannelResponse, setTestChannelResponse] = useState<Record<string, unknown> | null>(null);
  const [testChannel, setTestChannel] = useState<NotificationTemplate["channel"]>("email");
  const [testRecipient, setTestRecipient] = useState("");
  const [testUserId, setTestUserId] = useState("");

  const channelOptions = useMemo(
    () => [
      {
        value: "email" as NotificationTemplate["channel"],
        label: "E-posta",
        icon: <Mail className="h-3.5 w-3.5" />,
      },
      {
        value: "push" as NotificationTemplate["channel"],
        label: "Push",
        icon: <Bell className="h-3.5 w-3.5" />,
      },
      {
        value: "sms" as NotificationTemplate["channel"],
        label: "SMS",
        icon: <MessageSquare className="h-3.5 w-3.5" />,
      },
      {
        value: "in_app" as NotificationTemplate["channel"],
        label: "In-App",
        icon: <Monitor className="h-3.5 w-3.5" />,
      },
    ],
    [],
  );

  const createPlaceholderRows = (template?: NotificationTemplate | null): PlaceholderRow[] => {
    if (!template?.variables?.length) {
      return [];
    }

    return template.variables.map((variable) => ({
      key: variable,
      value: "",
    }));
  };

  useEffect(() => {
    if (testTemplate) {
      setTestChannel(testTemplate.channel);
      setTestRecipient("");
      setTestUserId("");
    }
  }, [testTemplate]);

  useEffect(() => {
    setPreviewResult((prev) => {
      if (!prev) {
        return prev;
      }
      if (prev.channel === previewChannel) {
        return prev;
      }
      return {
        ...prev,
        channel: previewChannel,
      };
    });
  }, [previewChannel]);

  const addPlaceholderRow = (setter: Dispatch<SetStateAction<PlaceholderRow[]>>, key = "") => {
    setter((rows) => [...rows, { key, value: "" }]);
  };

  const ensurePlaceholderRow = (setter: Dispatch<SetStateAction<PlaceholderRow[]>>, key: string) => {
    setter((rows) => {
      const normalized = key.trim();
      if (!normalized) {
        return rows;
      }
      if (rows.some((row) => row.key === normalized)) {
        return rows;
      }
      return [...rows, { key: normalized, value: "" }];
    });
  };

  const updatePlaceholderRow = (
    setter: Dispatch<SetStateAction<PlaceholderRow[]>>,
    index: number,
    patch: Partial<PlaceholderRow>,
  ) => {
    setter((rows) =>
      rows.map((row, i) => (i === index ? { ...row, ...patch } : row)),
    );
  };

  const removePlaceholderRow = (setter: Dispatch<SetStateAction<PlaceholderRow[]>>, index: number) => {
    setter((rows) => rows.filter((_, i) => i !== index));
  };

  const previewPlaceholderObject = useMemo(() => {
    return previewPlaceholders.reduce<Record<string, string>>((acc, row) => {
      const key = row.key.trim();
      if (key) {
        acc[key] = row.value;
      }
      return acc;
    }, {});
  }, [previewPlaceholders]);

  const testPlaceholderObject = useMemo(() => {
    return testPlaceholders.reduce<Record<string, string>>((acc, row) => {
      const key = row.key.trim();
      if (key) {
        acc[key] = row.value;
      }
      return acc;
    }, {});
  }, [testPlaceholders]);

  const variableGroupEntries = useMemo(() => Object.entries(variableGroups), [variableGroups]);
  const filteredPreviewGroups = useMemo(() => {
    if (previewGroupFilter === "all") {
      return variableGroupEntries;
    }
    return variableGroupEntries.filter(([group]) => group === previewGroupFilter);
  }, [variableGroupEntries, previewGroupFilter]);
  const filteredTestGroups = useMemo(() => {
    if (testGroupFilter === "all") {
      return variableGroupEntries;
    }
    return variableGroupEntries.filter(([group]) => group === testGroupFilter);
  }, [variableGroupEntries, testGroupFilter]);
  const testRecipientLabel = useMemo(() => {
    switch (testChannel) {
      case "email":
        return "Alıcı e-postası";
      case "push":
        return "FCM cihaz tokenı (opsiyonel)";
      case "sms":
        return "Telefon numarası";
      default:
        return "Alıcı";
    }
  }, [testChannel]);
  const testRecipientPlaceholder = useMemo(() => {
    switch (testChannel) {
      case "email":
        return "ornek@domain.com";
      case "push":
        return "cihaz tokenı";
      case "sms":
        return "+905321234567";
      default:
        return "";
    }
  }, [testChannel]);
  const testRecipientHint = useMemo(() => {
    switch (testChannel) {
      case "push":
        return "Kullanıcı ID girmezseniz cihaz tokenı ile gönderim yapılır.";
      case "sms":
        return "Numarayı uluslararası formatta girin (örn. +905321234567).";
      case "email":
        return "SMTP ayarlarınızın yapılandırıldığından emin olun.";
      default:
        return undefined;
    }
  }, [testChannel]);
  const testUserIdHint = useMemo(() => {
    switch (testChannel) {
      case "push":
        return "Kullanıcıda kayıtlı FCM tokenları varsa otomatik olarak kullanılır.";
      case "in_app":
        return "In-app bildirimi seçilen kullanıcının panelinde görüntülenir.";
      default:
        return undefined;
    }
  }, [testChannel]);

  useEffect(() => {
    if (previewGroupFilter !== "all" && !variableGroups[previewGroupFilter]) {
      setPreviewGroupFilter("all");
    }
    if (testGroupFilter !== "all" && !variableGroups[testGroupFilter]) {
      setTestGroupFilter("all");
    }
  }, [variableGroups, previewGroupFilter, testGroupFilter]);

  const openPreviewDialog = (template: NotificationTemplate) => {
    setPreviewTemplate(template);
    setPreviewPlaceholders(createPlaceholderRows(template));
    setPreviewChannel(template.channel);
    setPreviewResult(null);
    setPreviewDialogOpen(true);
  };

  const closePreviewDialog = () => {
    setPreviewDialogOpen(false);
    setPreviewTemplate(null);
    setPreviewPlaceholders([]);
    setPreviewResult(null);
    setPreviewChannel("email");
  };

  const openTestDialog = (template: NotificationTemplate) => {
    setTestTemplate(template);
    setTestPlaceholders(createPlaceholderRows(template));
    setTestChannel(template.channel);
    setTestResult(null);
    setTestMessage(null);
    setTestChannelResponse(null);
    setTestDialogOpen(true);
  };

  const closeTestDialog = () => {
    setTestDialogOpen(false);
    setTestTemplate(null);
    setTestPlaceholders([]);
    setTestResult(null);
    setTestMessage(null);
    setTestChannelResponse(null);
    setTestChannel("email");
  };

  const handlePreviewSubmit = () => {
    if (!previewTemplate) {
      toast.error("Önizleme için bir şablon seçilemedi.");
      return;
    }

    previewMutation.mutate({
      placeholders: Object.keys(previewPlaceholderObject).length
        ? previewPlaceholderObject
        : null,
    });
  };

  const handleTestSend = () => {
    if (!testTemplate) {
      toast.error("Test için bir şablon seçilemedi.");
      return;
    }

    const trimmedRecipient = testRecipient.trim();
    const trimmedUserId = testUserId.trim();

    if (testChannel === "email" && !trimmedRecipient) {
      toast.error("Test e-postası için alıcı e-postasını girin.");
      return;
    }

    if (testChannel === "sms" && !trimmedRecipient) {
      toast.error("SMS testi için telefon numarası girin.");
      return;
    }

    if (testChannel === "push" && !trimmedRecipient && !trimmedUserId) {
      toast.error("Push testi için kullanıcı ID veya cihaz tokenı girin.");
      return;
    }

    if (testChannel === "in_app" && !trimmedUserId) {
      toast.error("In-app bildirimi için kullanıcı ID gereklidir.");
      return;
    }

    const parsedUserId = trimmedUserId
      ? Number.parseInt(trimmedUserId, 10)
      : undefined;

    if (parsedUserId !== undefined && Number.isNaN(parsedUserId)) {
      toast.error("Kullanıcı ID sayısal olmalıdır.");
      return;
    }

    setTestChannelResponse(null);
    testSendMutation.mutate({
      channel: testChannel,
      recipient: trimmedRecipient || undefined,
      user_id: parsedUserId,
      placeholders: Object.keys(testPlaceholderObject).length
        ? testPlaceholderObject
        : undefined,
    });
  };

  const form = useForm<NotificationTemplateFormSchema>({
    resolver: zodResolver(notificationTemplateSchema),
    defaultValues: {
      name: "",
      slug: "",
      channel: "email",
      subject: "",
      body: "",
      variables: [],
      action_url: "",
      action_text: "",
      is_default: false,
      status: "draft",
    },
  });

  useEffect(() => {
    if (editingTemplate) {
      form.reset({
        name: editingTemplate.name,
        slug: editingTemplate.slug,
        channel: editingTemplate.channel,
        subject: editingTemplate.subject ?? "",
        body: editingTemplate.body,
        variables: editingTemplate.variables ?? [],
        action_url: editingTemplate.action_url ?? "",
        action_text: editingTemplate.action_text ?? "",
        is_default: editingTemplate.is_default,
        status: editingTemplate.status,
      });
    } else {
      form.reset({
        name: "",
        slug: "",
        channel: "email",
        subject: "",
        body: "",
        variables: [],
        action_url: "",
        action_text: "",
        is_default: false,
        status: "draft",
      });
    }
  }, [editingTemplate, form]);

  const createMutation = useMutationToast(createNotificationTemplate, {
    successMessage: "Şablon oluşturuldu.",
    onSuccess: () => {
      setDialogOpen(false);
      setEditingTemplate(null);
      queryClient.invalidateQueries({ queryKey: notificationTemplatesQueryKey });
    },
  });

  const updateMutation = useMutationToast(
    ({ id, payload }: { id: number; payload: Partial<NotificationTemplatePayload> }) =>
      updateNotificationTemplate(id, payload),
    {
      successMessage: "Şablon güncellendi.",
      onSuccess: () => {
        setDialogOpen(false);
        setEditingTemplate(null);
        queryClient.invalidateQueries({ queryKey: notificationTemplatesQueryKey });
      },
    },
  );

  const publishMutation = useMutationToast(publishNotificationTemplate, {
    successMessage: "Şablon yayınlandı.",
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notificationTemplatesQueryKey });
    },
  });

  const archiveMutation = useMutationToast(archiveNotificationTemplate, {
    successMessage: "Şablon arşivlendi.",
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notificationTemplatesQueryKey });
    },
  });

  const duplicateMutation = useMutationToast(duplicateNotificationTemplate, {
    successMessage: "Şablon kopyalandı.",
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notificationTemplatesQueryKey });
    },
  });

  const previewMutation = useMutation({
    mutationFn: async (payload: { placeholders?: Record<string, string> | null }) => {
      if (!previewTemplate) {
        throw new Error("Önizlenecek şablon bulunamadı.");
      }

      return renderNotificationTemplate(previewTemplate.id, payload);
    },
    onSuccess: (data) => {
      setPreviewResult({
        channel: previewChannel || data.preview.channel,
        subject: data.preview.subject,
        body: data.preview.body,
      });
    },
    onError: (error: unknown) => {
      const message =
        error instanceof Error ? error.message : "Önizleme oluşturulamadı.";
      toast.error(message);
    },
  });

  const testSendMutation = useMutation({
    mutationFn: async (payload: {
      channel: NotificationTemplate["channel"];
      recipient?: string;
      user_id?: number;
      placeholders?: Record<string, string>;
    }) => {
      if (!testTemplate) {
        throw new Error("Test edilecek şablon bulunamadı.");
      }

      return testSendNotificationTemplate(testTemplate.id, payload);
    },
    onSuccess: (data) => {
      setTestResult({
        channel: testChannel || data.preview.channel,
        subject: data.preview.subject,
        body: data.preview.body,
      });
      setTestMessage(data.message ?? null);
      setTestChannelResponse(data.channel_response ?? null);
      toast.success(data.message ?? "Test gönderimi tamamlandı.");
    },
    onError: (error: unknown) => {
      const message =
        error instanceof Error
          ? error.message
          : "Test gönderim simülasyonu başarısız.";
      toast.error(message);
    },
  });

  const isProcessing =
    createMutation.isPending ||
    updateMutation.isPending ||
    publishMutation.isPending ||
    archiveMutation.isPending ||
    duplicateMutation.isPending;
  const isPreviewLoading = previewMutation.isPending;
  const isTestLoading = testSendMutation.isPending;

  const onSubmit = form.handleSubmit((values) => {
    const payload: NotificationTemplatePayload = {
      name: values.name,
      slug: values.slug || undefined,
      channel: values.channel,
      subject: values.subject || undefined,
      body: values.body,
      variables: values.variables ?? [],
      action_url: values.action_url || undefined,
      action_text: values.action_text || undefined,
      is_default: values.is_default,
      status: values.status,
    };

    if (editingTemplate) {
      updateMutation.mutate({ id: editingTemplate.id, payload });
    } else {
      createMutation.mutate(payload);
    }
  });

  const filteredTemplates = useMemo(() => {
    return templates.filter((template) => {
      const channelMatch = activeChannelFilter === "all" || template.channel === activeChannelFilter;
      const statusMatch = statusFilter === "all" || template.status === statusFilter;
      return channelMatch && statusMatch;
    });
  }, [templates, activeChannelFilter, statusFilter]);

  return (
    <section className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="text-lg font-semibold text-slate-100">Bildirim şablonları</h3>
          <p className="text-xs text-slate-400">
            E-posta, push veya SMS bildirimleri için dinamik şablonlar oluşturun.
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
          <Dialog
            open={isDialogOpen}
            onOpenChange={(open) => {
              setDialogOpen(open);
              if (!open) {
                setEditingTemplate(null);
              }
            }}
          >
            <DialogTrigger asChild>
              <Button
                size="sm"
                onClick={() => {
                  setEditingTemplate(null);
                  setDialogOpen(true);
                }}
              >
                <Plus className="mr-2 h-4 w-4" />
                Yeni şablon
              </Button>
            </DialogTrigger>
            <DialogContent className="max-w-3xl">
              <DialogHeader>
                <DialogTitle>{editingTemplate ? "Şablonu düzenle" : "Yeni bildirim şablonu"}</DialogTitle>
                <DialogDescription>
                  Bildirim içeriğini kanala göre özelleştirin. Şablon yayınlandığında planlanmış bildirimlerde kullanabilirsiniz.
                </DialogDescription>
              </DialogHeader>
              <form onSubmit={onSubmit} className="space-y-4">
                <div className="grid gap-3 md:grid-cols-2">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Şablon adı
                    </label>
                    <Input placeholder="Örn. Rezervasyon Onayı" {...form.register("name")} />
                    {form.formState.errors.name ? (
                      <p className="text-xs text-red-400">{form.formState.errors.name.message}</p>
                    ) : null}
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Slug (isteğe bağlı)
                    </label>
                    <Input placeholder="rezervasyon-onayi" {...form.register("slug")} />
                    {form.formState.errors.slug ? (
                      <p className="text-xs text-red-400">{form.formState.errors.slug.message}</p>
                    ) : null}
                  </div>
                </div>

                <div className="grid gap-3 md:grid-cols-2">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Kanal
                    </label>
                    <select
                      className="w-full rounded-lg border border-slate-800 bg-slate-950 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
                      {...form.register("channel")}
                    >
                      <option value="email">E-posta</option>
                      <option value="push">Push</option>
                      <option value="sms">SMS</option>
                      <option value="in_app">In-App</option>
                    </select>
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
                      <option value="published">Yayınlandı</option>
                      <option value="archived">Arşivlendi</option>
                    </select>
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                    Konu (e-posta için)
                  </label>
                  <Input placeholder="Örn. Rezervasyonunuz onaylandı" {...form.register("subject")} />
                </div>

                <div className="space-y-2">
                  <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                    İçerik
                  </label>
                  <Textarea
                    rows={8}
                    placeholder="Merhaba {{user.name}}, rezervasyonunuz {{reservation.date}} tarihinde onaylandı."
                    {...form.register("body")}
                  />
                  {form.formState.errors.body ? (
                    <p className="text-xs text-red-400">{form.formState.errors.body.message}</p>
                  ) : null}
                </div>

                <div className="grid gap-3 md:grid-cols-2">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Buton URL
                    </label>
                    <Input placeholder="https://example.com" {...form.register("action_url")} />
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Buton metni
                    </label>
                    <Input placeholder="Detayları Gör" {...form.register("action_text")} />
                  </div>
                </div>

                <div className="space-y-2 rounded-xl border border-slate-800/60 bg-slate-950/60 p-3 text-xs text-slate-300">
                  <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                    Kullanılabilir değişkenler
                  </label>
                  <div className="space-y-2">
                    {templateVariablesLoading ? (
                      <Skeleton className="h-8 w-full" />
                    ) : variableGroupEntries.length ? (
                      variableGroupEntries.map(([group, variables]) => (
                        <div key={`form-${group}`} className="space-y-1">
                          <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                            {variableGroupLabels[group] ?? group}
                          </p>
                          <div className="flex flex-wrap gap-2">
                            {variables.map((variable) => (
                              <Badge
                                key={`form-${group}-${variable}`}
                                variant="outline"
                                className="border-slate-700 text-slate-300"
                              >
                                {`{{${variable}}}`}
                              </Badge>
                            ))}
                          </div>
                        </div>
                      ))
                    ) : (
                      <p className="text-[11px] text-slate-500">
                        Hazır değişken listesi yüklenemedi. Şablon içeriğinde {"{{placeholder}}"} formatını kullanabilirsiniz.
                      </p>
                    )}
                  </div>
                  <div className="flex items-center gap-2 pt-2">
                    <Checkbox
                      // eslint-disable-next-line react-hooks/incompatible-library
                      checked={form.watch("is_default")}
                      onCheckedChange={(checked) => form.setValue("is_default", Boolean(checked))}
                      id="template-default"
                    />
                    <label htmlFor="template-default" className="text-xs text-slate-400">
                      Bu kanaldaki varsayılan şablon olsun
                    </label>
                  </div>
                </div>

                <div className="flex items-center justify-end gap-2">
                  <Button
                    type="button"
                    variant="ghost"
                    onClick={() => {
                      setDialogOpen(false);
                      setEditingTemplate(null);
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

      <div className="flex flex-wrap items-center gap-2 text-xs text-slate-400">
        <div className="flex items-center gap-2">
          <span>Kanallar:</span>
          {(["all", "email", "push", "sms", "in_app"] as const).map((channel) => (
            <button
              key={channel}
              type="button"
              onClick={() => setActiveChannelFilter(channel as (typeof activeChannelFilter))}
              className={cn(
                "rounded-full border border-slate-800/60 px-3 py-1 transition-colors hover:bg-slate-900/60",
                activeChannelFilter === channel ? "border-sky-500/40 text-sky-300" : "text-slate-400",
              )}
            >
              {channel === "all" ? "Tümü" : channelLabels[channel as NotificationTemplate["channel"]]}
            </button>
          ))}
        </div>
        <div className="flex items-center gap-2">
          <span>Durum:</span>
          {(["all", "draft", "published", "archived"] as const).map((status) => (
            <button
              key={status}
              type="button"
              onClick={() => setStatusFilter(status as (typeof statusFilter))}
              className={cn(
                "rounded-full border border-slate-800/60 px-3 py-1 transition-colors hover:bg-slate-900/60",
                statusFilter === status ? "border-sky-500/40 text-sky-300" : "text-slate-400",
              )}
            >
              {status === "all"
                ? "Tümü"
                : status === "draft"
                  ? "Taslak"
                  : status === "published"
                    ? "Yayınlandı"
                    : "Arşivlendi"}
            </button>
          ))}
        </div>
      </div>

      {isLoading ? (
        <NotificationTemplatesSkeleton />
      ) : filteredTemplates.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="space-y-3">
          {filteredTemplates.map((template) => (
            <div
              key={template.id}
              className="rounded-2xl border border-slate-800/60 bg-slate-950/60 p-4 text-xs text-slate-300"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="space-y-2">
                  <div className="flex items-center gap-2">
                    <h4 className="text-sm font-semibold text-slate-100">{template.name}</h4>
                    <Badge variant="outline" className="border-slate-700 text-slate-300">
                      {channelLabels[template.channel]}
                    </Badge>
                    <Badge
                      variant={
                        template.status === "published"
                          ? "success"
                          : template.status === "draft"
                            ? "secondary"
                            : "outline"
                      }
                    >
                      {template.status === "published"
                        ? "Yayınlandı"
                        : template.status === "draft"
                          ? "Taslak"
                          : "Arşiv"}
                    </Badge>
                    {template.is_default ? (
                      <Badge variant="default" className="bg-sky-600/80">
                        Varsayılan
                      </Badge>
                    ) : null}
                  </div>
                  {template.subject ? (
                    <p className="text-slate-400">
                      <strong>Konu:</strong> {template.subject}
                    </p>
                  ) : null}
                  <p className="text-slate-400 line-clamp-3">{template.body}</p>
                  <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-500">
                    <span>
                      Son güncelleme:{" "}
                      {template.updated_at
                        ? format(new Date(template.updated_at), "d MMM yyyy HH:mm", { locale: tr })
                        : "-"}
                    </span>
                    {template.updated_by ? (
                      <span>• {template.updated_by.name}</span>
                    ) : null}
                  </div>
                </div>

                <div className="flex flex-col items-end gap-2">
                  <div className="flex flex-wrap justify-end gap-2">
                    <Button
                      size="sm"
                      variant="outline"
                      className="text-xs"
                      onClick={() => {
                        setEditingTemplate(template);
                        setDialogOpen(true);
                      }}
                    >
                      <Pencil className="mr-1 h-3 w-3" />
                      Düzenle
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="text-xs"
                      onClick={() => duplicateMutation.mutate(template.id)}
                    >
                      <Copy className="mr-1 h-3 w-3" />
                      Kopyala
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="text-xs"
                      onClick={() => openPreviewDialog(template)}
                    >
                      <Eye className="mr-1 h-3 w-3" />
                      Önizle
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="text-xs"
                      onClick={() => openTestDialog(template)}
                    >
                      <Send className="mr-1 h-3 w-3" />
                      Test gönder
                    </Button>
                    {template.status !== "published" ? (
                      <Button
                        size="sm"
                        variant="outline"
                        className="text-xs text-emerald-300 hover:text-emerald-200"
                        onClick={() => publishMutation.mutate(template.id)}
                      >
                        <Rocket className="mr-1 h-3 w-3" />
                        Yayınla
                      </Button>
                    ) : null}
                    {template.status !== "archived" ? (
                      <Button
                        size="sm"
                        variant="ghost"
                        className="text-xs text-amber-300 hover:text-amber-200"
                        onClick={() => archiveMutation.mutate(template.id)}
                      >
                        <Archive className="mr-1 h-3 w-3" />
                        Arşivle
                      </Button>
                    ) : null}
                    {onSelectTemplate ? (
                      <Button
                        size="sm"
                        variant="secondary"
                        className="text-xs"
                        onClick={() => onSelectTemplate(template)}
                      >
                        <Check className="mr-1 h-3 w-3" />
                        Şablonu kullan
                      </Button>
                    ) : null}
                  </div>
                  {template.variables && template.variables.length ? (
                    <div className="flex flex-wrap justify-end gap-1 text-[11px] text-slate-500">
                      {template.variables.slice(0, 6).map((variable) => (
                        <Badge
                          key={variable}
                          variant="outline"
                          className="border-slate-700 text-slate-300"
                        >
                          {`{{${variable}}}`}
                        </Badge>
                      ))}
                      {template.variables.length > 6 ? (
                        <span>+{template.variables.length - 6}</span>
                      ) : null}
                    </div>
                  ) : null}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <Dialog
        open={previewDialogOpen}
        onOpenChange={(open) => {
          if (open) {
            setPreviewDialogOpen(true);
          } else {
            closePreviewDialog();
          }
        }}
      >
        <DialogContent className="max-w-4xl">
          <DialogHeader>
            <DialogTitle>Şablon önizleme</DialogTitle>
            <DialogDescription>
              {previewTemplate
                ? `${previewTemplate.name} şablonundaki dinamik içerikleri örnek verilerle görüntüleyin.`
                : "Önizleme almak için bir şablon seçin."}
            </DialogDescription>
          </DialogHeader>

          {previewTemplate ? (
            <div className="space-y-6">
              <div className="grid gap-6 md:grid-cols-2">
                <div className="space-y-4">
                  <div className="space-y-3">
                    <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Değişken değerleri
                    </p>
                    <div className="space-y-3">
                      {previewPlaceholders.map((row, index) => (
                        <div
                          key={`${row.key}-${index}`}
                          className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]"
                        >
                          <Input
                            value={row.key}
                            placeholder="ör. user.name"
                            onChange={(event) =>
                              updatePlaceholderRow(setPreviewPlaceholders, index, {
                                key: event.target.value,
                              })
                            }
                          />
                          <Input
                            value={row.value}
                            placeholder="ör. Nazlı Yavuz"
                            onChange={(event) =>
                              updatePlaceholderRow(setPreviewPlaceholders, index, {
                                value: event.target.value,
                              })
                            }
                          />
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => removePlaceholderRow(setPreviewPlaceholders, index)}
                            aria-label="Değişkeni kaldır"
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      ))}
                    </div>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="text-xs"
                      onClick={() => addPlaceholderRow(setPreviewPlaceholders)}
                    >
                      <Plus className="mr-2 h-4 w-4" />
                      Değişken ekle
                    </Button>
                  </div>

                  <div className="space-y-3">
                    <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Şablonda kullanılan değişkenler
                    </p>
                    <div className="flex flex-wrap gap-2">
                      {previewTemplate.variables?.length ? (
                        previewTemplate.variables.map((variable) => (
                          <Badge
                            key={variable}
                            variant="outline"
                            className="cursor-pointer border-slate-700 text-slate-200 hover:border-sky-500/40 hover:text-sky-300"
                            onClick={() => ensurePlaceholderRow(setPreviewPlaceholders, variable)}
                          >
                            {`{{${variable}}}`}
                          </Badge>
                        ))
                      ) : (
                        <p className="text-[11px] text-slate-500">
                          Bu şablon için tanımlı değişken bulunmuyor. Aşağıdaki hazır değişkenlerden ekleyebilirsiniz.
                        </p>
                      )}
                    </div>
                  </div>

                  <div className="space-y-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                        Hazır değişken katalogu
                      </p>
                      {variableGroupEntries.length ? (
                        <ToggleGroup
                          type="single"
                          value={previewGroupFilter}
                          onValueChange={(value) => setPreviewGroupFilter((value as string) || "all")}
                          className="flex flex-wrap gap-2"
                        >
                          <ToggleGroupItem
                            value="all"
                            className="h-7 rounded-full border border-slate-800 bg-slate-900/60 px-3 py-1 text-xs text-slate-300 transition data-[state=on]:border-sky-500/40 data-[state=on]:bg-sky-500/10 data-[state=on]:text-sky-200"
                          >
                            Tümü
                          </ToggleGroupItem>
                          {variableGroupEntries.map(([group]) => (
                            <ToggleGroupItem
                              key={`preview-group-${group}`}
                              value={group}
                              className="h-7 rounded-full border border-slate-800 bg-slate-900/60 px-3 py-1 text-xs text-slate-300 transition data-[state=on]:border-sky-500/40 data-[state=on]:bg-sky-500/10 data-[state=on]:text-sky-200"
                            >
                              {variableGroupLabels[group] ?? group}
                            </ToggleGroupItem>
                          ))}
                        </ToggleGroup>
                      ) : null}
                    </div>
                    {templateVariablesLoading ? (
                      <Skeleton className="h-10 w-full" />
                    ) : !variableGroupEntries.length ? (
                      <p className="text-[11px] text-slate-500">
                        Hazır değişken listesi yüklenemedi. Şablon içeriğinde {"{{placeholder}}"} formatını kullanabilirsiniz.
                      </p>
                    ) : filteredPreviewGroups.length ? (
                      <div className="space-y-3">
                        {filteredPreviewGroups.map(([group, variables]) => (
                          <div key={`preview-block-${group}`} className="space-y-1">
                            <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                              {variableGroupLabels[group] ?? group}
                            </p>
                            <div className="flex flex-wrap gap-2">
                              {variables.map((variable) => (
                                <Badge
                                  key={`preview-${group}-${variable}`}
                                  variant="outline"
                                  className="cursor-pointer border-slate-800 text-slate-300 hover:border-sky-500/40 hover:text-sky-200"
                                  onClick={() => ensurePlaceholderRow(setPreviewPlaceholders, variable)}
                                >
                                  {`{{${variable}}}`}
                                </Badge>
                              ))}
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="text-[11px] text-slate-500">
                        Bu kategoride listelenebilecek değişken bulunmuyor.
                      </p>
                    )}
                  </div>
                </div>

                <div className="space-y-4">
                  <div className="space-y-2 rounded-2xl border border-slate-800/60 bg-slate-950/60 p-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                        Kanal seçimi
                      </p>
                      <ToggleGroup
                        type="single"
                        value={previewChannel}
                        onValueChange={(value) => {
                          if (!value) {
                            return;
                          }
                          setPreviewChannel(value as NotificationTemplate["channel"]);
                        }}
                        className="flex flex-wrap gap-2"
                      >
                        {channelOptions.map((option) => (
                          <ToggleGroupItem
                            key={`preview-channel-${option.value}`}
                            value={option.value}
                            disabled={!isChannelSupported(previewTemplate, option.value)}
                            className={cn(
                              "flex items-center gap-2 rounded-full border border-slate-800 bg-slate-900/60 px-3 py-1 text-xs text-slate-300 transition data-[state=on]:border-sky-500/40 data-[state=on]:bg-sky-500/10 data-[state=on]:text-sky-200",
                              !isChannelSupported(previewTemplate, option.value) && "opacity-50",
                            )}
                          >
                            {option.icon}
                            <span>{option.label}</span>
                          </ToggleGroupItem>
                        ))}
                      </ToggleGroup>
                    </div>
                    {!isChannelSupported(previewTemplate, previewChannel) ? (
                      <div className="flex items-center gap-2 rounded-lg border border-amber-600/50 bg-amber-500/10 px-3 py-2 text-[11px] text-amber-300">
                        <AlertCircle className="h-4 w-4" />
                        <span>Bu şablon seçilen kanalı desteklemiyor. Önizleme gerçek kanal içeriği ile sınırlı olacaktır.</span>
                      </div>
                    ) : (
                      <p className="text-[11px] text-slate-500">
                        Şablon varsayılan kanalı: {channelLabels[previewTemplate.channel]}
                      </p>
                    )}
                  </div>

                  <div className="rounded-2xl border border-slate-800/60 bg-slate-950/60 p-4">
                    <div className="flex items-center justify-between">
                      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                        Önizleme
                      </p>
                      <Badge variant="outline" className="border-slate-800 text-slate-300">
                        {channelLabels[
                          (previewResult?.channel ?? previewChannel ?? previewTemplate.channel) as NotificationTemplate["channel"]
                        ]}
                      </Badge>
                    </div>

                    <div className="mt-4 space-y-3 text-sm text-slate-200">
                      <div>
                        <p className="text-xs uppercase tracking-wide text-slate-500">Konu</p>
                        <p className="mt-1 rounded-lg border border-slate-800/60 bg-slate-950/70 px-3 py-2 text-sm text-slate-100">
                          {previewResult?.subject ?? previewTemplate.subject ?? "—"}
                        </p>
                      </div>

                      <div>
                        <p className="text-xs uppercase tracking-wide text-slate-500">İleti</p>
                        <div className="mt-1 max-h-80 overflow-auto rounded-lg border border-slate-800/60 bg-slate-950/70 px-3 py-3 text-xs leading-relaxed text-slate-200 whitespace-pre-wrap">
                          {isPreviewLoading ? (
                            <div className="flex items-center gap-2 text-slate-400">
                              <Loader2 className="h-4 w-4 animate-spin" />
                              Önizleme oluşturuluyor...
                            </div>
                          ) : previewResult ? (
                            previewResult.body || "—"
                          ) : (
                            "Önizleme almak için değişken değerlerini girin ve 'Önizleme oluştur' butonuna tıklayın."
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-end gap-2">
                <Button type="button" variant="ghost" onClick={closePreviewDialog}>
                  Kapat
                </Button>
                <Button
                  type="button"
                  onClick={handlePreviewSubmit}
                  disabled={isPreviewLoading}
                >
                  {isPreviewLoading ? (
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  ) : (
                    <Eye className="mr-2 h-4 w-4" />
                  )}
                  Önizleme oluştur
                </Button>
              </div>
            </div>
          ) : (
            <p className="text-sm text-slate-400">
              Önizleme almak için listeden bir bildirim şablonu seçin.
            </p>
          )}
        </DialogContent>
      </Dialog>

      <Dialog
        open={testDialogOpen}
        onOpenChange={(open) => {
          if (open) {
            setTestDialogOpen(true);
          } else {
            closeTestDialog();
          }
        }}
      >
        <DialogContent className="max-w-4xl">
          <DialogHeader>
            <DialogTitle>Test gönderimi</DialogTitle>
            <DialogDescription>
              Şablonu SMTP, push veya SMS entegrasyonlarınızı kullanarak gerçek alıcı bilgilerinde deneyin.
            </DialogDescription>
          </DialogHeader>

          {testTemplate ? (
            <div className="space-y-6">
              <div className="grid gap-6 md:grid-cols-2">
                <div className="space-y-4">
                  <div className="grid gap-3 sm:grid-cols-2">
                    <div className="space-y-2">
                      <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                        Kanal
                      </label>
                      <ToggleGroup
                        type="single"
                        value={testChannel}
                        onValueChange={(value) => {
                          if (!value) {
                            return;
                          }
                          setTestChannel(value as NotificationTemplate["channel"]);
                        }}
                        className="flex flex-wrap gap-2"
                      >
                        {channelOptions.map((option) => (
                          <ToggleGroupItem
                            key={`test-channel-${option.value}`}
                            value={option.value}
                            disabled={!isChannelSupported(testTemplate, option.value)}
                            className={cn(
                              "flex items-center gap-2 rounded-full border border-slate-800 bg-slate-900/60 px-3 py-1 text-xs text-slate-300 transition data-[state=on]:border-sky-500/40 data-[state=on]:bg-sky-500/10 data-[state=on]:text-sky-200",
                              !isChannelSupported(testTemplate, option.value) && "opacity-50",
                            )}
                          >
                            {option.icon}
                            <span>{option.label}</span>
                          </ToggleGroupItem>
                        ))}
                      </ToggleGroup>
                      {!isChannelSupported(testTemplate, testChannel) ? (
                        <div className="mt-2 flex items-center gap-2 rounded-lg border border-amber-600/50 bg-amber-500/10 px-3 py-2 text-[11px] text-amber-300">
                          <AlertCircle className="h-4 w-4" />
                          <span>Bu şablon seçilen kanalı desteklemiyor. Test gönderimi gerçek kanalda çalışır.</span>
                        </div>
                      ) : (
                        <p className="text-[11px] text-slate-500">
                          Şablon varsayılan kanalı: {channelLabels[testTemplate.channel]}
                        </p>
                      )}
                    </div>
                    <div className="space-y-2">
                      <label className="space-y-1 text-xs text-slate-300">
                        <span className="block text-[11px] font-semibold uppercase tracking-wide text-slate-400">
                          {testRecipientLabel}
                        </span>
                        <Input
                          value={testRecipient}
                          placeholder={testRecipientPlaceholder}
                          onChange={(event) => setTestRecipient(event.target.value)}
                        />
                        {testRecipientHint ? (
                          <span className="text-[11px] text-slate-500">{testRecipientHint}</span>
                        ) : null}
                      </label>
                    </div>
                  </div>
                  {["push", "in_app"].includes(testChannel) ? (
                    <div className="space-y-2">
                      <label className="space-y-1 text-xs text-slate-300">
                        <span className="block text-[11px] font-semibold uppercase tracking-wide text-slate-400">
                          Kullanıcı ID
                        </span>
                        <Input
                          value={testUserId}
                          placeholder="Örn. 123"
                          onChange={(event) => setTestUserId(event.target.value)}
                        />
                        {testUserIdHint ? (
                          <span className="text-[11px] text-slate-500">{testUserIdHint}</span>
                        ) : null}
                      </label>
                    </div>
                  ) : null}

                  <div className="space-y-3">
                    <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Değişken değerleri
                    </p>
                    <div className="space-y-3">
                      {testPlaceholders.map((row, index) => (
                        <div
                          key={`${row.key}-${index}`}
                          className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]"
                        >
                          <Input
                            value={row.key}
                            placeholder="ör. reservation.date"
                            onChange={(event) =>
                              updatePlaceholderRow(setTestPlaceholders, index, {
                                key: event.target.value,
                              })
                            }
                          />
                          <Input
                            value={row.value}
                            placeholder="ör. 12 Mayıs 2025"
                            onChange={(event) =>
                              updatePlaceholderRow(setTestPlaceholders, index, {
                                value: event.target.value,
                              })
                            }
                          />
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => removePlaceholderRow(setTestPlaceholders, index)}
                            aria-label="Değişkeni kaldır"
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      ))}
                    </div>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="text-xs"
                      onClick={() => addPlaceholderRow(setTestPlaceholders)}
                    >
                      <Plus className="mr-2 h-4 w-4" />
                      Değişken ekle
                    </Button>
                  </div>

                  <div className="space-y-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                        Hazır değişkenler
                      </p>
                      {variableGroupEntries.length ? (
                        <ToggleGroup
                          type="single"
                          value={testGroupFilter}
                          onValueChange={(value) => setTestGroupFilter((value as string) || "all")}
                          className="flex flex-wrap gap-2"
                        >
                          <ToggleGroupItem
                            value="all"
                            className="h-7 rounded-full border border-slate-800 bg-slate-900/60 px-3 py-1 text-xs text-slate-300 transition data-[state=on]:border-sky-500/40 data-[state=on]:bg-sky-500/10 data-[state=on]:text-sky-200"
                          >
                            Tümü
                          </ToggleGroupItem>
                          {variableGroupEntries.map(([group]) => (
                            <ToggleGroupItem
                              key={`test-toggle-${group}`}
                              value={group}
                              className="h-7 rounded-full border border-slate-800 bg-slate-900/60 px-3 py-1 text-xs text-slate-300 transition data-[state=on]:border-sky-500/40 data-[state=on]:bg-sky-500/10 data-[state=on]:text-sky-200"
                            >
                              {variableGroupLabels[group] ?? group}
                            </ToggleGroupItem>
                          ))}
                        </ToggleGroup>
                      ) : null}
                    </div>
                    {templateVariablesLoading ? (
                      <Skeleton className="h-10 w-full" />
                    ) : !variableGroupEntries.length ? (
                      <p className="text-[11px] text-slate-500">
                        Hazır değişken listesi yüklenemedi. Şablon içeriğinde {"{{placeholder}}"} formatını kullanabilirsiniz.
                      </p>
                    ) : filteredTestGroups.length ? (
                      <div className="space-y-3">
                        {filteredTestGroups.map(([group, variables]) => (
                          <div key={`test-${group}`} className="space-y-1">
                            <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                              {variableGroupLabels[group] ?? group}
                            </p>
                            <div className="flex flex-wrap gap-2">
                              {variables.map((variable) => (
                                <Badge
                                  key={`test-${group}-${variable}`}
                                  variant="outline"
                                  className="cursor-pointer border-slate-800 text-slate-300 hover:border-sky-500/40 hover:text-sky-200"
                                  onClick={() => ensurePlaceholderRow(setTestPlaceholders, variable)}
                                >
                                  {`{{${variable}}}`}
                                </Badge>
                              ))}
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="text-[11px] text-slate-500">
                        Bu kategoride listelenebilecek değişken bulunmuyor.
                      </p>
                    )}
                  </div>
                </div>

                <div className="space-y-4">
                  <div className="rounded-2xl border border-slate-800/60 bg-slate-950/60 p-4">
                    <div className="flex items-center justify-between">
                      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                        Test sonucu
                      </p>
                      <Badge variant="outline" className="border-slate-800 text-slate-300">
                        {channelLabels[
                          (testResult?.channel ?? testChannel) as NotificationTemplate["channel"]
                        ]}
                      </Badge>
                    </div>
                    <div className="mt-4 space-y-3 text-sm text-slate-200">
                      <div>
                        <p className="text-xs uppercase tracking-wide text-slate-500">Konu</p>
                        <p className="mt-1 rounded-lg border border-slate-800/60 bg-slate-950/70 px-3 py-2 text-sm text-slate-100">
                          {testResult?.subject ?? testTemplate.subject ?? "—"}
                        </p>
                      </div>
                      <div>
                        <p className="text-xs uppercase tracking-wide text-slate-500">İleti</p>
                        <div className="mt-1 max-h-80 overflow-auto rounded-lg border border-slate-800/60 bg-slate-950/70 px-3 py-3 text-xs leading-relaxed text-slate-200 whitespace-pre-wrap">
                          {isTestLoading ? (
                            <div className="flex items-center gap-2 text-slate-400">
                              <Loader2 className="h-4 w-4 animate-spin" />
                              Test simülasyonu hazırlanıyor...
                            </div>
                          ) : testResult ? (
                            testResult.body || "—"
                          ) : (
                            "Test sonucu hazır olduğunda burada görüntülenecek."
                          )}
                        </div>
                      </div>
                      {testMessage ? (
                        <p className="text-[11px] text-slate-500">{testMessage}</p>
                      ) : (
                        <p className="text-[11px] text-slate-500">
                          Test gönderimi ilgili servis entegrasyonları kullanılarak gerçekleştirilecektir.
                        </p>
                      )}
                      {testChannelResponse ? (
                        <div>
                          <p className="text-xs uppercase tracking-wide text-slate-500">Kanal yanıtı</p>
                          <pre className="mt-1 max-h-48 overflow-auto rounded-lg border border-slate-800/60 bg-slate-950/70 px-3 py-2 text-[11px] leading-relaxed text-slate-300">
                            {JSON.stringify(testChannelResponse, null, 2)}
                          </pre>
                        </div>
                      ) : null}
                    </div>
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-end gap-2">
                <Button type="button" variant="ghost" onClick={closeTestDialog}>
                  Kapat
                </Button>
                <Button type="button" onClick={handleTestSend} disabled={isTestLoading}>
                  {isTestLoading ? (
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  ) : (
                    <Send className="mr-2 h-4 w-4" />
                  )}
                  Test gönderimi yap
                </Button>
              </div>
            </div>
          ) : (
            <p className="text-sm text-slate-400">
              Test göndermek için listeden bir bildirim şablonu seçin.
            </p>
          )}
        </DialogContent>
      </Dialog>
    </section>
  );
}

function NotificationTemplatesSkeleton() {
  return (
    <div className="space-y-3">
      {Array.from({ length: 3 }).map((_, index) => (
        <div key={index} className="rounded-2xl border border-slate-800/60 bg-slate-950/60 p-4">
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
        <FileText className="h-6 w-6 text-slate-400" />
      </div>
      <div>
        <h4 className="text-sm font-semibold text-slate-200">Henüz şablon oluşturulmamış</h4>
        <p className="text-xs text-slate-500">
          Bildirimler için yeniden kullanılabilir şablonlar tasarlayarak zamandan tasarruf edebilirsiniz.
        </p>
      </div>
    </div>
  );
}

