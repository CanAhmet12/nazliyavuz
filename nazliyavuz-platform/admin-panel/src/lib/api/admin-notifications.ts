import { apiClient } from "@/lib/api/client";
import type { PaginationMeta } from "@/lib/api/admin";

export type NotificationSummary = {
  total: number;
  unread: number;
  today: number;
  this_week: number;
  read_rate: number;
};

export type NotificationSummaryResponse = {
  success: boolean;
  stats: NotificationSummary;
};

export type NotificationAnalytics = {
  by_type: Record<string, number>;
  by_priority: Record<string, number>;
  daily_trend: Array<{
    date: string;
    count: number;
  }>;
  delivery: {
    total_jobs: number;
    sent_jobs: number;
    failed_jobs: number;
    processing_jobs: number;
    success_rate: number;
    messages_sent: number;
    messages_failed: number;
  };
  channel_usage: Record<string, number>;
  target_breakdown: Record<string, number>;
  top_senders: Array<{
    user_id: number | null;
    name?: string | null;
    email?: string | null;
    count: number;
  }>;
  top_templates: Array<{
    template_id: number | null;
    name?: string | null;
    slug?: string | null;
    count: number;
  }>;
  recent_failures: Array<{
    id: number;
    scheduled_notification_id: number;
    title?: string | null;
    error_message?: string | null;
    fail_count: number;
    finished_at?: string | null;
  }>;
};

export type NotificationAnalyticsResponse = {
  success: boolean;
  analytics: NotificationAnalytics;
};

export type ScheduledNotificationLog = {
  id: number;
  status: string;
  sent_count: number;
  fail_count: number;
  started_at?: string | null;
  finished_at?: string | null;
  error_message?: string | null;
};

export type ScheduledNotification = {
  id: number;
  title: string;
  message: string;
  type: string;
  priority: "low" | "normal" | "high" | "urgent";
  target_type: "all" | "students" | "teachers" | "admins";
  target_filters?: Record<string, unknown> | null;
  channels: {
    push: boolean;
    email: boolean;
    in_app: boolean;
  };
  template_id?: number | null;
  template?: NotificationTemplate | null;
  status: "draft" | "scheduled" | "queued" | "sending" | "sent" | "failed" | "cancelled";
  scheduled_at?: string | null;
  timezone?: string | null;
  sent_count: number;
  fail_count: number;
  last_attempt_at?: string | null;
  meta?: Record<string, unknown> | null;
  created_by?: {
    id: number;
    name: string;
    email: string;
  } | null;
  created_at?: string | null;
  updated_at?: string | null;
  recent_logs?: ScheduledNotificationLog[];
};

export type ScheduledNotificationsResponse = {
  success: boolean;
  notifications: ScheduledNotification[];
};

export async function fetchNotificationSummary(): Promise<NotificationSummaryResponse> {
  const { data } = await apiClient.get<NotificationSummaryResponse>(
    "/admin/notifications/stats",
  );

  return data;
}

export async function fetchNotificationAnalytics(): Promise<NotificationAnalyticsResponse> {
  const { data } = await apiClient.get<NotificationAnalyticsResponse>(
    "/admin/notifications/analytics",
  );

  return data;
}

export type SendNotificationPayload = {
  title: string;
  message: string;
  type: "info" | "warning" | "success" | "error";
  target_users: Array<"all" | "students" | "teachers" | "admins">;
  priority?: "low" | "normal" | "high" | "urgent";
  scheduled_at?: string | null;
};

export async function sendNotification(payload: SendNotificationPayload) {
  const { data } = await apiClient.post("/admin/notifications/send", payload);
  return data;
}

export async function sendBulkNotification(payload: SendNotificationPayload) {
  const { data } = await apiClient.post("/admin/notifications/bulk", payload);
  return data;
}

export type NotificationHistoryItem = {
  id: number;
  title: string;
  message: string;
  type: string;
  is_read: boolean;
  created_at: string;
  user?: {
    id: number;
    name: string;
    email: string;
  } | null;
  data?: Record<string, unknown> | null;
};

export type NotificationHistoryResponse = {
  success: boolean;
  notifications: NotificationHistoryItem[];
  pagination: PaginationMeta;
};

export type NotificationHistoryFilters = {
  search?: string;
  type?: string;
  status?: "read" | "unread";
  page?: number;
  per_page?: number;
};

