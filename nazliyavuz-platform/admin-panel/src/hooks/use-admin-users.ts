import { useQuery } from "@tanstack/react-query";
import {
  fetchAdminUsers,
  type AdminUsersFilters,
  type AdminUsersResponse,
} from "@/lib/api/admin";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const usersQueryKey = ["admin", "users"];

export function useAdminUsers(filters: AdminUsersFilters) {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<AdminUsersResponse>({
    queryKey: [...usersQueryKey, filters],
    queryFn: () => fetchAdminUsers(filters),
    keepPreviousData: true,
    enabled: isEnabled,
  });
}

