import { formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import type { BackupItem } from "@/lib/api/backups";

type BackupsTableProps = {
  backups: BackupItem[];
  onRestore: (backup: BackupItem) => void;
  onDelete: (backup: BackupItem) => void;
  isProcessing?: boolean;
};

export function BackupsTable({
  backups,
  onRestore,
  onDelete,
  isProcessing,
}: BackupsTableProps) {
  if (!backups.length) {
    return (
      <div className="rounded-2xl border border-slate-800/70 bg-slate-950/60 p-6 text-sm text-slate-400">
        Henüz yedek oluşturulmadı. Yukarıdaki butonları kullanarak yeni yedek
        alabilirsiniz.
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-800/70 bg-slate-950/60">
      <table className="w-full border-collapse text-sm text-slate-200">
        <thead className="bg-slate-950/80 text-xs uppercase tracking-wide text-slate-400">
          <tr>
            <th className="px-4 py-3 text-left font-medium">Dosya</th>
            <th className="px-4 py-3 text-left font-medium">Boyut</th>
            <th className="px-4 py-3 text-left font-medium">Tip</th>
            <th className="px-4 py-3 text-left font-medium">Oluşturulma</th>
            <th className="px-4 py-3 text-right font-medium">İşlemler</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-800/70">
          {backups.map((backup) => (
            <tr key={backup.filename} className="hover:bg-slate-900/50">
              <td className="px-4 py-4">
                <div className="flex flex-col">
                  <span className="font-medium text-slate-100">
                    {backup.filename}
                  </span>
                  <span className="text-xs text-slate-500">
                    {backup.filepath ?? ""}
                  </span>
                </div>
              </td>
              <td className="px-4 py-4 text-xs text-slate-400">
                {formatSize(backup.size)}
              </td>
              <td className="px-4 py-4">
                <Badge variant={badgeVariant[backup.type] ?? "default"}>
                  {typeLabels[backup.type] ?? backup.type}
                </Badge>
              </td>
              <td className="px-4 py-4 text-xs text-slate-400">
                {formatDistanceToNow(new Date(backup.created_at), {
                  addSuffix: true,
                  locale: tr,
                })}
              </td>
              <td className="px-4 py-4 text-right">
                <div className="flex justify-end gap-2">
                  <Button
                    variant="ghost"
                    className="text-xs text-sky-300 hover:bg-sky-500/10"
                    onClick={() => onRestore(backup)}
                    disabled={isProcessing}
                  >
                    Geri Yükle
                  </Button>
                  <Button
                    variant="ghost"
                    className="text-xs text-rose-400 hover:bg-rose-500/10"
                    onClick={() => onDelete(backup)}
                    disabled={isProcessing}
                  >
                    Sil
                  </Button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

const typeLabels: Record<string, string> = {
  database: "Veritabanı",
  filesystem: "Dosya Sistemi",
  full: "Tam Yedek",
};

const badgeVariant: Record<string, "info" | "success" | "warning"> = {
  database: "info",
  filesystem: "warning",
  full: "success",
};

function formatSize(bytes: number) {
  if (bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
}

