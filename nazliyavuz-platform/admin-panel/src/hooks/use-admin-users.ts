import { useQuery } from "@tanstack/react-query";
import {
  fetchAdminUsers,
  type AdminUsersFilters,
  type AdminUsersResponse,
} from "@/lib/api/admin";

export const usersQueryKey = ["admin", "users"];

export function useAdminUsers(filters: AdminUsersFilters) {
  return useQuery<AdminUsersResponse>({
    queryKey: [...usersQueryKey, filters],
    queryFn: () => fetchAdminUsers(filters),
    keepPreviousData: true,
  });
}

