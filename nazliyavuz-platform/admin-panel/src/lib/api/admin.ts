import { apiClient } from "@/lib/api/client";

export type PaginationMeta = {
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
};

export type AdminUser = {
  id: number;
  name: string;
  email: string;
  role: "student" | "teacher" | "admin";
  status?: "active" | "suspended" | "pending";
  teacher_status?: "pending" | "approved" | "rejected";
  created_at: string;
  last_login_at?: string | null;
};

export type AdminUsersResponse = {
  success: boolean;
  users: AdminUser[];
  pagination: PaginationMeta;
};

export type AdminUsersFilters = {
  role?: string;
  status?: string;
  search?: string;
  page?: number;
  per_page?: number;
};

export async function fetchAdminUsers(
  filters: AdminUsersFilters = {},
): Promise<AdminUsersResponse> {
  const { data } = await apiClient.get<AdminUsersResponse>("/admin/users", {
    params: filters,
  });

  return data;
}

type UpdateUserStatusPayload = {
  userId: number;
  status: "active" | "suspended";
  reason?: string;
};

export async function updateUserStatus({
  userId,
  status,
  reason,
}: UpdateUserStatusPayload) {
  const { data } = await apiClient.put(`/admin/users/${userId}/status`, {
    status,
    reason,
  });
  return data;
}

type SuspendUserPayload = {
  userId: number;
  reason: string;
};

export async function suspendUser({ userId, reason }: SuspendUserPayload) {
  const { data } = await apiClient.post(`/admin/users/${userId}/suspend`, {
    reason,
  });
  return data;
}

export async function unsuspendUser(userId: number) {
  const { data } = await apiClient.post(`/admin/users/${userId}/unsuspend`);
  return data;
}

export type PendingTeacher = {
  id: number;
  name: string;
  email: string;
  created_at: string;
  teacher: {
    id: number;
    bio?: string | null;
    experience_years?: number | null;
    specialization?: string | null;
    certifications?: Array<{
      id: number;
      name: string;
      institution?: string | null;
      year?: number | null;
    }>;
  } | null;
};

export type PendingTeacherResponse = {
  success: boolean;
  pending_teachers: PendingTeacher[];
};

export async function fetchPendingTeachers(): Promise<PendingTeacherResponse> {
  const { data } = await apiClient.get<PendingTeacherResponse>(
    "/admin/teachers/pending",
  );

  return data;
}

type ApproveTeacherPayload = {
  userId: number;
  notes?: string;
};

export async function approveTeacher({
  userId,
  notes,
}: ApproveTeacherPayload) {
  const { data } = await apiClient.post(`/admin/teachers/${userId}/approve`, {
    notes,
  });
  return data;
}

type RejectTeacherPayload = {
  userId: number;
  reason: string;
};

export async function rejectTeacher({ userId, reason }: RejectTeacherPayload) {
  const { data } = await apiClient.post(`/admin/teachers/${userId}/reject`, {
    reason,
  });
  return data;
}

export type ReservationStatus =
  | "pending"
  | "accepted"
  | "in_progress"
  | "completed"
  | "cancelled";

export type AdminReservation = {
  id: number;
  title?: string | null;
  subject?: string | null;
  status: ReservationStatus;
  scheduled_at?: string | null;
  proposed_datetime?: string | null;
  created_at: string;
  duration_minutes?: number | null;
  price?: number | null;
  currency?: string | null;
  payment_status?:
    | "awaiting_payment"
    | "paid"
    | "refunded"
    | "failed"
    | null;
  notes?: string | null;
  teacher_notes?: string | null;
  admin_notes?: string | null;
  cancelled_reason?: string | null;
  cancelled_at?: string | null;
  refund_amount?: number | null;
  refund_reason?: string | null;
  refunded_at?: string | null;
  reminder_sent?: boolean | null;
  reminder_sent_at?: string | null;
  reminder_count?: number | null;
  lesson_summary?: LessonSummary | null;
  student?: {
    id: number;
    name: string;
    email: string;
  } | null;
  teacher?: {
    id: number;
    name: string;
    email: string;
  } | null;
  category?: {
    id: number;
    name: string;
  } | null;
  payments?: AdminPayment[];
  reschedule_request?: AdminRescheduleRequest | null;
  reschedule_history?: AdminRescheduleRequest[] | null;
  lessons?: AdminLesson[] | null;
  reminder_summary?: ReminderSummary | null;
  reminder_logs?: AdminReminderLog[] | null;
  refunds?: ReservationRefund[] | null;
};

