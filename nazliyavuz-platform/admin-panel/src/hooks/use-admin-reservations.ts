import { useQuery } from "@tanstack/react-query";
import {
  fetchAdminReservations,
  type AdminReservationsFilters,
  type AdminReservationsResponse,
} from "@/lib/api/admin";

export const reservationsQueryKey = ["admin", "reservations"];

export function useAdminReservations(filters: AdminReservationsFilters) {
  return useQuery<AdminReservationsResponse>({
    queryKey: [...reservationsQueryKey, filters],
    queryFn: () => fetchAdminReservations(filters),
    keepPreviousData: true,
  });
}

