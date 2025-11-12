"use client";

import type { TeacherBenchmarkResponse } from "@/lib/api/analytics";
import { Badge } from "@/components/ui/badge";
import { formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";
import {
  Star,
  TrendingUp,
  AlertTriangle,
  Crown,
  Timer,
  DollarSign,
  Users2,
} from "lucide-react";

type TeacherBenchmarkProps = {
  data: TeacherBenchmarkResponse["benchmark"];
};

export function TeacherBenchmarkPanel({ data }: TeacherBenchmarkProps) {
  return (
    <section className="space-y-6 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <header className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 className="text-sm font-semibold text-slate-100">Öğretmen benchmark analizi</h3>
          <p className="text-xs text-slate-400">
            Onaylı öğretmen performans metrikleri, liderler ve riskli segmentler.
          </p>
        </div>
        <Badge variant="default" className="border-slate-700/60 text-xs text-slate-300">
          {formatNumber(data.summary.total_teachers)} öğretmen
        </Badge>
      </header>

      <SummaryGrid summary={data.summary} />

      <LeadersGrid leaders={data.leaders} />

      <DistributionGrid distribution={data.distribution} />
    </section>
  );
}

function SummaryGrid({
  summary,
}: {
  summary: TeacherBenchmarkResponse["benchmark"]["summary"];
}) {
  const items = [
    {
      title: "Aktif (7 gün)",
      value: formatNumber(summary.active_7_days),
      helper: `${formatNumber(summary.active_30_days)} kişi 30 günde giriş yaptı`,
      icon: <Timer className="h-4 w-4 text-sky-300" />,
    },
    {
      title: "Ortalama rating",
      value: summary.average_rating.toFixed(2),
      helper: "Onaylı öğretmen ortalaması",
      icon: <Star className="h-4 w-4 text-amber-300" />,
    },
    {
      title: "Ders/öğretmen",
      value: summary.average_lessons_per_teacher.toFixed(2),
      helper: "Toplam tamamlanmış dersler baz alınarak",
      icon: <Users2 className="h-4 w-4 text-emerald-300" />,
    },
    {
      title: "Gelir/öğretmen",
      value: formatCurrency(summary.average_revenue_per_teacher),
      helper: `Toplam ${formatCurrency(summary.total_revenue)} gelire göre`,
      icon: <DollarSign className="h-4 w-4 text-rose-300" />,
    },
  ];

  return (
    <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
      {items.map((item) => (
        <article
          key={item.title}
          className="rounded-xl border border-slate-800/70 bg-slate-950/70 p-4 text-sm text-slate-200"
        >
          <div className="flex items-center justify-between">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
              {item.title}
            </p>
            {item.icon}
          </div>
          <p className="mt-2 text-lg font-semibold text-slate-100">{item.value}</p>
          <p className="text-xs text-slate-400">{item.helper}</p>
        </article>
      ))}
    </div>
  );
}

function LeadersGrid({
  leaders,
}: {
  leaders: TeacherBenchmarkResponse["benchmark"]["leaders"];
}) {
  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <LeaderColumn
        title="En yüksek performans"
        description="Gelir, rating ve öğrenci sayısı bazlı genel sıralama."
        icon={<Crown className="h-4 w-4 text-amber-300" />}
        data={leaders.top_performers}
        badgeVariant="primary"
      />
      <LeaderColumn
        title="Yükselişte olanlar"
        description="Son 30 güne göre ders sayısını ciddi oranda artıran öğretmenler."
        icon={<TrendingUp className="h-4 w-4 text-emerald-300" />}
        data={leaders.emerging}
        badgeVariant="emerald"
      />
      <LeaderColumn
        title="Dikkat edilmesi gerekenler"
        description="Yüksek iptal oranı veya performans düşüşü görülen segment."
        icon={<AlertTriangle className="h-4 w-4 text-rose-300" />}
        data={leaders.attention}
        badgeVariant="rose"
      />
    </div>
  );
}

type BadgeVariant = "primary" | "emerald" | "rose";

