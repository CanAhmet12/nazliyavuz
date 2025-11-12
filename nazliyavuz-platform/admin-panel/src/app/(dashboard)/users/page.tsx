"use client";

import { useState } from "react";
import { Search, UsersRound } from "lucide-react";
import { useAdminUsers, usersQueryKey } from "@/hooks/use-admin-users";
import { UsersTable } from "@/components/admin/users/users-table";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import type {
  AdminUser,
  AdminUsersFilters,
  AdminUsersResponse,
} from "@/lib/api/admin";
import type { UseQueryResult } from "@tanstack/react-query";
import { UserDetailDrawer } from "@/components/admin/users/user-detail-drawer";
import { useMutationToast } from "@/hooks/use-mutation-toast";
import { suspendUser, unsuspendUser } from "@/lib/api/admin";
import { useQueryClient } from "@tanstack/react-query";

const DEFAULT_FILTERS: AdminUsersFilters = {
  role: "",
  status: "",
  search: "",
  page: 1,
  per_page: 10,
};

export default function UsersPage() {
  const [filters, setFilters] = useState<AdminUsersFilters>({
    ...DEFAULT_FILTERS,
  });
  const [selectedUser, setSelectedUser] = useState<AdminUser | null>(null);
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const queryClient = useQueryClient();
  const usersQuery = useAdminUsers(filters) as UseQueryResult<
    AdminUsersResponse,
    Error
  >;
  const { data, isLoading, isFetching, refetch } = usersQuery;

  const users = data?.users ?? [];
  const pagination = data?.pagination;

  const suspendMutation = useMutationToast(suspendUser, {
    successMessage: "Kullanıcı askıya alındı.",
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: usersQueryKey });
    },
  });

  const unsuspendMutation = useMutationToast(
    ({ userId }: { userId: number }) => unsuspendUser(userId),
    {
      successMessage: "Kullanıcı askıdan kaldırıldı.",
      onSuccess: async () => {
        await queryClient.invalidateQueries({ queryKey: usersQueryKey });
      },
    },
  );

  const handleSuspend = async (reason: string) => {
    if (!selectedUser) return;
    await suspendMutation.mutateAsync({
      userId: selectedUser.id,
      reason,
    });
    setSelectedUser({ ...selectedUser, status: "suspended" });
  };

  const handleUnsuspend = async () => {
    if (!selectedUser) return;
    await unsuspendMutation.mutateAsync({ userId: selectedUser.id });
    setSelectedUser({ ...selectedUser, status: "active" });
  };

  const handleRowSelect = (user: AdminUser) => {
    setSelectedUser(user);
    setIsDrawerOpen(true);
  };

  const isProcessing = suspendMutation.isPending || unsuspendMutation.isPending;

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h2 className="text-lg font-semibold text-slate-100">
            Kullanıcı Yönetimi
          </h2>
          <p className="text-sm text-slate-400">
            Öğrenci, öğretmen ve admin hesaplarını tek yerden yönetin.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant="info" className="gap-2">
            <UsersRound className="h-4 w-4" />
            {pagination?.total ?? 0} kullanıcı
          </Badge>
          <Button
            variant="outline"
            className="border-slate-800 bg-slate-950 text-slate-300 hover:bg-slate-900/80"
            onClick={() => refetch()}
            disabled={isFetching}
          >
            Yenile
          </Button>
        </div>
      </div>

      <div className="grid gap-4 rounded-2xl border border-slate-800/60 bg-slate-950/60 p-5 md:grid-cols-3">
        <div className="md:col-span-2">
          <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
            Arama
          </label>
          <div className="mt-2 flex items-center gap-2 rounded-xl border border-slate-800/60 bg-slate-950/80 px-3">
            <Search className="h-4 w-4 text-slate-600" />
            <Input
              className="border-none bg-transparent px-0 text-sm focus-visible:ring-0"
              placeholder="İsim, e-posta veya rol ara..."
              value={filters.search}
              onChange={(event) =>
                setFilters((prev) => ({
                  ...prev,
                  search: event.target.value,
                  page: 1,
                }))
              }
            />
          </div>
        </div>

        <div className="space-y-2">
          <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
            Rol
          </label>
          <div className="flex flex-wrap gap-2">
            {roleFilters.map((role) => (
              <FilterChip
                key={role.value}
                active={filters.role === role.value}
                onClick={() =>
                  setFilters((prev) => ({
                    ...prev,
                    role: prev.role === role.value ? "" : role.value,
                    page: 1,
                  }))
                }
              >
                {role.label}
              </FilterChip>
            ))}
          </div>
        </div>

        <div className="space-y-2 md:col-span-3">
          <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
            Durum
          </label>
          <div className="flex flex-wrap gap-2">
            {statusFilters.map((status) => (
              <FilterChip
                key={status.value}
                active={filters.status === status.value}
                onClick={() =>
                  setFilters((prev) => ({
                    ...prev,
                    status: prev.status === status.value ? "" : status.value,
                    page: 1,
                  }))
                }
              >
                {status.label}
              </FilterChip>
            ))}
            {(filters.role || filters.status || filters.search) && (
              <Button
                variant="ghost"
                className="text-xs text-slate-400 hover:text-slate-200"
                onClick={() => setFilters({ ...DEFAULT_FILTERS })}
              >
                Filtreleri temizle
              </Button>
            )}
          </div>
        </div>
      </div>

      <div className="space-y-4">
        {isLoading ? (
          <UsersTableSkeleton />
        ) : (
          <UsersTable
            users={users}
            onSelect={handleRowSelect}
            selectedUserId={selectedUser?.id ?? null}
          />
        )}

        {pagination && (
          <div className="flex items-center justify-between text-xs text-slate-500">
            <span>
              Toplam {pagination.total} sonuç • Sayfa {pagination.current_page} /{" "}
              {pagination.last_page}
            </span>
            <div className="flex items-center gap-2">
              <Button
                variant="ghost"
                className="text-xs"
                onClick={() =>
                  setFilters((prev) => ({
                    ...prev,
                    page: Math.max(1, (prev.page ?? 1) - 1),
                  }))
                }
                disabled={(filters.page ?? 1) <= 1 || isFetching}
              >
                Önceki
              </Button>
              <Button
                variant="ghost"
                className="text-xs"
                onClick={() =>
                  setFilters((prev) => ({
                    ...prev,
                    page: Math.min(
                      pagination.last_page,
                      (prev.page ?? 1) + 1,
                    ),
                  }))
                }
                disabled={
                  (filters.page ?? 1) >= pagination.last_page || isFetching
                }
              >
                Sonraki
              </Button>
            </div>
          </div>
        )}
      </div>

      <UserDetailDrawer
        user={selectedUser}
        open={isDrawerOpen}
        onClose={() => setIsDrawerOpen(false)}
        onSuspend={handleSuspend}
        onUnsuspend={handleUnsuspend}
        isProcessing={isProcessing}
      />
    </div>
  );
}

