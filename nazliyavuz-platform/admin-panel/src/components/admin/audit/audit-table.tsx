import { Badge } from "@/components/ui/badge";
import type { AuditLog } from "@/lib/api/audit";
import { formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";

type AuditTableProps = {
  logs: AuditLog[];
  onShowDetails?: (log: AuditLog) => void;
};

export function AuditTable({ logs, onShowDetails }: AuditTableProps) {
  if (!logs.length) {
    return (
      <div className="rounded-2xl border border-slate-800/70 bg-slate-950/60 p-6 text-sm text-slate-400">
        Henüz audit kaydı bulunmuyor.
      </div>
    );
  }

  return (
    <>
      {/* Mobile Card View */}
      <div className="space-y-3 md:hidden">
        {logs.map((log) => (
          <div
            key={log.id}
            onClick={() => onShowDetails?.(log)}
            className="cursor-pointer rounded-xl border border-slate-800/70 bg-slate-950/60 p-4 transition-all active:scale-[0.98]"
          >
            <div className="space-y-2">
              <div className="flex items-start justify-between gap-2">
                <Badge variant="info" className="text-xs capitalize">
                  {log.action.replace(/_/g, " ")}
                </Badge>
                <SeverityBadge severity={log.severity} />
              </div>
              <div className="space-y-1.5 text-xs">
                {log.user ? (
                  <div>
                    <span className="text-slate-500">Kullanıcı: </span>
                    <span className="text-slate-300">{log.user.name}</span>
                    <span className="ml-1 text-slate-500">({log.user.email})</span>
                  </div>
                ) : (
                  <div className="text-slate-500">Sistem</div>
                )}
                <div>
                  <span className="text-slate-500">Zaman: </span>
                  <span className="text-slate-300">
                    {formatDistanceToNow(new Date(log.created_at), {
                      addSuffix: true,
                      locale: tr,
                    })}
                  </span>
                </div>
                {log.target_type && (
                  <div>
                    <span className="text-slate-500">Hedef: </span>
                    <span className="text-slate-300">
                      {formatTarget(log.target_type, log.target_id) ?? "-"}
                    </span>
                  </div>
                )}
                {log.description && (
                  <div className="line-clamp-2">
                    <span className="text-slate-500">Açıklama: </span>
                    <span className="text-slate-300">{log.description}</span>
                  </div>
                )}
              </div>
              <button
                type="button"
                className="mt-2 text-xs font-medium text-sky-300 hover:text-sky-200"
                onClick={(e) => {
                  e.stopPropagation();
                  onShowDetails?.(log);
                }}
              >
                Detayı Görüntüle →
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Desktop Table View */}
      <div className="hidden overflow-hidden rounded-xl border border-slate-800/70 bg-slate-950/60 md:block md:rounded-2xl">
        <table className="w-full border-collapse text-sm text-slate-200">
        <thead className="bg-slate-950/80 text-xs uppercase tracking-wide text-slate-400">
          <tr>
            <th className="px-4 py-3 text-left font-medium">Zaman</th>
            <th className="px-4 py-3 text-left font-medium">Kullanıcı</th>
            <th className="px-4 py-3 text-left font-medium">Aksiyon</th>
            <th className="px-4 py-3 text-left font-medium">Şiddet</th>
            <th className="px-4 py-3 text-left font-medium">Hedef</th>
            <th className="px-4 py-3 text-left font-medium">Açıklama</th>
            <th className="px-4 py-3 text-left font-medium">Detay</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-800/70">
          {logs.map((log) => (
            <tr key={log.id} className="hover:bg-slate-900/40">
              <td className="px-4 py-4 text-xs text-slate-400">
                {formatDistanceToNow(new Date(log.created_at), {
                  addSuffix: true,
                  locale: tr,
                })}
              </td>
              <td className="px-4 py-4">
                {log.user ? (
                  <div className="flex flex-col">
                    <span className="font-medium text-slate-100">{log.user.name}</span>
                    <span className="text-xs text-slate-500">{log.user.email}</span>
                  </div>
                ) : (
                  <span className="text-xs text-slate-500">Sistem</span>
                )}
              </td>
              <td className="px-4 py-4">
                <Badge variant="info" className="capitalize">
                  {log.action.replace(/_/g, " ")}
                </Badge>
              </td>
              <td className="px-4 py-4">
                <SeverityBadge severity={log.severity} />
              </td>
              <td className="px-4 py-4 text-xs text-slate-300">
                {formatTarget(log.target_type, log.target_id) ?? "-"}
              </td>
              <td className="px-4 py-4 text-xs text-slate-300">
                {log.description ?? "-"}
              </td>
              <td className="px-4 py-4 text-xs">
                <button
                  type="button"
                  className="font-medium text-sky-300 hover:text-sky-200"
                  onClick={() => onShowDetails?.(log)}
                >
                  Detayı Görüntüle
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      </div>
    </>
  );
}

function SeverityBadge({ severity }: { severity?: string | null }) {
  const normalized = severity?.toLowerCase() ?? "info";
  const mapping: Record<string, { label: string; variant: "info" | "warning" | "destructive" | "success" | "default" }> = {
    info: { label: "Bilgi", variant: "info" },
    warning: { label: "Uyarı", variant: "warning" },
    error: { label: "Hata", variant: "destructive" },
    critical: { label: "Kritik", variant: "destructive" },
    success: { label: "Başarılı", variant: "success" },
  };

  const { label, variant } = mapping[normalized] ?? { label: severity ?? "Bilinmiyor", variant: "default" };

  return <Badge variant={variant}>{label}</Badge>;
}

function formatTarget(targetType?: string | null, targetId?: number | null): string | null {
  if (!targetType && !targetId) {
    return null;
  }

  const typeLabel = targetType ? targetType.split("\\").pop()?.split("/").pop() ?? targetType : "Hedef";
  if (targetId == null) {
    return typeLabel;
  }

  return `${typeLabel} #${targetId}`;
}

