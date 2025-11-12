import { useQuery } from "@tanstack/react-query";
import {
  fetchAdminReservations,
  type AdminReservationsFilters,
  type AdminReservationsResponse,
} from "@/lib/api/admin";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const reservationsQueryKey = ["admin", "reservations"];

export function useAdminReservations(filters: AdminReservationsFilters) {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<AdminReservationsResponse>({
    queryKey: [...reservationsQueryKey, filters],
    queryFn: () => fetchAdminReservations(filters),
    placeholderData: (previousData) => previousData,
    enabled: isEnabled,
  });
}

