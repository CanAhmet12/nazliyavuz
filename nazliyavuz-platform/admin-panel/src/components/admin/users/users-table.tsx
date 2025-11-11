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
    <div className="overflow-hidden rounded-xl border border-slate-800/60 bg-slate-950/70">
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

