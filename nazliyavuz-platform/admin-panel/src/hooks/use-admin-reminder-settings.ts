import { useQuery } from "@tanstack/react-query";
import {
  fetchReservationReminderSettings,
  type AdminReminderSetting,
  type ReminderWorkflow,
} from "@/lib/api/admin";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

type ReminderSettingsQueryResult = {
  success: boolean;
  settings: AdminReminderSetting[];
  workflows: ReminderWorkflow[];
};

export const reminderSettingsQueryKey = ["admin", "reservations", "reminder-settings"];

export function useAdminReservationReminderSettings() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<ReminderSettingsQueryResult>({
    queryKey: reminderSettingsQueryKey,
    queryFn: fetchReservationReminderSettings,
    staleTime: 60_000,
    enabled: isEnabled,
  });
}

