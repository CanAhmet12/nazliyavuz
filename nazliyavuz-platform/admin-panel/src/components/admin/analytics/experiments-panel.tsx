"use client";

import { useState } from "react";
import toast from "react-hot-toast";
import { experimentsQueryKey, useExperiments } from "@/hooks/use-experiments";
import {
  createExperiment,
  type Experiment,
  type ExperimentPayload,
  updateExperimentStatus,
} from "@/lib/api/experiments";
import { useQueryClient } from "@tanstack/react-query";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus, FlaskConical, Loader2 } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";

export function ExperimentsPanel() {
  const queryClient = useQueryClient();
  const { data, isLoading, isError, refetch } = useExperiments();
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [formState, setFormState] = useState<ExperimentPayload>({
    name: "",
    key: "",
    type: "feature",
    status: "draft",
    traffic_allocation: 100,
    variants: [
      { name: "Kontrol", key: "control", is_control: true, traffic_allocation: 50 },
      { name: "Varyant A", key: "variant_a", traffic_allocation: 50 },
    ],
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const experiments = data?.experiments ?? [];

  const handleStatusChange = async (experimentId: number, status: Experiment["status"]) => {
    try {
      await updateExperimentStatus(experimentId, status);
      await queryClient.invalidateQueries({ queryKey: experimentsQueryKey });
      toast.success("Deney durumu güncellendi.");
    } catch (error) {
      const message = error instanceof Error ? error.message : "Durum güncellenirken hata oluştu.";
      toast.error(message);
    }
  };

  const handleCreateExperiment = async () => {
    if (!formState.name.trim() || !formState.key.trim()) {
      toast.error("Deney adı ve anahtarı zorunludur.");
      return;
    }

    setIsSubmitting(true);
    try {
      await createExperiment(formState);
      await queryClient.invalidateQueries({ queryKey: experimentsQueryKey });
      setIsDialogOpen(false);
      setFormState({
        name: "",
        key: "",
        type: "feature",
        status: "draft",
        traffic_allocation: 100,
        variants: [
          { name: "Kontrol", key: "control", is_control: true, traffic_allocation: 50 },
          { name: "Varyant A", key: "variant_a", traffic_allocation: 50 },
        ] as ExperimentPayload["variants"],
      });
      toast.success("Yeni deney oluşturuldu.");
    } catch (error) {
      const message = error instanceof Error ? error.message : "Deney oluşturulurken bir hata oluştu.";
      toast.error(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) {
    return <ExperimentsSkeleton />;
  }

  if (isError) {
    return (
      <div className="space-y-4 rounded-2xl border border-rose-500/40 bg-rose-500/10 p-6 text-xs text-rose-100">
        <div className="flex items-center justify-between gap-2">
          <p>Deney verileri yüklenirken bir hata oluştu.</p>
          <Button size="sm" variant="outline" onClick={() => refetch()}>
            Tekrar dene
          </Button>
        </div>
      </div>
    );
  }

  return (
    <section className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="flex items-center gap-2 text-sm font-semibold text-slate-100">
            <FlaskConical className="h-4 w-4 text-sky-300" />
            A/B testleri
          </h3>
          <p className="text-xs text-slate-400">
            Canlı deneylerin performans metriklerini takip edin, yeni testler başlatın.
          </p>
        </div>
        <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
          <DialogTrigger asChild>
            <Button size="sm" className="gap-2">
              <Plus className="h-4 w-4" />
              Yeni deney
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-lg">
            <DialogHeader>
              <DialogTitle>Yeni A/B testi oluştur</DialogTitle>
              <DialogDescription>
                Deney ismini, anahtarını ve varyantlarını belirleyerek yeni bir test tanımlayın.
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4">
              <div className="space-y-2">
                <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                  Deney adı
                </label>
                <Input
                  placeholder="Örn. Kayıt formu tasarım testi"
                  value={formState.name}
                  onChange={(event) =>
                    setFormState((prev) => ({
                      ...prev,
                      name: event.target.value,
                    }))
                  }
                />
              </div>
              <div className="space-y-2">
                <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                  Anahtar
                </label>
                <Input
                  placeholder="signup_form_test"
                  value={formState.key}
                  onChange={(event) =>
                    setFormState((prev) => ({
                      ...prev,
                      key: event.target.value,
                    }))
                  }
                />
              </div>
              <div className="grid gap-3 md:grid-cols-2">
                <div className="space-y-2">
                  <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                    Tür
                  </label>
                  <Select
                    value={formState.type}
                    onValueChange={(value) =>
                      setFormState((prev) => ({
                        ...prev,
                        type: value,
                      }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Tür seçin" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="feature">Özellik</SelectItem>
                      <SelectItem value="messaging">İletişim</SelectItem>
                      <SelectItem value="pricing">Fiyatlandırma</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                    Başlangıç durumu
                  </label>
                  <Select
                    value={formState.status}
                    onValueChange={(value) =>
                      setFormState((prev) => ({
                        ...prev,
                        status: value as Experiment["status"],
                      }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Durum" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="draft">Taslak</SelectItem>
                      <SelectItem value="running">Canlı</SelectItem>
                      <SelectItem value="paused">Beklemede</SelectItem>
                      <SelectItem value="completed">Tamamlandı</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="space-y-2">
                <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                  Hipotez
                </label>
                <Textarea
                  rows={3}
                  placeholder="Beklediğiniz etkileri yazın..."
                  value={formState.hypothesis ?? ""}
                  onChange={(event) =>
                    setFormState((prev) => ({
                      ...prev,
                      hypothesis: event.target.value,
                    }))
                  }
                />
              </div>
              <div className="space-y-2">
                <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">
                  Başarı metriği
                </label>
                <Textarea
                  rows={3}
                  placeholder="Örn. Kayıt tamamlama oranı, ilk rezervasyon süresi..."
                  value={formState.success_metric ?? ""}
                  onChange={(event) =>
                    setFormState((prev) => ({
                      ...prev,
                      success_metric: event.target.value,
                    }))
                  }
                />
              </div>
            </div>
            <DialogFooter>
              <Button variant="ghost" onClick={() => setIsDialogOpen(false)} disabled={isSubmitting}>
                Vazgeç
              </Button>
              <Button onClick={handleCreateExperiment} disabled={isSubmitting}>
                {isSubmitting ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                Kaydet
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </header>

      {experiments.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-slate-800/70 bg-slate-950/60 p-6 text-sm text-slate-400">
          Henüz tanımlanmış bir A/B testi yok.{" "}
          <button
            type="button"
            className="font-semibold text-slate-100 hover:underline"
            onClick={() => setIsDialogOpen(true)}
          >
            İlkini oluşturmaya başlayın.
          </button>
        </div>
      ) : (
        <div className="grid gap-4 xl:grid-cols-2">
          {experiments.map((experiment) => (
            <ExperimentCard
              key={experiment.id}
              experiment={experiment}
              onStatusChange={(status) => handleStatusChange(experiment.id, status)}
            />
          ))}
        </div>
      )}
    </section>
  );
}

type ExperimentCardProps = {
  experiment: Experiment;
  onStatusChange: (status: Experiment["status"]) => void;
};

function ExperimentCard({ experiment, onStatusChange }: ExperimentCardProps) {
  const statusBadge = statusVariant(experiment.status);
  const lastUpdated = experiment.ends_at ?? experiment.starts_at ?? null;

  return (
    <article className="space-y-4 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-5">
      <header className="flex items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-slate-100">{experiment.name}</p>
          <p className="text-xs text-slate-400">{experiment.key}</p>
        </div>
        <Badge variant="default" className={statusBadge.className}>
          {statusBadge.label}
        </Badge>
      </header>

      <div className="grid gap-3 text-xs text-slate-300 md:grid-cols-2">
        <MetricItem label="Atanan kullanıcı" value={formatNumber(experiment.metrics.assignments)} />
        <MetricItem
          label="Dönüşüm oranı"
          value={`${experiment.metrics.conversion_rate.toFixed(2)}%`}
          tone={experiment.metrics.conversion_rate >= 5 ? "positive" : undefined}
        />
        <MetricItem
          label="Toplam dönüşüm"
          value={formatNumber(experiment.metrics.conversions)}
        />
        <MetricItem
          label="Dönüşüm değeri"
          value={formatCurrency(experiment.metrics.conversion_value)}
        />
      </div>

      <div className="space-y-2 rounded-xl border border-slate-800/60 bg-slate-950/60 p-4 text-xs text-slate-300">
        <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">
          Varyant performansı
        </p>
        <div className="space-y-2">
          {experiment.variants.map((variant) => (
            <div
              key={variant.id}
              className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-slate-800/60 bg-slate-950/80 px-3 py-2"
            >
              <div className="flex flex-col">
                <span className="font-medium text-slate-100">
                  {variant.name} {variant.is_control ? "(Kontrol)" : ""}
                </span>
                <span className="text-[11px] text-slate-500">{variant.key}</span>
              </div>
              <div className="flex items-center gap-4 text-[11px] text-slate-300">
                <span>{variant.traffic_allocation}% trafik</span>
                <span>{formatNumber(variant.assignments)} atama</span>
                <span className={variant.conversion_rate >= 5 ? "text-emerald-300" : ""}>
                  {variant.conversion_rate.toFixed(2)}%
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>

      <footer className="flex flex-wrap items-center justify-between gap-3">
        <div className="text-[11px] text-slate-500">
          {lastUpdated
            ? `Son aktivite ${formatDistanceToNow(new Date(lastUpdated), {
                addSuffix: true,
                locale: tr,
              })}`
            : "Zamanlanmamış"}
        </div>
        <Select onValueChange={(value) => onStatusChange(value as Experiment["status"])} value={experiment.status}>
          <SelectTrigger className="h-8 w-[150px] border-slate-700 bg-slate-900 text-xs text-slate-300">
            <SelectValue placeholder="Durum değiştir" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="draft">Taslak</SelectItem>
            <SelectItem value="running">Canlı</SelectItem>
            <SelectItem value="paused">Beklemede</SelectItem>
            <SelectItem value="completed">Tamamlandı</SelectItem>
          </SelectContent>
        </Select>
      </footer>
    </article>
  );
}

function MetricItem({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone?: "positive" | "negative";
}) {
  return (
    <div className="rounded-lg border border-slate-800/60 bg-slate-950/60 p-3">
      <p className="text-[11px] uppercase tracking-wide text-slate-500">{label}</p>
      <p
        className={`mt-1 text-sm font-semibold ${
          tone === "positive" ? "text-emerald-300" : tone === "negative" ? "text-rose-300" : "text-slate-100"
        }`}
      >
        {value}
      </p>
    </div>
  );
}

function ExperimentsSkeleton() {
  return (
    <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <Skeleton className="h-6 w-56" />
      <div className="grid gap-4 xl:grid-cols-2">
        {Array.from({ length: 2 }).map((_, index) => (
          <Skeleton key={index} className="h-60 rounded-2xl border border-slate-800/70 bg-slate-900/60" />
        ))}
      </div>
    </div>
  );
}

function statusVariant(status: Experiment["status"]) {
  switch (status) {
    case "running":
      return { label: "Canlı", className: "border-emerald-500/40 bg-emerald-500/10 text-emerald-200" };
    case "paused":
      return { label: "Beklemede", className: "border-amber-500/40 bg-amber-500/10 text-amber-200" };
    case "completed":
      return { label: "Tamamlandı", className: "border-sky-500/40 bg-sky-500/10 text-sky-200" };
    default:
      return { label: "Taslak", className: "border-slate-700/60 bg-slate-900/60 text-slate-300" };
  }
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat("tr-TR").format(value);
}

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
    maximumFractionDigits: 0,
  }).format(value);
}