export async function fetchNotificationHistory(
  filters: NotificationHistoryFilters = {},
): Promise<NotificationHistoryResponse> {
  const { data } = await apiClient.get<NotificationHistoryResponse>(
    "/admin/notifications",
    {
      params: filters,
    },
  );

  return data;
}

export type SendUserNotificationPayload = {
  user_id: number;
  title: string;
  message: string;
  type: "info" | "warning" | "success" | "error";
  priority?: "low" | "normal" | "high" | "urgent";
};

export async function sendUserNotification(payload: SendUserNotificationPayload) {
  const { data } = await apiClient.post("/admin/notifications/user", payload);
  return data;
}

export type ScheduledNotificationPayload = {
  title?: string | null;
  message?: string | null;
  type: "info" | "warning" | "success" | "error";
  priority?: "low" | "normal" | "high" | "urgent";
  target_type?: "all" | "students" | "teachers" | "admins";
  channels?: {
    push?: boolean;
    email?: boolean;
    in_app?: boolean;
  };
  scheduled_at?: string | null;
  timezone?: string | null;
  status?: "draft" | "scheduled";
  template_id?: number | null;
  meta?: Record<string, unknown> | null;
};

export async function fetchScheduledNotifications(): Promise<ScheduledNotificationsResponse> {
  const { data } = await apiClient.get<ScheduledNotificationsResponse>(
    "/admin/notifications/scheduled",
  );
  return data;
}

export async function createScheduledNotification(payload: ScheduledNotificationPayload) {
  const { data } = await apiClient.post<{
    success: boolean;
    notification: ScheduledNotification;
  }>("/admin/notifications/scheduled", payload);

  return data;
}

export async function updateScheduledNotification(
  id: number,
  payload: Partial<ScheduledNotificationPayload>,
) {
  const { data } = await apiClient.put<{
    success: boolean;
    notification: ScheduledNotification;
  }>(`/admin/notifications/scheduled/${id}`, payload);

  return data;
}

export async function scheduleScheduledNotification(
  id: number,
  payload: { scheduled_at: string; timezone?: string | null },
) {
  const { data } = await apiClient.post<{
    success: boolean;
    notification: ScheduledNotification;
  }>(`/admin/notifications/scheduled/${id}/schedule`, payload);

  return data;
}

export async function sendScheduledNotificationNow(id: number) {
  const { data } = await apiClient.post<{
    success: boolean;
    notification: ScheduledNotification;
  }>(`/admin/notifications/scheduled/${id}/send-now`);

  return data;
}

export async function cancelScheduledNotification(id: number) {
  const { data } = await apiClient.post<{
    success: boolean;
    notification: ScheduledNotification;
  }>(`/admin/notifications/scheduled/${id}/cancel`);

  return data;
}

export async function fetchScheduledNotificationLogs(id: number) {
  const { data } = await apiClient.get<{
    success: boolean;
    logs: ScheduledNotificationLog[];
  }>(`/admin/notifications/scheduled/${id}/logs`);

  return data;
}

export type NotificationTemplate = {
  id: number;
  name: string;
  slug: string;
  channel: "email" | "push" | "sms" | "in_app";
  subject?: string | null;
  body: string;
  variables?: string[] | null;
  action_url?: string | null;
  action_text?: string | null;
  is_default: boolean;
  status: "draft" | "published" | "archived";
  created_by?: {
    id: number;
    name: string;
    email: string;
  } | null;
  updated_by?: {
    id: number;
    name: string;
    email: string;
  } | null;
  created_at?: string | null;
  updated_at?: string | null;
};

export type NotificationTemplatesResponse = {
  success: boolean;
  templates: NotificationTemplate[];
};

export type NotificationTemplatePayload = {
  name: string;
  slug?: string;
  channel: "email" | "push" | "sms" | "in_app";
  subject?: string | null;
  body: string;
  variables?: string[];
  action_url?: string | null;
  action_text?: string | null;
  is_default?: boolean;
  status?: "draft" | "published" | "archived";
};

export async function fetchNotificationTemplates(): Promise<NotificationTemplatesResponse> {
  const { data } = await apiClient.get<NotificationTemplatesResponse>("/admin/notification-templates");
  return data;
}

export async function createNotificationTemplate(payload: NotificationTemplatePayload) {
  const { data } = await apiClient.post<{
    success: boolean;
    template: NotificationTemplate;
  }>("/admin/notification-templates", payload);
  return data;
}

