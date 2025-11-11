import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { PendingTeacher } from "@/lib/api/admin";
import { formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";
import { useState } from "react";

type TeacherCardProps = {
  teacher: PendingTeacher;
  onApprove: (teacher: PendingTeacher, notes?: string) => Promise<void>;
  onReject: (teacher: PendingTeacher, reason: string) => Promise<void>;
  isProcessing?: boolean;
};

export function TeacherCard({
  teacher,
  onApprove,
  onReject,
  isProcessing,
}: TeacherCardProps) {
  const [rejectionReason, setRejectionReason] = useState("");

  return (
    <div className="group relative flex flex-col gap-5 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-5 shadow-[0_12px_40px_rgba(15,23,42,0.35)] transition-all hover:border-sky-500/40 hover:bg-slate-950/80">
      <div className="absolute inset-0 -z-10 overflow-hidden rounded-2xl opacity-0 blur-lg transition-opacity duration-300 group-hover:opacity-40">
        <div className="h-full w-full bg-sky-500/20" />
      </div>

      <header className="flex flex-col gap-2">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-slate-100">
            {teacher.name}
          </h3>
          <Badge variant="info">Başvuru</Badge>
        </div>
        <p className="text-sm text-slate-400">{teacher.email}</p>
        <p className="text-xs text-slate-500">
          Katılım tarihi: {formatRelative(teacher.created_at)}
        </p>
      </header>

      <section className="space-y-3 text-sm text-slate-300">
        {teacher.teacher?.bio && (
          <div>
            <p className="text-xs uppercase tracking-wide text-slate-500">
              Tanıtım
            </p>
            <p className="mt-1 leading-relaxed text-slate-200">
              {teacher.teacher.bio}
            </p>
          </div>
        )}

        <div className="grid gap-3 md:grid-cols-2">
          {teacher.teacher?.specialization && (
            <InfoBlock title="Uzmanlık">
              {teacher.teacher.specialization}
            </InfoBlock>
          )}
          {teacher.teacher?.experience_years !== undefined && (
            <InfoBlock title="Tecrübe">
              {teacher.teacher.experience_years
                ? `${teacher.teacher.experience_years} yıl`
                : "Belirtilmemiş"}
            </InfoBlock>
          )}
        </div>

        {!!teacher.teacher?.certifications?.length && (
          <div>
            <p className="text-xs uppercase tracking-wide text-slate-500">
              Sertifikalar
            </p>
            <ul className="mt-2 space-y-1.5 text-xs text-slate-300">
              {teacher.teacher.certifications.map((cert) => (
                <li
                  key={cert.id}
                  className="flex items-center justify-between rounded-lg border border-slate-800/60 bg-slate-950/60 px-3 py-2"
                >
                  <span>{cert.name}</span>
                  <span className="text-[11px] text-slate-500">
                    {cert.institution ?? "—"}{" "}
                    {cert.year ? `• ${cert.year}` : ""}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>

      <footer className="flex flex-col gap-3 border-t border-slate-800/60 pt-4 md:flex-row md:items-center md:justify-between">
        <div className="flex flex-1 gap-2">
          <textarea
            className="h-20 flex-1 rounded-xl border border-slate-800/60 bg-slate-950/80 px-3 py-2 text-xs text-slate-300 transition-colors placeholder:text-slate-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-500/60"
            placeholder="Reddetme nedeni (opsiyonel, onay için boş bırakılabilir)"
            value={rejectionReason}
            onChange={(event) => setRejectionReason(event.target.value)}
          />
        </div>
        <div className="flex flex-col gap-2 md:flex-row">
          <Button
            variant="ghost"
            className="border border-slate-800/60 text-slate-300 hover:bg-slate-900/70"
            disabled={isProcessing}
            onClick={() => setRejectionReason("")}
          >
            Notları temizle
          </Button>
          <Button
            variant="ghost"
            className="border border-emerald-500/30 bg-emerald-500/10 text-emerald-200 hover:bg-emerald-500/20"
            disabled={isProcessing}
            onClick={() => onApprove(teacher).then(() => setRejectionReason(""))}
          >
            Onayla
          </Button>
          <Button
            variant="destructive"
            disabled={isProcessing || !rejectionReason.trim()}
            onClick={async () => {
              const reason = rejectionReason.trim();
              if (!reason) return;
              await onReject(teacher, reason);
              setRejectionReason("");
            }}
          >
            Reddet
          </Button>
        </div>
      </footer>
    </div>
  );
}

function InfoBlock({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border border-slate-800/60 bg-slate-950/70 p-3">
      <p className="text-[11px] uppercase tracking-wide text-slate-500">
        {title}
      </p>
      <p className="mt-1 text-xs text-slate-200">{children}</p>
    </div>
  );
}

function formatRelative(date: string) {
  try {
    return formatDistanceToNow(new Date(date), {
      addSuffix: true,
      locale: tr,
    });
  } catch {
    return "-";
  }
}

