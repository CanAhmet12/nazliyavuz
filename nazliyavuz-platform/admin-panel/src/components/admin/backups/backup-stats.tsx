import { HardDrive, Clock, Database, Server } from "lucide-react";

type BackupStatsProps = {
  totalBackups: number;
  totalSizeFormatted: string;
  newestBackup: string | null;
  oldestBackup: string | null;
  backupsByType: Record<string, number>;
};

export function BackupStats({
  totalBackups,
  totalSizeFormatted,
  newestBackup,
  oldestBackup,
  backupsByType,
}: BackupStatsProps) {
  const stats = [
    {
      label: "Toplam Yedek",
      value: totalBackups.toString(),
      icon: <Database className="h-4 w-4" />,
      helper: "Saklanan tüm yedek sayısı",
    },
    {
      label: "Depolama Alanı",
      value: totalSizeFormatted,
      icon: <HardDrive className="h-4 w-4" />,
      helper: "Yedeklerin toplam boyutu",
    },
    {
      label: "En Yeni Yedek",
      value: newestBackup ? formatDate(newestBackup) : "Henüz yok",
      icon: <Clock className="h-4 w-4" />,
      helper: "Son yedekleme zamanı",
    },
    {
      label: "En Eski Yedek",
      value: oldestBackup ? formatDate(oldestBackup) : "Henüz yok",
      icon: <Clock className="h-4 w-4" />,
      helper: "Temizlenmeden önceki en eski yedek",
    },
    {
      label: "Yedek Tipleri",
      value: Object.entries(backupsByType)
        .map(([type, count]) => `${type}: ${count}`)
        .join(" • "),
      icon: <Server className="h-4 w-4" />,
      helper: "Database / dosya sistemi / tam yedek",
    },
  ];

  return (
    <div className="grid gap-4 md:grid-cols-2">
      {stats.map((item) => (
        <div
          key={item.label}
          className="flex h-full flex-col justify-between rounded-2xl border border-slate-800/70 bg-slate-950/60 p-5"
        >
          <div className="flex items-center justify-between">
            <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-sky-500/10 text-sky-300">
              {item.icon}
            </span>
            <p className="text-xs uppercase tracking-wide text-slate-500">
              {item.label}
            </p>
          </div>
          <p className="mt-4 text-xl font-semibold text-slate-100">
            {item.value || "-"}
          </p>
          <p className="mt-2 text-xs text-slate-500">{item.helper}</p>
        </div>
      ))}
    </div>
  );
}

function formatDate(value: string) {
  const date = new Date(value);
  return date.toLocaleString("tr-TR", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

