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
    <div className="overflow-hidden rounded-2xl border border-slate-800/70 bg-slate-950/60">
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

