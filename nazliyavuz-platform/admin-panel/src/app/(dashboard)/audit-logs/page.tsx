"use client";

import { useMemo, useState } from "react";
import type { UseQueryResult } from "@tanstack/react-query";
import { format, formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";
import toast from "react-hot-toast";
import { useAuditLogs } from "@/hooks/use-audit-logs";
import { AuditTable } from "@/components/admin/audit/audit-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { AuditLog, AuditLogsFilters, AuditLogsResponse } from "@/lib/api/audit";
import {
  CalendarRange,
  Copy,
  Filter,
  RefreshCcw,
  Search,
  ShieldAlert,
  Target,
  User,
} from "lucide-react";

const severityOptions = [
  { value: "", label: "Tümü" },
  { value: "info", label: "Bilgi" },
  { value: "warning", label: "Uyarı" },
  { value: "error", label: "Hata" },
  { value: "critical", label: "Kritik" },
];

const sortOptions = [
  { value: "created_at_desc", label: "Son eklenen" },
  { value: "created_at_asc", label: "İlk eklenen" },
  { value: "severity_desc", label: "Şiddet (yüksek → düşük)" },
  { value: "severity_asc", label: "Şiddet (düşük → yüksek)" },
];

export default function AuditLogsPage() {
  const [filters, setFilters] = useState<AuditLogsFilters>({
    page: 1,
    per_page: 20,
    sort: "created_at_desc",
    query: "",
  });
  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null);
  const auditLogsQuery = useAuditLogs(filters) as UseQueryResult<AuditLogsResponse, Error>;
  const { data: auditData, isLoading, isFetching, refetch } = auditLogsQuery;

  const actions = auditData?.filters?.actions;
  const targetTypes = auditData?.filters?.target_types;

  const availableActions = useMemo(() => actions ?? [], [actions]);
  const availableTargetTypes = useMemo(() => targetTypes ?? [], [targetTypes]);

  const quickActions = useMemo(() => availableActions.slice(0, 6), [availableActions]);

  const updateFilters = <K extends keyof AuditLogsFilters>(
    key: K,
    value: AuditLogsFilters[K],
  ) => {
    setFilters((prev) => {
      const next: AuditLogsFilters = {
        ...prev,
        [key]: value,
      };

      if (key !== "page") {
        next.page = 1;
      }

      return next;
    });
  };

  const resetFilters = () => {
    setFilters({
      page: 1,
      per_page: filters.per_page,
      sort: "created_at_desc",
      query: "",
    });
  };

  const metaJson = selectedLog ? JSON.stringify(selectedLog.meta ?? {}, null, 2) : "";

  const copyMeta = async () => {
    if (!metaJson) {
      toast.error("Kopyalanacak metadata bulunamadı.");
      return;
    }

    try {
      await navigator.clipboard.writeText(metaJson);
      toast.success("Metadata panoya kopyalandı.");
    } catch (error) {
      toast.error("Kopyalama sırasında bir hata oluştu.");
      console.error("Failed to copy audit metadata", error);
    }
  };

  return (
    <div className="space-y-6">
      <Dialog open={selectedLog !== null} onOpenChange={() => setSelectedLog(null)}>
        <DialogContent className="max-w-3xl">
          <DialogHeader>
            <DialogTitle className="flex items-center justify-between gap-3">
              <span className="flex items-center gap-2 text-sm uppercase tracking-wide text-slate-400">
                <ShieldAlert className="h-4 w-4" />
                {selectedLog ? selectedLog.action.replace(/_/g, " ") : "Audit kaydı"}
              </span>
              {selectedLog ? <Badge variant="info">{formatDistanceToNow(new Date(selectedLog.created_at), { addSuffix: true, locale: tr })}</Badge> : null}
            </DialogTitle>
            <DialogDescription>
              Audit kaydının detaylarını inceleyin. Metadata ve ortam bilgileri olası sorunları analiz etmenize yardımcı olur.
            </DialogDescription>
          </DialogHeader>

          {selectedLog ? (
            <div className="space-y-6">
              <div className="grid gap-4 rounded-xl border border-slate-800/70 bg-slate-950/60 p-4 md:grid-cols-2">
                <InfoRow
                  icon={<ShieldAlert className="h-4 w-4 text-sky-300" />}
                  label="Şiddet"
                  value={<Badge>{selectedLog.severity}</Badge>}
                />
                <InfoRow
                  icon={<CalendarRange className="h-4 w-4 text-sky-300" />}
                  label="Zaman"
                  value={
                    <span className="flex flex-col">
                      <span>{format(new Date(selectedLog.created_at), "dd MMMM yyyy HH:mm", { locale: tr })}</span>
                      <span className="text-xs text-slate-500">
                        {formatDistanceToNow(new Date(selectedLog.created_at), { addSuffix: true, locale: tr })}
                      </span>
                    </span>
                  }
                />
                <InfoRow
                  icon={<User className="h-4 w-4 text-sky-300" />}
                  label="Kullanıcı"
                  value={
                    selectedLog.user ? (
                      <span className="flex flex-col">
                        <span>{selectedLog.user.name}</span>
                        <span className="text-xs text-slate-500">{selectedLog.user.email}</span>
                      </span>
                    ) : (
                      "Sistem"
                    )
                  }
                />
                <InfoRow
                  icon={<Target className="h-4 w-4 text-sky-300" />}
                  label="Hedef"
                  value={formatTarget(selectedLog.target_type, selectedLog.target_id) ?? "-"}
                />
                <InfoRow
                  label="IP adresi"
                  value={selectedLog.ip_address ?? "-"}
                />
                <InfoRow
                  label="User-Agent"
                  value={
                    <span className="line-clamp-2 text-xs text-slate-400">
                      {selectedLog.user_agent ?? "-"}
                    </span>
                  }
                />
              </div>

              {selectedLog.description ? (
                <div className="space-y-2 rounded-xl border border-slate-800/70 bg-slate-950/60 p-4 text-sm text-slate-300">
                  <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                    Açıklama
                  </p>
                  <p>{selectedLog.description}</p>
                </div>
              ) : null}

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                    Metadata
                  </p>
                  <Button size="sm" variant="secondary" className="gap-2" onClick={copyMeta}>
                    <Copy className="h-3.5 w-3.5" />
                    Kopyala
                  </Button>
                </div>
                <pre className="max-h-80 overflow-auto rounded-xl border border-slate-800/70 bg-slate-950/70 p-4 text-xs text-slate-300">
                  {metaJson || "// Metadata bulunamadı"}
                </pre>
              </div>
            </div>
          ) : null}
        </DialogContent>
      </Dialog>

      <div className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-100">Audit Kayıtları</h2>
        <p className="text-sm text-slate-400">
          Kritik yönetici aksiyonlarını, kullanıcı işlemlerini ve sistem denetim kayıtlarını görüntüleyin.
        </p>
      </div>

      <div className="space-y-4 rounded-2xl border border-slate-800/60 bg-slate-950/60 p-5">
        <div className="grid gap-4 md:grid-cols-2">
          <div>
            <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
              Genel arama
            </label>
            <div className="mt-2 flex items-center gap-2 rounded-xl border border-slate-800/60 bg-slate-950/80 px-3">
              <Search className="h-4 w-4 text-slate-600" />
              <Input
                className="border-none bg-transparent px-0 text-sm focus-visible:ring-0"
                placeholder="Aksiyon, kullanıcı, açıklama veya metadata terimleri..."
                value={filters.query ?? ""}
                onChange={(event) => updateFilters("query", event.target.value)}
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
              Şiddet
            </label>
            <Select
              value={filters.severity ?? ""}
              onValueChange={(value) => updateFilters("severity", value || undefined)}
            >
              <SelectTrigger className="mt-2">
                <SelectValue placeholder="Şiddet seçin" />
              </SelectTrigger>
              <SelectContent>
                {severityOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-4">
          <FilterSelect
            label="Aksiyon"
            value={filters.action ?? ""}
            placeholder="Aksiyon seç"
            options={availableActions}
            onChange={(value) => updateFilters("action", value || undefined)}
          />
          <FilterSelect
            label="Hedef tipi"
            value={filters.target_type ?? ""}
            placeholder="Hedef tipi seç"
            options={availableTargetTypes}
            onChange={(value) => updateFilters("target_type", value || undefined)}
          />
          <div>
            <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
              Kullanıcı ID
            </label>
            <Input
              type="number"
              className="mt-2"
              placeholder="ID"
              value={filters.user_id?.toString() ?? ""}
              onChange={(event) => {
                const value = event.target.value;
                updateFilters("user_id", value ? Number(value) : undefined);
              }}
            />
          </div>
          <div>
            <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
              Hedef ID
            </label>
            <Input
              type="number"
              className="mt-2"
              placeholder="ID"
              value={filters.target_id?.toString() ?? ""}
              onChange={(event) => {
                const value = event.target.value;
                updateFilters("target_id", value ? Number(value) : undefined);
              }}
            />
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-4">
          <div>
            <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
              Başlangıç tarihi
            </label>
            <Input
              type="date"
              className="mt-2"
              value={filters.from ?? ""}
              onChange={(event) => updateFilters("from", event.target.value || undefined)}
            />
          </div>
          <div>
            <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
              Bitiş tarihi
            </label>
            <Input
              type="date"
              className="mt-2"
              value={filters.to ?? ""}
              onChange={(event) => updateFilters("to", event.target.value || undefined)}
            />
          </div>
          <div>
            <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
              Sıralama
            </label>
            <Select
              value={filters.sort ?? "created_at_desc"}
              onValueChange={(value) => updateFilters("sort", value)}
            >
              <SelectTrigger className="mt-2">
                <SelectValue placeholder="Sıralama" />
              </SelectTrigger>
              <SelectContent>
                {sortOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex items-end gap-2">
            <Button variant="ghost" size="sm" className="text-xs text-slate-400 hover:text-slate-100" onClick={resetFilters}>
              Filtreleri sıfırla
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="text-xs text-sky-300 hover:text-sky-200"
              onClick={() => refetch()}
              disabled={isFetching}
            >
              <RefreshCcw className="mr-1 h-3 w-3" />
              Yenile
            </Button>
          </div>
        </div>

        {quickActions.length > 0 ? (
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs uppercase tracking-wide text-slate-500">Hızlı filtreler:</span>
            {quickActions.map((action) => {
              const active = filters.action === action;
              return (
                <button
                  key={action}
                  type="button"
                  className="flex items-center gap-1 rounded-full border border-slate-800/70 bg-slate-950/70 px-3 py-1 text-xs text-slate-300 transition-colors hover:bg-slate-900/60 data-[active=true]:border-sky-500/40 data-[active=true]:bg-sky-500/10 data-[active=true]:text-sky-300"
                  data-active={active}
                  onClick={() => updateFilters("action", active ? undefined : action)}
                >
                  <Filter className="h-3 w-3" />
                  {action.replace(/_/g, " ")}
                </button>
              );
            })}
          </div>
        ) : null}

        <div className="flex items-center justify-between text-xs text-slate-500">
          <span>
            Toplam {auditData?.pagination.total ?? 0} kayıt • Sayfa{" "}
            {auditData?.pagination.current_page ?? filters.page} / {auditData?.pagination.last_page ?? "?"}
          </span>
          <div className="flex items-center gap-2">
            <Button
              variant="ghost"
              className="text-xs"
              onClick={() => updateFilters("page", Math.max(1, (filters.page ?? 1) - 1))}
              disabled={(filters.page ?? 1) <= 1 || isFetching}
            >
              Önceki
            </Button>
            <Button
              variant="ghost"
              className="text-xs"
              onClick={() =>
                updateFilters(
                  "page",
                  Math.min(auditData?.pagination.last_page ?? (filters.page ?? 1), (filters.page ?? 1) + 1),
                )
              }
              disabled={(filters.page ?? 1) >= (auditData?.pagination.last_page ?? 1) || isFetching}
            >
              Sonraki
            </Button>
          </div>
        </div>
      </div>

      {isLoading ? (
        <Skeleton className="h-64 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
      ) : (
        <AuditTable logs={auditData?.logs ?? []} onShowDetails={setSelectedLog} />
      )}

      <div className="rounded-2xl border border-slate-800/70 bg-slate-950/60 p-5 text-xs text-slate-400">
        <p className="font-medium text-slate-200">İpucu</p>
        <p className="mt-1">
          Liste tüm admin aksiyonlarını içerir. Kritik işlemler (yedek geri yükleme, rol değişiklikleri, toplu silmeler vb.) için detay panelini kullanarak hangi parametrelerin işlendiğini görebilirsiniz.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <Badge variant="info">user_status_updated</Badge>
          <Badge variant="warning">backup_restore</Badge>
          <Badge variant="destructive">multiple_users_deleted</Badge>
        </div>
      </div>
    </div>
  );
}

function FilterSelect({
  label,
  value,
  placeholder,
  options,
  onChange,
}: {
  label: string;
  value: string;
  placeholder: string;
  options: string[];
  onChange: (value: string) => void;
}) {
  return (
    <div>
      <label className="text-xs font-medium uppercase tracking-wide text-slate-500">
        {label}
      </label>
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger className="mt-2">
          <SelectValue placeholder={placeholder} />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="">{`Tüm ${label.toLowerCase()}lar`}</SelectItem>
          {options.map((option) => (
            <SelectItem key={option} value={option}>
              {option.replace(/_/g, " ")}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}

function InfoRow({
  icon,
  label,
  value,
}: {
  icon?: React.ReactNode;
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="flex items-start gap-3 rounded-lg border border-slate-800/70 bg-slate-950/70 p-3 text-sm text-slate-200">
      {icon ? <span className="mt-0.5 text-sky-300">{icon}</span> : null}
      <div className="flex flex-col">
        <span className="text-xs uppercase tracking-wide text-slate-500">{label}</span>
        <span className="mt-1 text-sm leading-tight text-slate-100">{value}</span>
      </div>
    </div>
  );
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

