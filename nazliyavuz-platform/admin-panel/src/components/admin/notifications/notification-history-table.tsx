import { Badge } from "@/components/ui/badge";
import type { NotificationHistoryItem } from "@/lib/api/admin-notifications";
import { formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";

type NotificationHistoryTableProps = {
  notifications: NotificationHistoryItem[];
  onViewMetadata: (metadata: Record<string, unknown>) => void;
};

export function NotificationHistoryTable({
  notifications,
  onViewMetadata,
}: NotificationHistoryTableProps) {
  if (!notifications.length) {
    return (
      <div className="rounded-2xl border border-slate-800/70 bg-slate-950/60 p-6 text-sm text-slate-400">
        Henüz gönderilmiş bildirim bulunmuyor.
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-800/70 bg-slate-950/60">
      <table className="w-full border-collapse text-sm text-slate-200">
        <thead className="bg-slate-950/80 text-xs uppercase tracking-wide text-slate-400">
          <tr>
            <th className="px-4 py-3 text-left font-medium">Başlık</th>
            <th className="px-4 py-3 text-left font-medium">Tip</th>
            <th className="px-4 py-3 text-left font-medium">Hedef Kullanıcı</th>
            <th className="px-4 py-3 text-left font-medium">Durum</th>
            <th className="px-4 py-3 text-left font-medium">Gönderim</th>
            <th className="px-4 py-3 text-left font-medium">Detay</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-800/70">
          {notifications.map((notification) => (
            <tr key={notification.id} className="hover:bg-slate-900/40">
              <td className="px-4 py-4">
                <div className="flex flex-col gap-1">
                  <span className="font-medium text-slate-100">
                    {notification.title}
                  </span>
                  <span className="text-xs text-slate-500 truncate">
                    {notification.message}
                  </span>
                </div>
              </td>
              <td className="px-4 py-4">
                <Badge variant={typeVariant[notification.type] ?? "info"}>
                  {typeCopy[notification.type] ?? notification.type}
                </Badge>
              </td>
              <td className="px-4 py-4 text-xs text-slate-300">
                {notification.user
                  ? `${notification.user.name} • ${notification.user.email}`
                  : "Toplu gönderim"}
              </td>
              <td className="px-4 py-4">
                <Badge variant={notification.is_read ? "default" : "info"}>
                  {notification.is_read ? "Okundu" : "Okunmadı"}
                </Badge>
              </td>
              <td className="px-4 py-4 text-xs text-slate-400">
                {formatDistanceToNow(new Date(notification.created_at), {
                  addSuffix: true,
                  locale: tr,
                })}
              </td>
              <td className="px-4 py-4 text-xs text-slate-500">
                {notification.data ? (
                  <button
                    type="button"
                    className="text-sky-300 hover:text-sky-200"
                    onClick={() =>
                      onViewMetadata(notification.data ?? {})
                    }
                  >
                    İncele
                  </button>
                ) : (
                  "-"
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

const typeVariant: Record<string, "info" | "success" | "warning" | "destructive"> =
  {
    info: "info",
    success: "success",
    warning: "warning",
    error: "destructive",
  };

const typeCopy: Record<string, string> = {
  info: "Bilgi",
  success: "Başarı",
  warning: "Uyarı",
  error: "Hata",
};

