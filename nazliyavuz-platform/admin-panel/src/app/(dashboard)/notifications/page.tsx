"use client";

import { useEffect, useMemo, useState } from "react";
import { useForm, type FieldErrors } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useNotificationSummary } from "@/hooks/use-notification-summary";
import { useNotificationAnalytics } from "@/hooks/use-notification-analytics";
import { useNotificationHistory } from "@/hooks/use-notification-history";
import { useMutationToast } from "@/hooks/use-mutation-toast";
import {
  sendBulkNotification,
  sendUserNotification,
  type SendNotificationPayload,
} from "@/lib/api/admin-notifications";
import {
  notificationSchema,
  targetedNotificationSchema,
  type NotificationFormSchema,
  type TargetedNotificationFormSchema,
} from "@/lib/validations/notification";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import {
  Bell,
  Target,
  Users2,
  CheckCircle2,
  TriangleAlert,
  Info,
  Flame,
  Loader2,
  History,
  UserSearch,
} from "lucide-react";
import { format, formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";
import { NotificationHistoryTable } from "@/components/admin/notifications/notification-history-table";
import { ScheduledNotificationsCard } from "@/components/admin/notifications/scheduled-notifications-card";
import { NotificationTemplatesCard } from "@/components/admin/notifications/notification-templates-card";
import { NotificationIntegrationsCard } from "@/components/admin/notifications/notification-integrations-card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import type {
  NotificationHistoryFilters,
  NotificationHistoryResponse,
} from "@/lib/api/admin-notifications";
import type { AdminUser } from "@/lib/api/admin";
import { searchAdminUsers } from "@/lib/api/admin";
import type { UseQueryResult } from "@tanstack/react-query";

const defaultFormValues: NotificationFormSchema = {
  title: "",
  message: "",
  type: "info",
  priority: "normal",
  targetUsers: ["students"],
  scheduledAt: undefined,
};

const typeOptions: Array<{
  value: NotificationFormSchema["type"];
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  description: string;
}> = [
  { value: "info", label: "Bilgi", icon: Info, description: "Genel bilgilendirme" },
  { value: "success", label: "Başarı", icon: CheckCircle2, description: "Olumlu durumlar" },
  { value: "warning", label: "Uyarı", icon: TriangleAlert, description: "Dikkat gerektiren" },
  { value: "error", label: "Hata", icon: Flame, description: "Acil müdahale" },
];

const targetOptions: Array<{
  value: SendNotificationPayload["target_users"][number];
  label: string;
}> = [
  { value: "all", label: "Tüm kullanıcılar" },
  { value: "students", label: "Öğrenciler" },
  { value: "teachers", label: "Öğretmenler" },
  { value: "admins", label: "Adminler" },
];

const channelLabels: Record<string, string> = {
  push: "Push",
  email: "E-posta",
  in_app: "In-App",
  sms: "SMS",
};

const targetTypeCopy: Record<string, string> = {
  all: "Tüm kullanıcılar",
  students: "Öğrenciler",
  teachers: "Öğretmenler",
  admins: "Adminler",
};

const priorityOptions: Array<{
  value: NonNullable<SendNotificationPayload["priority"]>;
  label: string;
}> = [
  { value: "low", label: "Düşük" },
  { value: "normal", label: "Normal" },
  { value: "high", label: "Yüksek" },
  { value: "urgent", label: "Acil" },
];