export type AdminReservationsResponse = {
  success: boolean;
  reservations: AdminReservation[];
  pagination: PaginationMeta;
};

export type AdminReservationsFilters = {
  status?: string;
  date_from?: string;
  date_to?: string;
  teacher_id?: number;
  student_id?: number;
  search?: string;
  page?: number;
  per_page?: number;
};

export async function fetchAdminReservations(
  filters: AdminReservationsFilters = {},
): Promise<AdminReservationsResponse> {
  const { data } = await apiClient.get<AdminReservationsResponse>(
    "/admin/reservations",
    {
      params: filters,
    },
  );

  return data;
}

export async function searchAdminUsers(query: string): Promise<AdminUser[]> {
  const { data } = await apiClient.get<{ success: boolean; users: AdminUser[] }>(
    "/admin/users/search",
    {
      params: { q: query },
    },
  );

  return data.users ?? [];
}

export type UpdateReservationStatusPayload = {
  reservationId: number;
  status: ReservationStatus;
  notify_participants?: boolean;
  teacher_notes?: string | null;
  admin_notes?: string | null;
  notes?: string | null;
  cancellation_reason?: string | null;
};

export async function updateReservationStatus({
  reservationId,
  ...payload
}: UpdateReservationStatusPayload) {
  const { data } = await apiClient.put<{
    success: boolean;
    reservation: AdminReservation;
    message?: string;
  }>(`/admin/reservations/${reservationId}/status`, payload);

  return data;
}

export type AdminPayment = {
  id: number;
  amount: number;
  currency: string;
  status: string;
  paid_at?: string | null;
  payment_method?: string | null;
  transaction_id?: string | null;
  paytr_order_id?: string | null;
  payment_data?: Record<string, unknown> | null;
};

export type RescheduleRequestStatus = "pending" | "approved" | "rejected" | string;

export type AdminRescheduleRequest = {
  type?: string;
  requested_by?: number | string;
  requested_at?: string;
  old_datetime?: string;
  new_datetime?: string;
  reason?: string;
  status?: RescheduleRequestStatus;
  handled_by?: number | string;
  handled_by_role?: string;
  handled_at?: string;
  rejection_reason?: string;
};

export type AdminLesson = {
  id: number;
  status: string;
  status_text?: string | null;
  scheduled_at?: string | null;
  started_at?: string | null;
  ended_at?: string | null;
  duration_minutes?: number | null;
  formatted_duration?: string | null;
  notes?: string | null;
  feedback?: string | null;
  rating?: number | null;
  rated_at?: string | null;
  is_overdue: boolean;
  can_be_started: boolean;
  can_be_rated: boolean;
  created_at?: string | null;
  updated_at?: string | null;
  teacher?: {
    id: number;
    name: string;
    email: string;
  } | null;
  student?: {
    id: number;
    name: string;
    email: string;
  } | null;
};

export type LessonSummary = {
  total: number;
  completed: number;
  in_progress: number;
  upcoming: number;
  last_lesson_at?: string | null;
  next_lesson_at?: string | null;
};

export type ReminderChannelConfig = {
  enabled: boolean;
  template_id?: number | null;
};

export type ReminderAudienceChannels = {
  push: ReminderChannelConfig;
  email: ReminderChannelConfig;
  sms: ReminderChannelConfig;
};

export type ReminderWorkflowStep = {
  id: number;
  workflow_id: number;
  name: string;
  offset_minutes: number;
  offset_direction: "before" | "after";
  offset_human: string;
  send_window: number;
  step_order: number;
  enabled: boolean;
  stop_on_success: boolean;
  channels: {
    student: ReminderAudienceChannels;
    teacher: ReminderAudienceChannels;
  };
  metadata: Record<string, unknown>;
  created_at?: string | null;
  updated_at?: string | null;
};

export type ReminderWorkflow = {
  id: number;
  name: string;
  slug: string;
  description?: string | null;
  status: "draft" | "active" | "archived";
  target_statuses: ReservationStatus[];
  target_roles: Array<"student" | "teacher">;
  meta: Record<string, unknown>;
  steps: ReminderWorkflowStep[];
  created_at?: string | null;
  updated_at?: string | null;
};