function LeaderColumn({
  title,
  description,
  data,
  icon,
  badgeVariant,
}: {
  title: string;
  description: string;
  data: TeacherLeader[];
  icon: React.ReactNode;
  badgeVariant: BadgeVariant;
}) {
  const formatted = data.map(formatLeader);

  return (
    <section className="space-y-3 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-start gap-2">
        {icon}
        <div>
          <p className="text-sm font-semibold text-slate-100">{title}</p>
          <p className="text-xs text-slate-400">{description}</p>
        </div>
      </header>
      <div className="space-y-3 text-sm text-slate-200">
        {formatted.length === 0 ? (
          <p className="text-xs text-slate-500">Veri bulunamadı.</p>
        ) : (
          formatted.map((entry) => (
            <article
              key={entry.id}
              className="rounded-lg border border-slate-800/60 bg-slate-950/60 p-3 text-xs"
            >
              <div className="flex items-center justify-between gap-2">
                <div>
                  <p className="font-semibold text-slate-100">{entry.name}</p>
                  <p className="text-[11px] text-slate-500">{entry.email}</p>
                </div>
                <Badge variant="default" className={badgeClass(badgeVariant)}>
                  Skor: {entry.rankingScore.toFixed(1)}
                </Badge>
              </div>
              <div className="mt-2 grid grid-cols-2 gap-x-3 gap-y-1 text-[11px] text-slate-300">
                <span>🎓 {entry.uniqueStudents} öğrenci</span>
                <span>📚 {entry.totalLessons} ders</span>
                <span>⭐ {entry.ratingAvg.toFixed(2)} ({entry.ratingCount})</span>
                <span>💰 {formatCurrency(entry.totalRevenue)}</span>
              </div>
              {entry.lastReservation && (
                <p className="mt-1 text-[10px] text-slate-500">
                  Son ders {formatDistanceToNow(new Date(entry.lastReservation), { locale: tr })} önce
                </p>
              )}
            </article>
          ))
        )}
      </div>
    </section>
  );
}

function formatLeader(leader: TeacherLeader) {
  return {
    id: leader.id,
    name: leader.name,
    email: leader.email,
    ratingAvg: leader.rating_avg,
    ratingCount: leader.rating_count,
    totalLessons: leader.total_lessons,
    uniqueStudents: leader.unique_students,
    totalRevenue: leader.total_revenue,
    lastReservation: leader.last_reservation_at,
    rankingScore: leader.ranking_score,
  };
}

function badgeClass(variant: BadgeVariant) {
  switch (variant) {
    case "emerald":
      return "bg-emerald-500/20 text-emerald-200 border-emerald-500/40";
    case "rose":
      return "bg-rose-500/20 text-rose-200 border-rose-500/40";
    default:
      return "bg-amber-500/20 text-amber-200 border-amber-500/40";
  }
}

function DistributionGrid({
  distribution,
}: {
  distribution: TeacherBenchmarkResponse["benchmark"]["distribution"];
}) {
  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <DistributionCard
        title="Rating dağılımı"
        description="Öğretmenlerin genel rating dağılımı"
        icon={<Star className="h-4 w-4 text-amber-300" />}
        data={distribution.ratings}
      />
      <DistributionCard
        title="Ders yükü"
        description="Tüm zaman toplam ders sayısına göre"
        icon={<Users2 className="h-4 w-4 text-sky-300" />}
        data={distribution.workload}
      />
      <DistributionCard
        title="Son 30 gün aktivitesi"
        description="Son 30 günde tamamlanan ders sayısı"
        icon={<TrendingUp className="h-4 w-4 text-emerald-300" />}
        data={distribution.activity}
      />
    </div>
  );
}

function DistributionCard({
  title,
  description,
  icon,
  data,
}: {
  title: string;
  description: string;
  icon: React.ReactNode;
  data: TeacherBenchmarkDistributionItem[];
}) {
  return (
    <section className="space-y-3 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-center gap-2">
        {icon}
        <div>
          <p className="text-sm font-semibold text-slate-100">{title}</p>
          <p className="text-xs text-slate-400">{description}</p>
        </div>
      </header>
      <div className="space-y-2 text-xs text-slate-300">
        {data.length === 0 ? (
          <p className="text-xs text-slate-500">Veri bulunamadı.</p>
        ) : (
          data.map((item) => (
            <div key={item.bucket} className="rounded-lg border border-slate-800/50 bg-slate-950/60 p-3">
              <div className="flex items-center justify-between">
                <span className="text-slate-200">
                  {item.label ?? `${item.bucket}`}
                </span>
                <span>{formatNumber(item.count)} öğretmen</span>
              </div>
              <div className="mt-2 h-1.5 w-full rounded-full bg-slate-900/60">
                <div
                  className="h-1.5 rounded-full bg-gradient-to-r from-sky-500 to-emerald-400"
                  style={{ width: `${item.percentage}%` }}
                />
              </div>
              <p className="mt-1 text-[11px] text-slate-500">{item.percentage.toFixed(1)}%</p>
            </div>
          ))
        )}
      </div>
    </section>
  );
}

type TeacherLeader = TeacherBenchmarkResponse["benchmark"]["leaders"]["top_performers"][number];
type TeacherBenchmarkDistributionItem =
  TeacherBenchmarkResponse["benchmark"]["distribution"]["ratings"][number];

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

