import { useQuery } from "@tanstack/react-query";
import {
  fetchReservationReminderSettings,
  type AdminReminderSetting,
  type ReminderWorkflow,
} from "@/lib/api/admin";

type ReminderSettingsQueryResult = {
  success: boolean;
  settings: AdminReminderSetting[];
  workflows: ReminderWorkflow[];
};

export const reminderSettingsQueryKey = ["admin", "reservations", "reminder-settings"];

export function useAdminReservationReminderSettings() {
  return useQuery<ReminderSettingsQueryResult>({
    queryKey: reminderSettingsQueryKey,
    queryFn: fetchReservationReminderSettings,
    staleTime: 60_000,
  });
}

