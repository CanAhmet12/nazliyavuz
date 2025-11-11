"use client";

import type { BackupAutomationStatus } from "@/lib/api/backups";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";
import {
  AlertTriangle,
  CheckCircle2,
  Clock,
  Database,
  HardDrive,
  Info,
  RefreshCw,
  Server,
  XCircle,
} from "lucide-react";

type BackupAutomationStatusProps = {
  automation: BackupAutomationStatus;
};

const scheduleIcons: Record<string, React.ReactNode> = {
  database: <Database className="h-4 w-4" />,
  filesystem: <Server className="h-4 w-4" />,
  full: <HardDrive className="h-4 w-4" />,
};

export function BackupAutomationStatusCard({ automation }: BackupAutomationStatusProps) {
  const { schedule, restore } = automation;

  return (
    <section className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/60 p-6">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h3 className="text-sm font-semibold text-slate-100">Yedekleme Otomasyonu</h3>
          <p className="text-xs text-slate-400">
            Otomatik yedekleme görevlerinin durumu, zamanlaması ve son geri yükleme bilgileri.
          </p>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        {Object.entries(schedule).map(([key, detail]) => (
          <AutomationCard key={key} type={key} detail={detail} />
        ))}
      </div>

      <RestoreStatus restore={restore} />
    </section>
  );
}

type AutomationCardProps = {
  type: string;
  detail: BackupAutomationStatus["schedule"]["database"];
};

function AutomationCard({ type, detail }: AutomationCardProps) {
  const enabled = detail.enabled;
  const statusBadge = getStatusBadge(detail.last_status);

  return (
    <Card className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-900/60 p-4">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2 text-sm font-semibold text-slate-100">
          <span className="flex h-8 w-8 items-center justify-center rounded-xl bg-slate-800/70 text-sky-300">
            {scheduleIcons[type] ?? <Info className="h-4 w-4" />}
          </span>
          <span>{getScheduleLabel(type)}</span>
        </div>
        <Badge variant={enabled ? "secondary" : "outline"} className={enabled ? "text-emerald-300" : "text-slate-400"}>
          {enabled ? "Aktif" : "Pasif"}
        </Badge>
      </div>

      <div className="space-y-2 text-xs text-slate-400">
        <div className="flex items-center justify-between gap-2">
          <span className="flex items-center gap-2">
            <Clock className="h-3.5 w-3.5" />
            Cron
          </span>
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="truncate font-mono text-slate-200">{detail.cron ?? "-"}</span>
              </TooltipTrigger>
              <TooltipContent>
                <p className="font-mono text-xs">{detail.cron ?? "Tanımlı değil"}</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
        <Divider />
        <StatusRow label="Son çalıştırma" value={formatDate(detail.last_run_at)} />
        <StatusRow label="Son durum" value={statusBadge.label} className={statusBadge.className} icon={statusBadge.icon} />
        <StatusRow label="Son dosya" value={detail.last_file ?? "-"} />
        <StatusRow label="Sonraki çalışma" value={formatDate(detail.next_run_at)} />
        <StatusRow label="Depolama" value={detail.storage ?? "-"} />
        {detail.duration_seconds ? (
          <StatusRow label="Süre" value={`${detail.duration_seconds.toFixed(1)} sn`} />
        ) : null}
      </div>
    </Card>
  );
}

function RestoreStatus({
  restore,
}: {
  restore: BackupAutomationStatus["restore"];
}) {
  const status = restore.last_restore_status;

  const badge = getStatusBadge(status);

  return (
    <Card className="flex flex-col gap-4 rounded-2xl border border-slate-800/70 bg-slate-900/60 p-4 md:flex-row md:items-center md:justify-between">
      <div className="space-y-1">
        <p className="text-sm font-semibold text-slate-100">Son Geri Yükleme</p>
        <p className="text-xs text-slate-400">
          Manuel veya otomatik geri yükleme işlemlerinin son durumu.
        </p>
      </div>
      <div className="flex flex-wrap items-center gap-3 text-xs text-slate-300">
        <Badge variant="outline" className={cn("flex items-center gap-1", badge.className)}>
          {badge.icon}
          {badge.label}
        </Badge>
        <InfoRow label="Zaman" value={formatDate(restore.last_restore_at)} />
        <InfoRow label="Dosya" value={restore.last_restore_file ?? "-"} />
        {restore.initiated_by_name ? (
          <InfoRow label="Başlatan" value={restore.initiated_by_name} />
        ) : null}
        {restore.message ? (
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Badge variant="outline" className="cursor-help border-amber-500/40 text-amber-200">
                  Detay
                </Badge>
              </TooltipTrigger>
              <TooltipContent>
                <p className="max-w-xs text-xs">{restore.message}</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        ) : null}
      </div>
    </Card>
  );
}

function StatusRow({
  label,
  value,
  className,
  icon,
}: {
  label: string;
  value: string;
  className?: string;
  icon?: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between gap-2">
      <span className="text-slate-500">{label}</span>
      <span className={cn("flex items-center gap-1 text-slate-200", className)}>
        {icon}
        {value}
      </span>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <span className="flex items-center gap-2 rounded-full border border-slate-800/60 bg-slate-950/60 px-3 py-1">
      <span className="text-slate-500">{label}:</span>
      <span className="text-slate-200">{value}</span>
    </span>
  );
}

function Divider() {
  return <div className="h-px w-full bg-slate-800/60" />;
}

function formatDate(value?: string | null): string {
  if (!value) {
    return "-";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }
  return date.toLocaleString("tr-TR", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

function getScheduleLabel(type: string): string {
  switch (type) {
    case "database":
      return "Veritabanı Yedeği";
    case "filesystem":
      return "Dosya Sistemi Yedeği";
    case "full":
      return "Tam Sistem Yedeği";
    default:
      return "Yedek";
  }
}

function getStatusBadge(status?: string | null): { label: string; className: string; icon?: React.ReactNode } {
  switch (status) {
    case "completed":
    case "success":
      return { label: "Başarılı", className: "text-emerald-300", icon: <CheckCircle2 className="h-3.5 w-3.5" /> };
    case "failed":
      return { label: "Hatalı", className: "text-rose-300", icon: <XCircle className="h-3.5 w-3.5" /> };
    case "running":
    case "processing":
      return { label: "Devam ediyor", className: "text-sky-300", icon: <RefreshCw className="h-3.5 w-3.5 animate-spin" /> };
    default:
      return { label: "Bilinmiyor", className: "text-slate-400", icon: <AlertTriangle className="h-3.5 w-3.5" /> };
  }
}