export type ReminderPending = {
  id: number;
  workflow_id: number;
  workflow_name: string;
  name: string;
  offset_minutes: number;
  offset_direction: "before" | "after";
  scheduled_for?: string | null;
  channels: ReminderWorkflowStep["channels"];
};

export type ReminderSummary = {
  total_sent: number;
  last_sent_at?: string | null;
  last_channels?: string[];
  pending: ReminderPending[];
};

export type AdminReminderLog = {
  id: number;
  sent_at?: string | null;
  source: string;
  channels: string[];
  setting?: {
    id: number;
    name: string;
    offset_minutes: number;
  } | null;
};

export type AdminReminderSetting = ReminderWorkflowStep;

export type ReservationRefund = {
  id: number;
  amount: number;
  currency: string;
  status: "pending" | "processing" | "completed" | "failed" | "cancelled";
  reason?: string | null;
  notify_participants: boolean;
  cancel_reservation: boolean;
  attempts: number;
  max_attempts: number;
  last_attempt_at?: string | null;
  processed_at?: string | null;
  failure_code?: string | null;
  failure_message?: string | null;
  provider?: {
    name?: string | null;
    reference?: string | null;
    response?: Record<string, unknown> | null;
  };
  meta?: Record<string, unknown> | null;
  created_at?: string | null;
  updated_at?: string | null;
  payment?: {
    id: number;
    amount: number;
    status: string;
    paytr_order_id?: string | null;
  } | null;
  created_by?: {
    id: number;
    name: string;
    email: string;
  } | null;
};

export type RefundReservationPayload = {
  reservationId: number;
  refund_amount?: number;
  reason?: string;
  notify_participants?: boolean;
  cancel_reservation?: boolean;
};

export type RefundReservationResponse = {
  success: boolean;
  reservation: AdminReservation;
  refund: ReservationRefund;
  status?: string;
  message?: string;
  paytr?: Record<string, unknown> | null;
};

export async function refundReservation({
  reservationId,
  ...payload
}: RefundReservationPayload): Promise<RefundReservationResponse> {
  const { data } = await apiClient.post<RefundReservationResponse>(
    `/admin/reservations/${reservationId}/refund`,
    payload,
  );

  return data;
}

export type HandleReschedulePayload = {
  reservationId: number;
  action: "approve" | "reject" | "clear";
  rejection_reason?: string;
  notify_participants?: boolean;
};

export async function handleAdminReschedule({
  reservationId,
  ...payload
}: HandleReschedulePayload) {
  const { data } = await apiClient.post<{
    success: boolean;
    reservation: AdminReservation;
  }>(`/admin/reservations/${reservationId}/reschedule`, payload);

  return data;
}

export type BulkReservationUndoItem = {
  reservation_id: number;
  previous_status: ReservationStatus;
  previous_cancelled_reason?: string | null;
  previous_cancelled_at?: string | null;
  previous_cancelled_by_id?: number | null;
  previous_admin_notes?: string | null;
};

type BulkStatusResponse = {
  success: boolean;
  message?: string;
  updated_count?: number;
  reservations: AdminReservation[];
  undo?: BulkReservationUndoItem[];
};

export type BulkStatusUpdatePayload = {
  reservation_ids: number[];
  status: ReservationStatus;
  notify_participants?: boolean;
  admin_notes?: string;
  cancellation_reason?: string;
};

export async function bulkUpdateReservationStatus(
  payload: BulkStatusUpdatePayload,
): Promise<BulkStatusResponse> {
  const { data } = await apiClient.post<BulkStatusResponse>(
    "/admin/reservations/bulk/status",
    payload,
  );
  return data;
}

export type BulkCancelPayload = {
  reservation_ids: number[];
  reason?: string;
  notify_participants?: boolean;
  admin_notes?: string;
};

export async function bulkCancelReservations(
  payload: BulkCancelPayload,
): Promise<BulkStatusResponse> {
  const { data } = await apiClient.post<BulkStatusResponse>(
    "/admin/reservations/bulk/cancel",
    payload,
  );
  return data;
}