export default function NotificationsPage() {
  const [isBulk, setIsBulk] = useState(true);
  const [metadata, setMetadata] = useState<Record<string, unknown> | null>(null);
  const [historyFilters, setHistoryFilters] = useState<NotificationHistoryFilters>({
    page: 1,
    per_page: 10,
    search: "",
    type: "",
    status: undefined,
  });
  const [userQuery, setUserQuery] = useState("");
  const [userResults, setUserResults] = useState<AdminUser[]>([]);
  const [isSearchingUsers, setIsSearchingUsers] = useState(false);
  const [selectedUser, setSelectedUser] = useState<AdminUser | null>(null);

  const {
    data: summaryData,
    isLoading: summaryLoading,
    refetch: refetchSummary,
  } = useNotificationSummary();

  const {
    data: analyticsData,
    isLoading: analyticsLoading,
    refetch: refetchAnalytics,
  } = useNotificationAnalytics();

  const historyQuery = useNotificationHistory(historyFilters) as UseQueryResult<
    NotificationHistoryResponse,
    Error
  >;
  const {
    data: historyData,
    isLoading: historyLoading,
    refetch: refetchHistory,
    isFetching: isHistoryFetching,
  } = historyQuery;

  const {
    register,
    handleSubmit,
    setValue,
    reset,
    formState: { errors },
  } = useForm<NotificationFormSchema>({
    resolver: zodResolver(notificationSchema),
    defaultValues: defaultFormValues,
  });

  const [selectedTargets, setSelectedTargets] = useState(
    defaultFormValues.targetUsers,
  );
  const [selectedType, setSelectedType] = useState(defaultFormValues.type);
  const [selectedPriority, setSelectedPriority] = useState(
    defaultFormValues.priority ?? "normal",
  );

useEffect(() => {
  register("targetUsers");
}, [register]);

  const mutation = useMutationToast(sendBulkNotification, {
    successMessage: "Bildirim kuyruğa eklendi.",
    onSuccess: () => {
      reset(defaultFormValues);
      setSelectedTargets(defaultFormValues.targetUsers);
      setSelectedType(defaultFormValues.type);
      setSelectedPriority(defaultFormValues.priority ?? "normal");
      void Promise.all([refetchSummary(), refetchAnalytics()]);
    },
  });

  const {
    register: targetedRegister,
    handleSubmit: targetedHandleSubmit,
  setValue: setTargetedValue,
  watch: targetedWatch,
    reset: targetedReset,
    formState: { errors: targetedErrors },
  } = useForm<TargetedNotificationFormSchema>({
    resolver: zodResolver(targetedNotificationSchema),
  defaultValues: {
    userId: undefined,
    title: "",
    message: "",
    type: "info",
    priority: "normal",
  },
  });

  const targetedMutation = useMutationToast(sendUserNotification, {
    successMessage: "Hedefli bildirim gönderildi.",
    onSuccess: () => {
      targetedReset({
        userId: undefined,
        title: "",
        message: "",
        type: "info",
        priority: "normal",
      });
      setSelectedUser(null);
      setUserQuery("");
      setUserResults([]);
      void Promise.all([refetchSummary(), refetchAnalytics(), refetchHistory()]);
    },
  });

  const targetedPriority = targetedWatch("priority") ?? "normal";
  const targetedType = targetedWatch("type") ?? "info";
  const analytics = analyticsData?.analytics;

  useEffect(() => {
    if (userQuery.trim().length < 2) {
      setUserResults([]);
      return;
    }

    let active = true;
    setIsSearchingUsers(true);

    const handler = setTimeout(async () => {
      try {
        const results = await searchAdminUsers(userQuery.trim());
        if (active) {
          setUserResults(results);
        }
      } finally {
        if (active) {
          setIsSearchingUsers(false);
        }
      }
    }, 300);

    return () => {
      active = false;
      clearTimeout(handler);
    };
  }, [userQuery]);

  const summaryCards = useMemo(() => {
    if (!summaryData?.stats) {
      return null;
    }

    return [
      {
        label: "Toplam Bildirim",
        value: summaryData.stats.total.toLocaleString("tr-TR"),
        icon: Bell,
        subLabel: "Gönderilen toplam bildirim sayısı",
      },
      {
        label: "Okunmamış",
        value: summaryData.stats.unread.toLocaleString("tr-TR"),
        icon: Target,
        subLabel: "Kullanıcıların okumadığı bildirimler",
      },
      {
        label: "Bugün Gönderilen",
        value: summaryData.stats.today.toLocaleString("tr-TR"),
        icon: Users2,
        subLabel: "Son 24 saatte gönderilen bildirimler",
      },
      {
        label: "Okunma Oranı",
        value: `${summaryData.stats.read_rate}%`,
        icon: CheckCircle2,
        subLabel: "Genel okunma yüzdesi",
      },
    ];
  }, [summaryData]);

  const onSubmit = (values: NotificationFormSchema) => {
    const payload: SendNotificationPayload = {
      title: values.title,
      message: values.message,
      type: values.type,
      target_users: values.targetUsers,
      priority: values.priority ?? "normal",
      scheduled_at: values.scheduledAt,
    };

    mutation.mutate(payload);
  };

  const onSubmitTargeted = (values: TargetedNotificationFormSchema) => {
    if (!selectedUser) {
      return;
    }
    targetedMutation.mutate({
      user_id: selectedUser.id,
      title: values.title,
      message: values.message,
      type: values.type,
      priority: values.priority ?? "normal",
    });
  };

  const historyPagination = historyData?.pagination;

  return (
    <div className="space-y-6">
      <Dialog open={metadata !== null} onOpenChange={() => setMetadata(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Bildirim Metadata</DialogTitle>
            <DialogDescription>
              Gönderilen bildirimle ilgili ek bilgiler.
            </DialogDescription>
          </DialogHeader>
          <pre className="max-h-80 overflow-auto rounded-lg border border-slate-800/70 bg-slate-950/70 p-4 text-xs text-slate-300">
            {metadata ? JSON.stringify(metadata, null, 2) : ""}
          </pre>
        </DialogContent>
      </Dialog>

      <header className="flex flex-col gap-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h2 className="text-lg font-semibold text-slate-100">
            Bildirim Yönetimi
          </h2>
          <p className="text-sm text-slate-400">
            Platform kullanıcılarına toplu veya hedefli bildirimler gönderin,
            performansı takip edin.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant={isBulk ? "default" : "outline"}
            className="text-xs"
            onClick={() => setIsBulk(true)}
          >
            Toplu bildirim
          </Button>
          <Button
            variant={!isBulk ? "default" : "outline"}
            className="text-xs"
            onClick={() => {
              setIsBulk(false);
              targetedReset({
                userId: undefined,
                title: "",
                message: "",
                type: "info",
                priority: "normal",
              });
              setSelectedUser(null);
              setUserQuery("");
              setUserResults([]);
            }}
          >
            Hedefli bildirim
          </Button>
        </div>
      </header>

      <NotificationIntegrationsCard />
      <ScheduledNotificationsCard
        onViewLogs={(notification) => {
          setMetadata({
            notification,
            logs: notification.recent_logs ?? [],
          });
        }}
      />
      <NotificationTemplatesCard />

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {summaryLoading || !summaryCards ? (
          Array.from({ length: 4 }).map((_, index) => (
            <div
              key={index}
              className="rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5"
            >
              <Skeleton className="h-4 w-20" />
              <Skeleton className="mt-3 h-6 w-16" />
              <Skeleton className="mt-2 h-4 w-32" />
            </div>
          ))
        ) : (
          summaryCards.map((card) => (
            <div
              key={card.label}
              className="relative overflow-hidden rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5"
            >
              <div className="absolute right-0 top-0 h-full w-1/3 bg-sky-500/5" />
              <div className="relative z-10 space-y-3">
                <div className="flex items-center gap-2 text-slate-300">
                  <card.icon className="h-4 w-4 text-sky-300" />
                  <span className="text-xs font-medium uppercase tracking-wide">
                    {card.label}
                  </span>
                </div>
                <p className="text-2xl font-semibold text-slate-100">
                  {card.value}
                </p>
                <p className="text-xs text-slate-500">{card.subLabel}</p>
              </div>
            </div>
          ))
        )}
      </section>

      <section className="grid gap-4 xl:grid-cols-2">
        <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold text-slate-100">
              Tip & Öncelik Dağılımı
            </h3>
            <Button
              variant="ghost"
              className="text-xs text-slate-400 hover:text-slate-200"
              onClick={() => refetchAnalytics()}
              disabled={analyticsLoading}
            >
              Yenile
            </Button>
          </div>
          {analyticsLoading || !analytics ? (
            <div className="space-y-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          ) : (
            <div className="space-y-4">
              <div>
                <p className="text-xs uppercase tracking-wide text-slate-500">
                  Bildirim Tipi
                </p>
                <div className="mt-2 space-y-2">
                  {Object.entries(analytics.by_type).map(
                    ([type, count]) => (
                      <div
                        key={type}
                        className="flex items-center justify-between rounded-xl border border-slate-800/60 bg-slate-950/70 px-4 py-2 text-sm text-slate-200"
                      >
                        <span className="flex items-center gap-2">
                          <Badge variant={notificationTypeBadge[type] ?? "info"}>
                            {notificationTypeCopy[type] ?? type}
                          </Badge>
                        </span>
                        <span className="text-xs text-slate-400">{count}</span>
                      </div>
                    ),
                  )}
                </div>
              </div>
              <div>
                <p className="text-xs uppercase tracking-wide text-slate-500">
                  Öncelik Dağılımı
                </p>
                <div className="mt-2 space-y-2">
                  {Object.entries(analytics.by_priority).map(
                    ([priority, count]) => (
                      <div
                        key={priority}
                        className="flex items-center justify-between rounded-xl border border-slate-800/60 bg-slate-950/70 px-4 py-2 text-sm text-slate-200"
                      >
                        <span>{notificationPriorityCopy[priority] ?? priority}</span>
                        <span className="text-xs text-slate-400">{count}</span>
                      </div>
                    ),
                  )}
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5">
          <h3 className="text-sm font-semibold text-slate-100">
            Son 30 Günlük Trend
          </h3>
          {analyticsLoading || !analytics ? (
            <div className="space-y-2">
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
            </div>
          ) : (
            <div className="space-y-1 text-xs text-slate-300">
              {analytics.daily_trend.slice(-10).map((entry) => (
                <div
                  key={entry.date}
                  className="flex items-center justify-between rounded-lg border border-slate-800/60 bg-slate-950/70 px-4 py-2"
                >
                  <span>{format(new Date(entry.date), "d MMM yyyy", { locale: tr })}</span>
                  <span className="font-medium text-slate-100">
                    {entry.count}
                  </span>
                </div>
              ))}
              {analytics.daily_trend.length === 0 && (
                <p className="text-xs text-slate-500">
                  Son 30 günde gönderilmiş bildirim bulunmuyor.
                </p>
              )}
            </div>
          )}
        </div>
      </section>

      <section className="grid gap-4 xl:grid-cols-3">
        <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold text-slate-100">Gönderim performansı</h3>
            <Button
              variant="ghost"
              className="text-xs text-slate-400 hover:text-slate-200"
              onClick={() => refetchAnalytics()}
              disabled={analyticsLoading}
            >
              Yenile
            </Button>
          </div>
          {analyticsLoading || !analytics ? (
            <div className="space-y-2">
              <Skeleton className="h-9 w-full" />
              <Skeleton className="h-9 w-full" />
              <Skeleton className="h-9 w-full" />
            </div>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2">
              <StatPill label="Toplam iş" value={analytics.delivery.total_jobs.toLocaleString("tr-TR")} />
              <StatPill label="Başarılı iş" value={analytics.delivery.sent_jobs.toLocaleString("tr-TR")} />
              <StatPill
                label="Başarısız iş"
                value={analytics.delivery.failed_jobs.toLocaleString("tr-TR")}
                variant={analytics.delivery.failed_jobs > 0 ? "warning" : "default"}
              />
              <StatPill
                label="Başarı oranı"
                value={`${analytics.delivery.success_rate}%`}
                variant={analytics.delivery.success_rate < 95 ? "warning" : "default"}
              />
              <StatPill
                label="Gönderilen mesaj"
                value={analytics.delivery.messages_sent.toLocaleString("tr-TR")}
              />
              <StatPill
                label="Hatalı mesaj"
                value={analytics.delivery.messages_failed.toLocaleString("tr-TR")}
                variant={analytics.delivery.messages_failed > 0 ? "warning" : "default"}
              />
            </div>
          )}
        </div>

        <div className="space-y-3 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5">
          <h3 className="text-sm font-semibold text-slate-100">Kanal kullanımı</h3>
          {analyticsLoading || !analytics ? (
            <div className="space-y-2">
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
            </div>
          ) : Object.keys(analytics.channel_usage).length ? (
            <div className="space-y-2 text-xs text-slate-300">
              {Object.entries(analytics.channel_usage)
                .sort((a, b) => b[1] - a[1])
                .map(([channel, count]) => (
                  <div
                    key={channel}
                    className="flex items-center justify-between rounded-lg border border-slate-800/60 bg-slate-950/70 px-4 py-2"
                  >
                    <span>{channelLabels[channel] ?? channel}</span>
                    <span className="text-xs text-slate-400">{count}</span>
                  </div>
                ))}
            </div>
          ) : (
            <p className="text-xs text-slate-500">Henüz kanal kullanımı verisi bulunmuyor.</p>
          )}
        </div>

        <div className="space-y-3 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5">
          <h3 className="text-sm font-semibold text-slate-100">Hedef kitlesi</h3>
          {analyticsLoading || !analytics ? (
            <div className="space-y-2">
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
            </div>
          ) : Object.keys(analytics.target_breakdown).length ? (
            <div className="space-y-2 text-xs text-slate-300">
              {Object.entries(analytics.target_breakdown)
                .sort((a, b) => b[1] - a[1])
                .map(([target, count]) => (
                  <div
                    key={target}
                    className="flex items-center justify-between rounded-lg border border-slate-800/60 bg-slate-950/70 px-4 py-2"
                  >
                    <span>{targetTypeCopy[target] ?? target}</span>
                    <span className="text-xs text-slate-400">{count}</span>
                  </div>
                ))}
            </div>
          ) : (
            <p className="text-xs text-slate-500">Hedef kitlesi bilgisi henüz oluşmadı.</p>
          )}
        </div>
      </section>

      <section className="grid gap-4 xl:grid-cols-2">
        <div className="space-y-3 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5">
          <h3 className="text-sm font-semibold text-slate-100">En aktif göndericiler</h3>
          {analyticsLoading || !analytics ? (
            <div className="space-y-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          ) : analytics.top_senders.length ? (
            <div className="space-y-2 text-xs text-slate-300">
              {analytics.top_senders.map((sender) => (
                <div
                  key={sender.user_id ?? `system-${sender.count}`}
                  className="flex items-center justify-between rounded-lg border border-slate-800/60 bg-slate-950/70 px-4 py-2"
                >
                  <div>
                    <p className="font-medium text-slate-100">
                      {sender.name ?? "Sistem"}
                    </p>
                    <p className="text-[11px] text-slate-500">
                      {sender.email ?? "Otomatik bildirim"}
                    </p>
                  </div>
                  <span className="text-xs text-slate-400">
                    {sender.count.toLocaleString("tr-TR")}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-xs text-slate-500">
              Henüz gönderici bazlı bir istatistik bulunmuyor.
            </p>
          )}
        </div>

        <div className="space-y-3 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5">
          <h3 className="text-sm font-semibold text-slate-100">En çok kullanılan şablonlar</h3>
          {analyticsLoading || !analytics ? (
            <div className="space-y-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          ) : analytics.top_templates.length ? (
            <div className="space-y-2 text-xs text-slate-300">
              {analytics.top_templates.map((template) => (
                <div
                  key={template.template_id ?? `template-${template.count}`}
                  className="flex items-center justify-between rounded-lg border border-slate-800/60 bg-slate-950/70 px-4 py-2"
                >
                  <div>
                    <p className="font-medium text-slate-100">
                      {template.name ?? "İsimsiz şablon"}
                    </p>
                    {template.slug ? (
                      <p className="text-[11px] text-slate-500">/{template.slug}</p>
                    ) : null}
                  </div>
                  <span className="text-xs text-slate-400">
                    {template.count.toLocaleString("tr-TR")}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-xs text-slate-500">Şablon tabanlı bildirim kaydı bulunmuyor.</p>
          )}
        </div>
      </section>

      <section className="space-y-3 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5">
        <h3 className="text-sm font-semibold text-slate-100">Son hatalı gönderimler</h3>
        {analyticsLoading || !analytics ? (
          <div className="space-y-2">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        ) : analytics.recent_failures.length ? (
          <div className="space-y-2 text-xs text-slate-300">
            {analytics.recent_failures.map((failure) => (
              <div
                key={failure.id}
                className="rounded-lg border border-slate-800/60 bg-slate-950/70 px-4 py-3"
              >
                <div className="flex items-center justify-between gap-3">
                  <p className="font-medium text-slate-100">
                    {failure.title ?? `Bildirim #${failure.scheduled_notification_id}`}
                  </p>
                  <span className="text-[11px] text-slate-500">
                    {failure.finished_at
                      ? formatDistanceToNow(new Date(failure.finished_at), { addSuffix: true, locale: tr })
                      : "Devam ediyor"}
                  </span>
                </div>
                <p className="mt-1 text-[11px] text-amber-300">
                  {failure.error_message ?? "Hata mesajı bulunmuyor."}
                </p>
                <p className="mt-1 text-[11px] text-slate-500">
                  Başarısız gönderim: {failure.fail_count.toLocaleString("tr-TR")}
                </p>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-xs text-slate-500">
            Kaydedilmiş başarısız gönderim bulunmuyor. Tüm bildirimler sorunsuz görünüyor.
          </p>
        )}
      </section>

      <section className="rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
        <h3 className="text-base font-semibold text-slate-100">
          {isBulk ? "Toplu bildirim oluştur" : "Hedefli bildirim gönder"}
        </h3>
        <p className="mt-1 text-xs text-slate-500">
          {isBulk
            ? "Belirli kullanıcı gruplarına özel mesajlar, kampanyalar veya sistem duyuruları gönderebilirsiniz."
            : "Seçtiğiniz kullanıcıya özel bildirim gönderin."}
        </p>

        {isBulk ? (
          <form onSubmit={handleSubmit(onSubmit)} className="mt-6 space-y-6">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
                  Başlık
                </label>
                <Input
                  placeholder="Örnek: Yeni dönem kampanyası başladı!"
                  {...register("title")}
                />
                {errors.title && (
                  <p className="text-xs text-rose-400">{errors.title.message}</p>
                )}
              </div>
              <div className="space-y-2">
                <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
                  Planlanan Tarih (opsiyonel)
                </label>
                <Input type="datetime-local" {...register("scheduledAt")} />
              </div>
            </div>

            <MessageAndTypeSections
              register={register}
              errors={errors}
              selectedPriority={selectedPriority}
              setSelectedPriority={(priority) => {
                setSelectedPriority(priority);
                setValue("priority", priority, { shouldValidate: true });
              }}
              selectedType={selectedType}
              setSelectedType={(type) => {
                setSelectedType(type);
                setValue("type", type, { shouldValidate: true });
              }}
              selectedTargets={selectedTargets}
              setSelectedTargets={(targets) => {
                setSelectedTargets(targets);
                setValue("targetUsers", targets, { shouldValidate: true });
              }}
            />

            <div className="flex items-center justify-end gap-2">
              <Button
                type="button"
                variant="ghost"
                className="text-slate-400 hover:text-slate-200"
                onClick={() => {
                  reset(defaultFormValues);
                  setSelectedTargets(defaultFormValues.targetUsers);
                  setSelectedType(defaultFormValues.type);
                  setSelectedPriority(defaultFormValues.priority ?? "normal");
                }}
                disabled={mutation.isPending}
              >
                Formu temizle
              </Button>
              <Button type="submit" disabled={mutation.isPending}>
                {mutation.isPending ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Gönderiliyor...
                  </>
                ) : (
                  "Bildirim gönder"
                )}
              </Button>
            </div>
          </form>
        ) : (
          <form
            onSubmit={targetedHandleSubmit(onSubmitTargeted)}
            className="mt-6 space-y-6"
          >
            <div className="space-y-2">
              <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
                Kullanıcı ara
              </label>
              <div className="relative">
                <Input
                  placeholder="Ad, e-posta"
                  value={userQuery}
                  onChange={(event) => {
                    setUserQuery(event.target.value);
                    setSelectedUser(null);
                  }}
                />
                {selectedUser && (
                  <Badge className="absolute right-2 top-2 bg-sky-500/10 text-sky-200">
                    {selectedUser.name}
                  </Badge>
                )}
              </div>
              {isSearchingUsers && (
                <p className="text-xs text-slate-500">Kullanıcılar aranıyor...</p>
              )}
              {!isSearchingUsers && userQuery.trim().length >= 2 && (
                <div className="max-h-48 space-y-1 overflow-y-auto rounded-xl border border-slate-800/70 bg-slate-950/70 p-2 text-xs">
                  {userResults.length === 0 ? (
                    <p className="text-slate-500">Eşleşen kullanıcı bulunamadı.</p>
                  ) : (
                    userResults.map((user) => (
                      <button
                        key={user.id}
                        type="button"
                        className={cn(
                          "w-full rounded-lg px-3 py-2 text-left transition-colors hover:bg-slate-900/60",
                          selectedUser?.id === user.id && "bg-sky-500/10",
                        )}
                        onClick={() => {
                          setSelectedUser(user);
                          setUserResults([]);
                          setUserQuery(`${user.name} (${user.email})`);
                          setTargetedValue("userId", user.id, { shouldValidate: true });
                        }}
                      >
                        <span className="font-medium text-slate-100">{user.name}</span>
                        <span className="block text-[11px] text-slate-500">
                          {user.email}
                        </span>
                      </button>
                    ))
                  )}
                </div>
              )}
              {targetedErrors.userId && (
                <p className="text-xs text-rose-400">
                  {targetedErrors.userId.message}
                </p>
              )}
            </div>

            <input
              type="hidden"
              value={selectedUser?.id ?? ""}
              {...targetedRegister("userId", {
                valueAsNumber: true,
              })}
            />
            <input
              type="hidden"
              value={targetedPriority}
              {...targetedRegister("priority")}
            />
            <input
              type="hidden"
              value={targetedType}
              {...targetedRegister("type")}
            />

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
                  Başlık
                </label>
                <Input
                  placeholder="Örnek: Hesabınız hakkında"
                  {...targetedRegister("title")}
                />
                {targetedErrors.title && (
                  <p className="text-xs text-rose-400">
                    {targetedErrors.title.message}
                  </p>
                )}
              </div>
              <div className="space-y-2">
                <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
                  Öncelik
                </label>
                <div className="flex flex-wrap gap-2">
                  {priorityOptions.map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      className="rounded-lg border border-slate-800/70 bg-slate-950/70 px-3 py-1 text-xs text-slate-300 transition-colors hover:bg-slate-900/60 data-[active=true]:border-sky-500/40 data-[active=true]:bg-sky-500/10 data-[active=true]:text-sky-300"
                      data-active={targetedPriority === option.value}
                      onClick={() =>
                        setTargetedValue("priority", option.value, {
                          shouldValidate: true,
                        })
                      }
                    >
                      {option.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
                Mesaj İçeriği
              </label>
              <Textarea
                rows={6}
                placeholder="Kullanıcıya iletmek istediğiniz mesaj..."
                {...targetedRegister("message")}
              />
              {targetedErrors.message && (
                <p className="text-xs text-rose-400">
                  {targetedErrors.message.message}
                </p>
              )}
            </div>

            <div className="flex flex-wrap gap-2">
              {typeOptions.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  className="flex items-center gap-2 rounded-xl border border-slate-800/60 bg-slate-950/70 px-4 py-2 text-xs text-slate-300 transition-colors hover:border-sky-500/40 hover:bg-slate-950/80 data-[active=true]:border-sky-500/40 data-[active=true]:text-sky-200"
                  data-active={targetedType === option.value}
                  onClick={() =>
                    setTargetedValue("type", option.value, {
                      shouldValidate: true,
                    })
                  }
                >
                  <option.icon className="h-4 w-4" />
                  {option.label}
                </button>
              ))}
              {targetedErrors.type && (
                <p className="text-xs text-rose-400">
                  {targetedErrors.type.message}
                </p>
              )}
            </div>

            <div className="flex items-center justify-end gap-2">
              <Button
                type="button"
                variant="ghost"
                className="text-slate-400 hover:text-slate-200"
                onClick={() => {
                  targetedReset({
                    userId: undefined,
                    title: "",
                    message: "",
                    type: "info",
                    priority: "normal",
                  });
                  setSelectedUser(null);
                  setUserQuery("");
                  setUserResults([]);
                }}
                disabled={targetedMutation.isPending}
              >
                Formu temizle
              </Button>
              <Button
                type="submit"
                disabled={targetedMutation.isPending || !selectedUser}
              >
                {targetedMutation.isPending ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Gönderiliyor...
                  </>
                ) : (
                  "Bildirim gönder"
                )}
              </Button>
            </div>
          </form>
        )}
      </section>

      <section className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5">
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <h3 className="flex items-center gap-2 text-sm font-semibold text-slate-100">
              <History className="h-4 w-4" />
              Bildirim geçmişi
            </h3>
            <p className="text-xs text-slate-500">
              Gönderilen bildirimleri statü ve tipe göre filtreleyin.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Input
              placeholder="Başlık, mesaj veya kullanıcı ara"
              value={historyFilters.search ?? ""}
              onChange={(event) =>
                setHistoryFilters((prev) => ({
                  ...prev,
                  search: event.target.value,
                  page: 1,
                }))
              }
              className="w-56"
            />
            <div className="flex gap-2">
              <select
                className="rounded-lg border border-slate-800/70 bg-slate-950/70 px-3 py-2 text-xs text-slate-200"
                value={historyFilters.type ?? ""}
                onChange={(event) =>
                  setHistoryFilters((prev) => ({
                    ...prev,
                    type: event.target.value,
                    page: 1,
                  }))
                }
              >
                <option value="">Tip (Tümü)</option>
                <option value="info">Bilgi</option>
                <option value="success">Başarı</option>
                <option value="warning">Uyarı</option>
                <option value="error">Hata</option>
              </select>
              <select
                className="rounded-lg border border-slate-800/70 bg-slate-950/70 px-3 py-2 text-xs text-slate-200"
                value={historyFilters.status ?? ""}
                onChange={(event) => {
                  const nextStatus = event.target.value;
                  setHistoryFilters((prev) => ({
                    ...prev,
                    status:
                      nextStatus === ""
                        ? undefined
                        : (nextStatus as "read" | "unread"),
                    page: 1,
                  }));
                }}
              >
                <option value="">Durum (Tümü)</option>
                <option value="read">Okundu</option>
                <option value="unread">Okunmadı</option>
              </select>
              <Button
                variant="ghost"
                className="text-xs text-sky-300 hover:text-sky-200"
                onClick={() => refetchHistory()}
                disabled={isHistoryFetching}
              >
                <UserSearch className="mr-1 h-3 w-3" />
                Yenile
              </Button>
            </div>
          </div>
        </div>

        {historyLoading ? (
          <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
        ) : (
          <NotificationHistoryTable
            notifications={historyData?.notifications ?? []}
            onViewMetadata={setMetadata}
          />
        )}

        {historyPagination && (
          <div className="flex items-center justify-between text-xs text-slate-500">
            <span>
              Toplam {historyPagination.total} sonuç • Sayfa{" "}
              {historyPagination.current_page} / {historyPagination.last_page}
            </span>
            <div className="flex items-center gap-2">
              <Button
                variant="ghost"
                className="text-xs"
                onClick={() =>
                  setHistoryFilters((prev) => ({
                    ...prev,
                    page: Math.max(1, (prev.page ?? 1) - 1),
                  }))
                }
                disabled={(historyFilters.page ?? 1) <= 1 || isHistoryFetching}
              >
                Önceki
              </Button>
              <Button
                variant="ghost"
                className="text-xs"
                onClick={() =>
                  setHistoryFilters((prev) => ({
                    ...prev,
                    page: Math.min(
                      historyPagination.last_page,
                      (prev.page ?? 1) + 1,
                    ),
                  }))
                }
                disabled={
                  (historyFilters.page ?? 1) >= historyPagination.last_page ||
                  isHistoryFetching
                }
              >
                Sonraki
              </Button>
            </div>
          </div>
        )}
      </section>
    </div>
  );
}

const notificationTypeCopy: Record<string, string> = {
  info: "Bilgi",
  success: "Başarı",
  warning: "Uyarı",
  error: "Hata",
};

const notificationTypeBadge: Record<string, "info" | "success" | "warning" | "destructive"> = {
  info: "info",
  success: "success",
  warning: "warning",
  error: "destructive",
};

const notificationPriorityCopy: Record<string, string> = {
  low: "Düşük",
  normal: "Normal",
  high: "Yüksek",
  urgent: "Acil",
};

type StatPillProps = {
  label: string;
  value: string;
  variant?: "default" | "warning";
};

function StatPill({ label, value, variant = "default" }: StatPillProps) {
  return (
    <div
      className={cn(
        "rounded-lg border border-slate-800/60 bg-slate-950/70 px-4 py-3 text-xs text-slate-200",
        variant === "warning" && "border-amber-500/60 bg-amber-500/10 text-amber-200",
      )}
    >
      <p className="text-[11px] uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-1 text-sm font-semibold text-slate-100">{value}</p>
    </div>
  );
}

type MessageSectionProps = {
  register: ReturnType<typeof useForm<NotificationFormSchema>>["register"];
  errors: FieldErrors<NotificationFormSchema>;
  selectedType: NotificationFormSchema["type"];
  selectedPriority: NonNullable<NotificationFormSchema["priority"]>;
  selectedTargets: SendNotificationPayload["target_users"];
  setSelectedType: (type: NotificationFormSchema["type"]) => void;
  setSelectedPriority: (priority: NonNullable<SendNotificationPayload["priority"]>) => void;
  setSelectedTargets: (targets: SendNotificationPayload["target_users"]) => void;
};

function MessageAndTypeSections({
  register,
  errors,
  selectedType,
  selectedPriority,
  selectedTargets,
  setSelectedType,
  setSelectedPriority,
  setSelectedTargets,
}: MessageSectionProps) {
  return (
    <>
      <div className="space-y-2">
        <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
          Mesaj İçeriği
        </label>
        <Textarea
          rows={6}
          placeholder="Öğrencilerinize veya öğretmenlerinize iletmek istediğiniz mesajı yazın."
          {...register("message")}
        />
        {errors.message?.message && (
          <p className="text-xs text-rose-400">
            {errors.message.message}
          </p>
        )}
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
            Bildirim Tipi
          </label>
          <div className="grid gap-2">
            {typeOptions.map((option) => (
              <button
                key={option.value}
                type="button"
                className={cn(
                  "flex items-center justify-between rounded-xl border border-slate-800/60 bg-slate-950/70 px-4 py-3 text-sm text-slate-200 transition-colors hover:border-sky-500/40 hover:bg-slate-950/80",
                  selectedType === option.value &&
                    "border-sky-500/40 bg-sky-500/10 text-sky-200",
                )}
                onClick={() => setSelectedType(option.value)}
              >
                <span className="flex flex-col">
                  <span className="font-medium">{option.label}</span>
                  <span className="text-xs text-slate-500">
                    {option.description}
                  </span>
                </span>
                <option.icon className="h-4 w-4" />
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-4">
          <div>
            <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
              Hedef Kitle
            </label>
            <div className="mt-2 flex flex-wrap gap-2">
              {targetOptions.map((option) => {
                const selected = selectedTargets.includes(option.value);
                return (
                  <button
                    key={option.value}
                    type="button"
                    className="rounded-full border border-slate-800/70 bg-slate-950/70 px-3 py-1 text-xs text-slate-300 transition-colors hover:bg-slate-900/60 data-[active=true]:border-sky-500/40 data-[active=true]:bg-sky-500/10 data-[active=true]:text-sky-300"
                    data-active={selected}
                    onClick={() => {
                      let next = selectedTargets;
                      if (selected) {
                        next = selectedTargets.filter((v) => v !== option.value);
                      } else {
                        next =
                          option.value === "all"
                            ? ["all"]
                            : selectedTargets
                                .filter((v) => v !== "all")
                                .concat(option.value);
                      }
                      if (next.length === 0) {
                        next = ["students"];
                      }
                      setSelectedTargets(next);
                    }}
                  >
                    {option.label}
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
              Öncelik
            </label>
            <div className="mt-2 flex flex-wrap gap-2">
              {priorityOptions.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  className={cn(
                    "rounded-lg border border-slate-800/70 bg-slate-950/70 px-3 py-1 text-xs text-slate-300 transition-colors hover:bg-slate-900/60",
                    selectedPriority === option.value && "border-sky-500/40",
                  )}
                  onClick={() => setSelectedPriority(option.value)}
                >
                  {option.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

