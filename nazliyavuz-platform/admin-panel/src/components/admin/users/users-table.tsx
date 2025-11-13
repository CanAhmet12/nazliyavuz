import { Badge } from "@/components/ui/badge";
import type { AdminUser } from "@/lib/api/admin";
import { format } from "date-fns";
import { tr } from "date-fns/locale";
import { cn } from "@/lib/utils";

type UsersTableProps = {
  users: AdminUser[];
  onSelect?: (user: AdminUser) => void;
  selectedUserId?: number | null;
};

export function UsersTable({ users, onSelect, selectedUserId }: UsersTableProps) {
  if (!users.length) {
    return (
      <div className="flex h-48 flex-col items-center justify-center rounded-xl border border-slate-800/60 bg-slate-950/60 text-center">
        <p className="text-sm font-medium text-slate-200">
          Henüz kullanıcı bulunmuyor
        </p>
        <p className="mt-1 text-xs text-slate-500">
          Filtreleri değiştirerek farklı sonuçlar deneyebilirsiniz.
        </p>
      </div>
    );
  }

  return (
    <>
      {/* Mobile Card View */}
      <div className="space-y-3 md:hidden">
        {users.map((user) => (
          <div
            key={user.id}
            onClick={() => onSelect?.(user)}
            className={cn(
              "cursor-pointer rounded-xl border border-slate-800/60 bg-slate-950/70 p-4 transition-all active:scale-[0.98]",
              selectedUserId === user.id && "border-sky-500/40 bg-sky-500/10",
            )}
          >
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <h3 className="truncate text-sm font-semibold text-slate-100">
                    {user.name}
                  </h3>
                  <Badge variant={roleVariant[user.role]} className="shrink-0 text-xs">
                    {roleCopy[user.role] ?? user.role}
                  </Badge>
                </div>
                <p className="mt-1 truncate text-xs text-slate-400">{user.email}</p>
                <div className="mt-2 flex flex-wrap items-center gap-2">
                  <Badge variant={statusVariant[user.status ?? "active"]} className="text-xs">
                    {statusCopy[user.status ?? "active"]}
                  </Badge>
                  {user.role === "teacher" && user.teacher_status && (
                    <Badge
                      variant={teacherStatusVariant[user.teacher_status]}
                      className="text-xs uppercase"
                    >
                      {teacherStatusCopy[user.teacher_status]}
                    </Badge>
                  )}
                </div>
              </div>
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 border-t border-slate-800/60 pt-3 text-xs text-slate-500">
              <div>
                <span className="text-slate-400">Son Giriş:</span>{" "}
                {user.last_login_at
                  ? formatDate(user.last_login_at, "d MMM yyyy")
                  : "Henüz giriş yapmadı"}
              </div>
              <div>
                <span className="text-slate-400">Kayıt:</span>{" "}
                {formatDate(user.created_at, "d MMM yyyy")}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Desktop Table View */}
      <div className="hidden overflow-hidden rounded-xl border border-slate-800/60 bg-slate-950/70 md:block">
        <table className="w-full table-fixed border-collapse text-sm text-slate-200">
          <thead className="bg-slate-950/80 text-xs uppercase tracking-wide text-slate-400">
            <tr>
              <th className="px-4 py-3 text-left font-medium">Kullanıcı</th>
              <th className="px-4 py-3 text-left font-medium">Rol</th>
              <th className="px-4 py-3 text-left font-medium">Durum</th>
              <th className="px-4 py-3 text-left font-medium">Son Giriş</th>
              <th className="px-4 py-3 text-left font-medium">Kayıt Tarihi</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800/70">
            {users.map((user) => (
              <tr
                key={user.id}
                className={cn(
                  "cursor-pointer transition-colors hover:bg-slate-900/50",
                  selectedUserId === user.id && "bg-sky-500/10",
                )}
                onClick={() => onSelect?.(user)}
              >
                <td className="px-4 py-4">
                  <div className="flex flex-col">
                    <span className="font-medium text-slate-100">
                      {user.name}
                    </span>
                    <span className="text-xs text-slate-400">{user.email}</span>
                  </div>
                </td>
                <td className="px-4 py-4">
                  <Badge variant={roleVariant[user.role]}>
                    {roleCopy[user.role] ?? user.role}
                  </Badge>
                </td>
                <td className="px-4 py-4">
                  <div className="flex items-center gap-2">
                    <Badge variant={statusVariant[user.status ?? "active"]}>
                      {statusCopy[user.status ?? "active"]}
                    </Badge>
                    {user.role === "teacher" && user.teacher_status && (
                      <Badge
                        variant={teacherStatusVariant[user.teacher_status]}
                        className="uppercase"
                      >
                        {teacherStatusCopy[user.teacher_status]}
                      </Badge>
                    )}
                  </div>
                </td>
                <td className="px-4 py-4">
                  <span className={cn("text-xs text-slate-400")}>
                    {user.last_login_at
                      ? formatDate(user.last_login_at)
                      : "Henüz giriş yapmadı"}
                  </span>
                </td>
                <td className="px-4 py-4 text-xs text-slate-400">
                  {formatDate(user.created_at, "d MMM yyyy")}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

const roleVariant: Record<AdminUser["role"], "info" | "default" | "success"> = {
  admin: "info",
  teacher: "success",
  student: "default",
};

const roleCopy: Record<AdminUser["role"], string> = {
  admin: "Yönetici",
  teacher: "Öğretmen",
  student: "Öğrenci",
};

const statusVariant: Record<string, "success" | "warning" | "destructive"> = {
  active: "success",
  suspended: "destructive",
  pending: "warning",
};

const statusCopy: Record<string, string> = {
  active: "Aktif",
  suspended: "Askıda",
  pending: "Beklemede",
};

const teacherStatusVariant: Record<
  NonNullable<AdminUser["teacher_status"]>,
  "info" | "success" | "destructive"
> = {
  pending: "info",
  approved: "success",
  rejected: "destructive",
};

const teacherStatusCopy: Record<
  NonNullable<AdminUser["teacher_status"]>,
  string
> = {
  pending: "Onay bekliyor",
  approved: "Onaylandı",
  rejected: "Reddedildi",
};

function formatDate(date: string, template = "d MMM yyyy HH:mm") {
  try {
    return format(new Date(date), template, { locale: tr });
  } catch {
    return "-";
  }
}