export type BulkReminderPayload = {
  reservation_ids: number[];
  notify_student?: boolean;
  notify_teacher?: boolean;
  send_email?: boolean;
};

export type BulkReminderResponse = {
  success: boolean;
  message?: string;
  processed_count: number;
  reservations: AdminReservation[];
};

export async function bulkSendReservationReminders(
  payload: BulkReminderPayload,
): Promise<BulkReminderResponse> {
  const { data } = await apiClient.post<BulkReminderResponse>(
    "/admin/reservations/bulk/reminders",
    payload,
  );
  return data;
}

export type BulkUndoPayload = {
  items: BulkReservationUndoItem[];
};

export type BulkUndoResponse = {
  success: boolean;
  message?: string;
  restored_count: number;
  reservations: AdminReservation[];
  missing?: number[];
};

export async function bulkUndoReservationActions(
  payload: BulkUndoPayload,
): Promise<BulkUndoResponse> {
  const { data } = await apiClient.post<BulkUndoResponse>(
    "/admin/reservations/bulk/undo",
    payload,
  );
  return data;
}

type ReminderSettingsResponse = {
  success: boolean;
  workflows: ReminderWorkflow[];
  settings: AdminReminderSetting[];
};

export async function fetchReservationReminderSettings(): Promise<ReminderSettingsResponse> {
  const { data } = await apiClient.get<ReminderSettingsResponse>(
    "/admin/reservations/reminder-settings",
  );
  return data;
}

export type ReminderWorkflowPayload = {
  name: string;
  description?: string | null;
  status?: "draft" | "active" | "archived";
  target_statuses?: ReservationStatus[];
  target_roles?: Array<"student" | "teacher">;
  meta?: Record<string, unknown>;
};

export type ReminderWorkflowStepChannelsPayload = {
  student?: Partial<Record<"push" | "email" | "sms", { enabled?: boolean; template_id?: number | null }>>;
  teacher?: Partial<Record<"push" | "email" | "sms", { enabled?: boolean; template_id?: number | null }>>;
};

export type ReminderWorkflowStepPayload = {
  name: string;
  offset_minutes: number;
  offset_direction?: "before" | "after";
  send_window?: number;
  step_order?: number;
  enabled?: boolean;
  stop_on_success?: boolean;
  channels?: ReminderWorkflowStepChannelsPayload;
  metadata?: Record<string, unknown>;
};

export type ReminderWorkflowReorderPayload = {
  order: number[];
};

export type ReminderSettingPayload = {
  name: string;
  offset_minutes: number;
  enabled?: boolean;
  notify_student?: boolean;
  notify_teacher?: boolean;
  send_email?: boolean;
};

export async function createReservationReminderSetting(
  payload: ReminderSettingPayload,
): Promise<{ success: boolean; setting: AdminReminderSetting }> {
  const { data } = await apiClient.post<{ success: boolean; setting: AdminReminderSetting }>(
    "/admin/reservations/reminder-settings",
    payload,
  );
  return data;
}

export async function updateReservationReminderSetting(
  settingId: number,
  payload: Partial<ReminderSettingPayload>,
): Promise<{ success: boolean; setting: AdminReminderSetting }> {
  const { data } = await apiClient.put<{ success: boolean; setting: AdminReminderSetting }>(
    `/admin/reservations/reminder-settings/${settingId}`,
    payload,
  );
  return data;
}

export async function deleteReservationReminderSetting(settingId: number): Promise<{
  success: boolean;
  message?: string;
}> {
  const { data } = await apiClient.delete<{ success: boolean; message?: string }>(
    `/admin/reservations/reminder-settings/${settingId}`,
  );
  return data;
}

export async function fetchReservationReminderWorkflows(): Promise<{
  success: boolean;
  workflows: ReminderWorkflow[];
}> {
  const { data } = await apiClient.get<{ success: boolean; workflows: ReminderWorkflow[] }>(
    "/admin/reservations/reminder-workflows",
  );
  return data;
}

export async function createReminderWorkflow(
  payload: ReminderWorkflowPayload,
): Promise<{ success: boolean; workflow: ReminderWorkflow }> {
  const { data } = await apiClient.post<{ success: boolean; workflow: ReminderWorkflow }>(
    "/admin/reservations/reminder-workflows",
    payload,
  );
  return data;
}

