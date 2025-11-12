import { useQuery } from "@tanstack/react-query";
import {
  fetchAdminUsers,
  type AdminUsersFilters,
  type AdminUsersResponse,
} from "@/lib/api/admin";
import { authStore } from "@/store/auth-store";

export const usersQueryKey = ["admin", "users"];

export function useAdminUsers(filters: AdminUsersFilters) {
  const accessToken = authStore((state) => state.accessToken);

  return useQuery<AdminUsersResponse>({
    queryKey: [...usersQueryKey, filters],
    queryFn: () => fetchAdminUsers(filters),
    keepPreviousData: true,
    enabled: Boolean(accessToken),
  });
}

