import { useQuery } from "@tanstack/react-query";
import {
  fetchReservationCalendar,
  type AdminCalendarFilters,
  type AdminCalendarResponse,
} from "@/lib/api/admin";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const reservationCalendarKey = ["admin", "reservations", "calendar"];

export function useAdminReservationCalendar(filters: AdminCalendarFilters) {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<AdminCalendarResponse>({
    queryKey: [...reservationCalendarKey, filters],
    queryFn: () => fetchReservationCalendar(filters),
    keepPreviousData: true,
    enabled: isEnabled,
  });
}