export async function updateReminderWorkflow(
  workflowId: number,
  payload: Partial<ReminderWorkflowPayload>,
): Promise<{ success: boolean; workflow: ReminderWorkflow }> {
  const { data } = await apiClient.put<{ success: boolean; workflow: ReminderWorkflow }>(
    `/admin/reservations/reminder-workflows/${workflowId}`,
    payload,
  );
  return data;
}

export async function deleteReminderWorkflow(workflowId: number): Promise<{
  success: boolean;
  message?: string;
}> {
  const { data } = await apiClient.delete<{ success: boolean; message?: string }>(
    `/admin/reservations/reminder-workflows/${workflowId}`,
  );
  return data;
}

export async function createReminderWorkflowStep(
  workflowId: number,
  payload: ReminderWorkflowStepPayload,
): Promise<{ success: boolean; step: ReminderWorkflowStep }> {
  const { data } = await apiClient.post<{ success: boolean; step: ReminderWorkflowStep }>(
    `/admin/reservations/reminder-workflows/${workflowId}/steps`,
    payload,
  );
  return data;
}

export async function updateReminderWorkflowStep(
  workflowId: number,
  stepId: number,
  payload: Partial<ReminderWorkflowStepPayload>,
): Promise<{ success: boolean; step: ReminderWorkflowStep }> {
  const { data } = await apiClient.put<{ success: boolean; step: ReminderWorkflowStep }>(
    `/admin/reservations/reminder-workflows/${workflowId}/steps/${stepId}`,
    payload,
  );
  return data;
}

export async function deleteReminderWorkflowStep(
  workflowId: number,
  stepId: number,
): Promise<{ success: boolean; message?: string }> {
  const { data } = await apiClient.delete<{ success: boolean; message?: string }>(
    `/admin/reservations/reminder-workflows/${workflowId}/steps/${stepId}`,
  );
  return data;
}

export async function reorderReminderWorkflowSteps(
  workflowId: number,
  payload: ReminderWorkflowReorderPayload,
): Promise<{ success: boolean; workflow: ReminderWorkflow }> {
  const { data } = await apiClient.post<{ success: boolean; workflow: ReminderWorkflow }>(
    `/admin/reservations/reminder-workflows/${workflowId}/steps/reorder`,
    payload,
  );
  return data;
}

export type AdminCalendarFilters = {
  start_date?: string;
  end_date?: string;
  status?: string;
  teacher_id?: number;
  student_id?: number;
  category_id?: number;
};

export type AdminCalendarReservation = {
  id: number;
  title?: string | null;
  subject?: string | null;
  status: ReservationStatus;
  start?: string | null;
  end?: string | null;
  proposed_datetime?: string | null;
  duration_minutes?: number | null;
  price?: number | null;
  currency?: string | null;
  payment_status?: string | null;
  notes?: string | null;
  teacher_notes?: string | null;
  admin_notes?: string | null;
  category?: {
    id: number;
    name: string;
  } | null;
  category_id?: number | null;
  teacher?: {
    id: number;
    name: string;
    email: string;
  } | null;
  teacher_id?: number | null;
  student?: {
    id: number;
    name: string;
    email: string;
  } | null;
  student_id?: number | null;
  is_reschedule_pending: boolean;
  reschedule_request?: AdminRescheduleRequest | null;
};

export type AdminCalendarResponse = {
  success: boolean;
  start_date: string;
  end_date: string;
  count: number;
  reservations: AdminCalendarReservation[];
};

export async function fetchReservationCalendar(
  filters: AdminCalendarFilters = {},
): Promise<AdminCalendarResponse> {
  const { data } = await apiClient.get<AdminCalendarResponse>(
    "/admin/reservations/calendar",
    {
      params: filters,
    },
  );

  return data;
}

export type UpdateReservationSchedulePayload = {
  reservationId: number;
  proposed_datetime: string;
  duration_minutes?: number | null;
  teacher_id?: number | null;
  category_id?: number | null;
  notify_participants?: boolean;
};

export async function updateReservationSchedule({
  reservationId,
  ...payload
}: UpdateReservationSchedulePayload) {
  const { data } = await apiClient.put<{
    success: boolean;
    reservation: AdminReservation;
  }>(`/admin/reservations/${reservationId}/schedule`, payload);

  return data;
}