export async function updateNotificationTemplate(
  id: number,
  payload: Partial<NotificationTemplatePayload>,
) {
  const { data } = await apiClient.put<{
    success: boolean;
    template: NotificationTemplate;
  }>(`/admin/notification-templates/${id}`, payload);
  return data;
}

export async function publishNotificationTemplate(id: number) {
  const { data } = await apiClient.post<{
    success: boolean;
    template: NotificationTemplate;
  }>(`/admin/notification-templates/${id}/publish`);
  return data;
}

export async function archiveNotificationTemplate(id: number) {
  const { data } = await apiClient.post<{
    success: boolean;
    template: NotificationTemplate;
  }>(`/admin/notification-templates/${id}/archive`);
  return data;
}

export async function duplicateNotificationTemplate(id: number) {
  const { data } = await apiClient.post<{
    success: boolean;
    template: NotificationTemplate;
  }>(`/admin/notification-templates/${id}/duplicate`);
  return data;
}

export type NotificationTemplateDetailResponse = {
  success: boolean;
  template: NotificationTemplate;
};

export async function getNotificationTemplate(id: number): Promise<NotificationTemplateDetailResponse> {
  const { data } = await apiClient.get<NotificationTemplateDetailResponse>(`/admin/notification-templates/${id}`);
  return data;
}

export type NotificationTemplateVariablesResponse = {
  success: boolean;
  groups: Record<string, string[]>;
};

export async function fetchNotificationTemplateVariables(): Promise<NotificationTemplateVariablesResponse> {
  const { data } = await apiClient.get<NotificationTemplateVariablesResponse>("/admin/notification-templates/variables");
  return data;
}

export type NotificationTemplatePreviewResponse = {
  success: boolean;
  preview: {
    channel: NotificationTemplate["channel"];
    subject: string;
    body: string;
  };
  message?: string;
  channel_response?: Record<string, unknown> | null;
};

export async function renderNotificationTemplate(
  id: number,
  payload: { placeholders?: Record<string, string> | null },
): Promise<NotificationTemplatePreviewResponse> {
  const { data } = await apiClient.post<NotificationTemplatePreviewResponse>(
    `/admin/notification-templates/${id}/render`,
    payload,
  );
  return data;
}

export async function testSendNotificationTemplate(
  id: number,
  payload: {
    channel: NotificationTemplate["channel"];
    recipient?: string;
    user_id?: number;
    placeholders?: Record<string, string>;
  },
): Promise<NotificationTemplatePreviewResponse> {
  const { data } = await apiClient.post<NotificationTemplatePreviewResponse>(
    `/admin/notification-templates/${id}/test-send`,
    payload,
  );
  return data;
}

export type NotificationIntegrationStatus = {
  success: boolean;
  email: {
    configured: boolean;
    details: {
      driver: string | null;
      host: string | null;
      port: string | null;
      username: string | null;
      encryption: string | null;
      from_address: string | null;
      from_name: string | null;
      password_set: boolean;
    };
    missing: string[];
  };
  push: {
    configured: boolean;
    details: {
      server_key_set: boolean;
      sender_id: string | null;
    };
    missing: string[];
  };
  sms: {
    configured: boolean;
    provider: string;
    details: {
      twilio_account_sid: string | null;
      twilio_auth_token_set: boolean;
      twilio_from: string | null;
    };
    missing: string[];
  };
  supported_sms_providers: string[];
};

export type NotificationIntegrationUpdatePayload = {
  email?: {
    driver?: string | null;
    host?: string | null;
    port?: string | null;
    username?: string | null;
    password?: string | null;
    encryption?: string | null;
    from_address?: string | null;
    from_name?: string | null;
  };
  push?: {
    server_key?: string | null;
    sender_id?: string | null;
  };
  sms?: {
    provider?: "twilio" | "mock" | null;
    twilio_account_sid?: string | null;
    twilio_auth_token?: string | null;
    twilio_from?: string | null;
  };
};

export async function fetchNotificationIntegrationStatus(): Promise<NotificationIntegrationStatus> {
  const { data } = await apiClient.get<NotificationIntegrationStatus>("/admin/notification-integrations");
  return data;
}

export async function updateNotificationIntegrations(
  payload: NotificationIntegrationUpdatePayload,
): Promise<NotificationIntegrationStatus> {
  const { data } = await apiClient.put<NotificationIntegrationStatus>("/admin/notification-integrations", payload);
  return data;
}