type FilterChipProps = {
  children: React.ReactNode;
  active: boolean;
  onClick: () => void;
};

function FilterChip({ children, active, onClick }: FilterChipProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="rounded-full border border-slate-800/70 bg-slate-950/70 px-3 py-1 text-xs text-slate-300 transition-colors hover:bg-slate-900/60 data-[active=true]:border-sky-500/40 data-[active=true]:bg-sky-500/10 data-[active=true]:text-sky-300"
      data-active={active}
    >
      {children}
    </button>
  );
}

function UsersTableSkeleton() {
  return (
    <div className="space-y-4">
      <Skeleton className="h-4 w-24" />
      <div className="overflow-hidden rounded-xl border border-slate-800/60 bg-slate-950/70">
        <table className="w-full table-fixed border-collapse">
          <thead className="bg-slate-950/80">
            <tr>
              {Array.from({ length: 5 }).map((_, index) => (
                <th key={index} className="px-4 py-3 text-left text-xs">
                  <Skeleton className="h-3 w-16 bg-slate-800/60" />
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800/70">
            {Array.from({ length: 5 }).map((_, index) => (
              <tr key={index}>
                {Array.from({ length: 5 }).map((__, cellIndex) => (
                  <td key={cellIndex} className="px-4 py-4">
                    <Skeleton className="h-4 w-24 bg-slate-800/60" />
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

const roleFilters = [
  { label: "Tümü", value: "" },
  { label: "Öğrenciler", value: "student" },
  { label: "Öğretmenler", value: "teacher" },
  { label: "Adminler", value: "admin" },
];

const statusFilters = [
  { label: "Aktif", value: "active" },
  { label: "Askıda", value: "suspended" },
  { label: "Beklemede", value: "pending" },
];

