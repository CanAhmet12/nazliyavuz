"use client";

import { Badge } from "@/components/ui/badge";
import type { UserSegmentation } from "@/lib/api/analytics";
import {
  Users,
  GraduationCap,
  UserCheck,
  Target,
  Bell,
  Mail,
  TrendingUp,
} from "lucide-react";

type UserSegmentationProps = {
  data: UserSegmentation;
};

export function UserSegmentationPanel({ data }: UserSegmentationProps) {
  const summaryCards = [
    {
      label: "Toplam kullanıcı",
      value: formatNumber(data.totals.total_users),
      icon: <Users className="h-4 w-4 text-sky-400" />,
      helper: `Son 30 günde ${formatNumber(data.totals.new_last_30_days)} yeni kullanıcı`,
    },
    {
      label: "Öğrenci oranı",
      value: computePercentage(data.totals.students, data.totals.total_users),
      icon: <GraduationCap className="h-4 w-4 text-emerald-400" />,
      helper: `${formatNumber(data.totals.students)} öğrenci`,
    },
    {
      label: "Öğretmen oranı",
      value: computePercentage(data.totals.teachers, data.totals.total_users),
      icon: <UserCheck className="h-4 w-4 text-amber-400" />,
      helper: `${formatNumber(data.totals.teachers)} öğretmen`,
    },
    {
      label: "Son 7 günde aktif",
      value: formatNumber(data.totals.active_last_7_days),
      icon: <TrendingUp className="h-4 w-4 text-rose-300" />,
      helper: "7 gün içinde giriş yapan kullanıcılar",
    },
  ];

  return (
    <section className="space-y-6 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <div className="space-y-2">
        <h3 className="text-sm font-semibold text-slate-100">Kullanıcı segment analizi</h3>
        <p className="text-xs text-slate-400">
          Rölere, aktivitelerine ve etkileşim seviyelerine göre kullanıcı dağılımı.
        </p>
      </div>

      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        {summaryCards.map((card) => (
          <article
            key={card.label}
            className="flex flex-col gap-3 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4 text-sm text-slate-200"
          >
            <div className="flex items-center justify-between gap-2">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                {card.label}
              </p>
              {card.icon}
            </div>
            <p className="text-lg font-semibold text-slate-100">{card.value}</p>
            <p className="text-xs text-slate-400">{card.helper}</p>
          </article>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <RoleDistribution data={data.role_distribution} />
        <TeacherStatus data={data.teacher_status} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <StudentActivity data={data.student_activity} total={data.totals.students} />
        <RetentionBreakdown data={data.retention} />
      </div>

      <MarketingPreferences data={data.marketing} total={data.totals.total_users} />

      <FocusMetrics data={data.focus} />

      <CohortTable cohorts={data.cohorts} />

      <TopCategories data={data.top_categories} />
    </section>
  );
}

function RoleDistribution({ data }: { data: UserSegmentation["role_distribution"] }) {
  const total = data.reduce((sum, item) => sum + item.count, 0);

  return (
    <section className="space-y-4 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-center justify-between">
        <div>
          <p className="text-sm font-semibold text-slate-100">Rol dağılımı</p>
          <p className="text-xs text-slate-400">
            Kullanıcıların rollerine göre dağılım ve son 30 günlük büyüme.
          </p>
        </div>
      </header>
      <div className="space-y-3">
        {data.map((item) => (
          <div key={item.role} className="space-y-1.5">
            <div className="flex items-center justify-between text-xs text-slate-400">
              <span className="font-medium text-slate-200">{translateRole(item.role)}</span>
              <span>
                {formatNumber(item.count)} • {item.percentage.toFixed(1)}% •{" "}
                <span className={item.growth_30d >= 0 ? "text-emerald-300" : "text-rose-300"}>
                  {item.growth_30d >= 0 ? "+" : ""}
                  {item.growth_30d}
                </span>{" "}
                / 30g
              </span>
            </div>
            <div className="h-2 w-full rounded-full bg-slate-900/60">
              <div
                className="h-2 rounded-full bg-gradient-to-r from-sky-500 to-emerald-400"
                style={{ width: `${item.percentage}%` }}
              />
            </div>
          </div>
        ))}
        {total === 0 ? (
          <p className="text-xs text-slate-500">Veri bulunamadı.</p>
        ) : null}
      </div>
    </section>
  );
}

function TeacherStatus({ data }: { data: UserSegmentation["teacher_status"] }) {
  if (!data.length) {
    return (
      <section className="rounded-xl border border-slate-800/70 bg-slate-950/70 p-4 text-xs text-slate-500">
        Öğretmen kaydı bulunamadı.
      </section>
    );
  }

  return (
    <section className="space-y-4 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-center justify-between">
        <div>
          <p className="text-sm font-semibold text-slate-100">Öğretmen durumları</p>
          <p className="text-xs text-slate-400">
            Öğretmenlerin onay durumlarına göre dağılımı.
          </p>
        </div>
        <Badge variant="outline" className="border-emerald-500/40 text-emerald-200">
          Öğretmen segmentleri
        </Badge>
      </header>
      <div className="grid gap-3 md:grid-cols-3">
        {data.map((item) => (
          <article
            key={item.status}
            className="rounded-lg border border-slate-800/60 bg-slate-950/60 p-4 text-sm text-slate-200"
          >
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
              {translateTeacherStatus(item.status)}
            </p>
            <p className="mt-2 text-lg font-semibold text-slate-100">{formatNumber(item.count)}</p>
            <p className="text-xs text-slate-400">{item.percentage.toFixed(1)}%</p>
          </article>
        ))}
      </div>
    </section>
  );
}

function StudentActivity({
  data,
  total,
}: {
  data: UserSegmentation["student_activity"];
  total: number;
}) {
  return (
    <section className="space-y-4 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-center justify-between">
        <div>
          <p className="text-sm font-semibold text-slate-100">Öğrenci etkileşimi</p>
          <p className="text-xs text-slate-400">
            Rezervasyon sayılarına göre öğrenci segmentleri.
          </p>
        </div>
      </header>
      <div className="grid gap-3 md:grid-cols-2">
        {data.map((segment) => (
          <article
            key={segment.segment}
            className="rounded-lg border border-slate-800/60 bg-slate-950/60 p-4 text-sm text-slate-200"
          >
            <div className="flex items-center justify-between">
              <p className="font-semibold text-slate-100">{segment.label}</p>
              <Badge variant="secondary" className="bg-slate-900/60 text-xs text-slate-300">
                {segment.percentage.toFixed(1)}%
              </Badge>
            </div>
            <p className="mt-2 text-xs text-slate-400">
              {formatNumber(segment.count)} öğrenci •{" "}
              {total > 0 ? `${segment.percentage.toFixed(1)}%` : "0%"}
            </p>
          </article>
        ))}
      </div>
    </section>
  );
}

function RetentionBreakdown({ data }: { data: UserSegmentation["retention"] }) {
  return (
    <section className="space-y-4 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-center justify-between">
        <div>
          <p className="text-sm font-semibold text-slate-100">Aktivite & churn analizi</p>
          <p className="text-xs text-slate-400">
            Öğrenci ve öğretmenlerin son giriş tarihine göre segmentasyonu.
          </p>
        </div>
      </header>
      <div className="grid gap-3 md:grid-cols-2">
        <RetentionColumn title="Öğrenciler" segments={data.students} />
        <RetentionColumn title="Öğretmenler" segments={data.teachers} />
      </div>
    </section>
  );
}

function RetentionColumn({ title, segments }: { title: string; segments: RetentionSegment[] }) {
  return (
    <div className="space-y-3 rounded-lg border border-slate-800/60 bg-slate-950/60 p-4">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{title}</p>
      <div className="space-y-2">
        {segments.map((segment) => (
          <div key={segment.segment} className="flex items-center justify-between text-xs text-slate-300">
            <span>{segment.label}</span>
            <span className={segment.segment === "inactive_90" ? "text-rose-300" : "text-slate-200"}>
              {formatNumber(segment.count)} • {segment.percentage.toFixed(1)}%
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function MarketingPreferences({
  data,
  total,
}: {
  data: UserSegmentation["marketing"];
  total: number;
}) {
  return (
    <section className="space-y-3 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-center gap-2">
        <Bell className="h-4 w-4 text-sky-300" />
        <p className="text-sm font-semibold text-slate-100">Bildirim tercihleri</p>
      </header>
      <div className="flex flex-wrap gap-3 text-xs text-slate-300">
        {data.map((item) => (
          <Badge
            key={item.key}
            variant="outline"
            className="flex items-center gap-2 border-slate-700/60 bg-slate-900/60 px-3 py-1 text-slate-200"
          >
            {item.key === "email_notifications" ? (
              <Mail className="h-3 w-3" />
            ) : item.key === "push_notifications" ? (
              <Bell className="h-3 w-3" />
            ) : (
              <Target className="h-3 w-3" />
            )}
            <span>{item.label}</span>
            <span className="font-medium text-sky-300">{formatNumber(item.count)}</span>
            <span className="text-slate-400">
              ({total > 0 ? item.percentage.toFixed(1) : "0"}%)
            </span>
          </Badge>
        ))}
      </div>
    </section>
  );
}

function FocusMetrics({ data }: { data: UserSegmentation["focus"] }) {
  return (
    <section className="space-y-3 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-center gap-2">
        <Target className="h-4 w-4 text-emerald-300" />
        <p className="text-sm font-semibold text-slate-100">Odaklanılması gereken segmentler</p>
      </header>
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        {data.map((metric) => (
          <article
            key={metric.key}
            className="space-y-1 rounded-lg border border-slate-800/60 bg-slate-950/70 p-4 text-sm text-slate-200"
          >
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
              {metric.label}
            </p>
            <p className="text-lg font-semibold text-slate-100">{formatNumber(metric.value)}</p>
            {metric.description ? (
              <p className="text-xs text-slate-400">{metric.description}</p>
            ) : null}
          </article>
        ))}
      </div>
    </section>
  );
}

function CohortTable({ cohorts }: { cohorts: UserSegmentation["cohorts"] }) {
  return (
    <section className="space-y-3 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-center justify-between">
        <p className="text-sm font-semibold text-slate-100">Haftalık kayıt kohortları</p>
        <Badge variant="outline" className="border-slate-700/60 text-xs text-slate-300">
          Son 6 hafta
        </Badge>
      </header>
      <div className="overflow-x-auto">
        <table className="w-full table-fixed text-left text-xs text-slate-300">
          <thead>
            <tr className="text-slate-500">
              <th className="w-1/3 border-b border-slate-800/60 pb-2">Hafta</th>
              <th className="w-1/3 border-b border-slate-800/60 pb-2">Öğrenci</th>
              <th className="w-1/3 border-b border-slate-800/60 pb-2">Öğretmen</th>
            </tr>
          </thead>
          <tbody>
            {cohorts.map((cohort) => (
              <tr key={cohort.label} className="border-b border-slate-800/40 last:border-none">
                <td className="py-2 text-slate-200">{cohort.label}</td>
                <td className="py-2">{formatNumber(cohort.students)}</td>
                <td className="py-2">{formatNumber(cohort.teachers)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function TopCategories({ data }: { data: UserSegmentation["top_categories"] }) {
  return (
    <section className="space-y-3 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
      <header className="flex items-center justify-between">
        <p className="text-sm font-semibold text-slate-100">En popüler kategoriler</p>
        <Badge variant="secondary" className="bg-slate-900/70 text-xs text-slate-300">
          İlk 5
        </Badge>
      </header>
      {data.length === 0 ? (
        <p className="text-xs text-slate-500">Kategori verisi bulunamadı.</p>
      ) : (
        <div className="space-y-2 text-sm text-slate-200">
          {data.map((category, index) => (
            <div key={category.name} className="flex items-center justify-between">
              <span className="flex items-center gap-2">
                <span className="text-xs text-slate-500">{index + 1}.</span>
                {category.name}
              </span>
              <span className="text-xs text-slate-400">
                {formatNumber(category.count)} rezervasyon
              </span>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

function translateRole(role: string): string {
  switch (role) {
    case "teacher":
      return "Öğretmen";
    case "student":
      return "Öğrenci";
    case "admin":
      return "Admin";
    default:
      return role;
  }
}

function translateTeacherStatus(status: string): string {
  switch (status) {
    case "approved":
      return "Onaylandı";
    case "pending":
      return "Beklemede";
    case "rejected":
      return "Reddedildi";
    default:
      return ucfirst(status);
  }
}

function ucfirst(value: string): string {
  if (!value) {
    return "";
  }

  return value.charAt(0).toUpperCase() + value.slice(1);
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat("tr-TR").format(value);
}

function computePercentage(part: number, total: number): string {
  if (total <= 0) {
    return "0%";
  }

  return `${((part / total) * 100).toFixed(1)}%`;
}

