"use client";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import type { AdminUser } from "@/lib/api/admin";
import { formatDistanceToNow } from "date-fns";
import { tr } from "date-fns/locale";
import { useState } from "react";

type UserDetailDrawerProps = {
  user: AdminUser | null;
  open: boolean;
  onClose: () => void;
  onSuspend: (reason: string) => Promise<void>;
  onUnsuspend: () => Promise<void>;
  isProcessing?: boolean;
};

export function UserDetailDrawer({
  user,
  open,
  onClose,
  onSuspend,
  onUnsuspend,
  isProcessing,
}: UserDetailDrawerProps) {
  const [reason, setReason] = useState("");

  if (!user) {
    return null;
  }

  const isSuspended = user.status === "suspended";

  const handleSuspend = async () => {
    if (!reason.trim()) {
      return;
    }
    await onSuspend(reason.trim());
    setReason("");
  };

  return (
    <Dialog open={open} onOpenChange={(value) => !value && onClose()}>
      <DialogContent className="top-0 right-0 h-screen max-w-md translate-x-1/2 translate-y-0 rounded-none border-l border-slate-800/80 bg-slate-950/95 p-0 sm:max-w-md">
        <div className="flex h-full flex-col">
          <DialogHeader className="border-b border-slate-800/70 px-6 py-4">
            <DialogTitle>Kullanıcı Detayı</DialogTitle>
            <DialogDescription>
              Hesap bilgileri ve yönetim aksiyonları
            </DialogDescription>
          </DialogHeader>

          <div className="flex-1 overflow-y-auto px-6 py-5 space-y-6">
            <section className="space-y-2">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold text-slate-100">
                  {user.name}
                </h3>
                <Badge variant={roleVariant[user.role]}>
                  {roleCopy[user.role]}
                </Badge>
              </div>
              <p className="text-sm text-slate-400">{user.email}</p>
              <div className="flex flex-wrap gap-2">
                <Badge variant={statusVariant[user.status ?? "active"]}>
                  {statusCopy[user.status ?? "active"]}
                </Badge>
                {user.role === "teacher" && user.teacher_status && (
                  <Badge variant={teacherStatusVariant[user.teacher_status]}>
                    {teacherStatusCopy[user.teacher_status]}
                  </Badge>
                )}
              </div>
            </section>

            <section className="space-y-3 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4 text-sm text-slate-200">
              <InfoRow label="Hesap oluşturma">
                {formatDate(user.created_at)}
              </InfoRow>
              <InfoRow label="Son giriş">
                {user.last_login_at
                  ? formatDate(user.last_login_at)
                  : "Henüz giriş yapmadı"}
              </InfoRow>
              <InfoRow label="Rol">
                {roleCopy[user.role]}
              </InfoRow>
              <InfoRow label="Durum">
                {statusCopy[user.status ?? "active"]}
              </InfoRow>
            </section>

            <section className="space-y-3">
              <h4 className="text-sm font-semibold text-slate-200">
                Yönetim aksiyonları
              </h4>
              {isSuspended ? (
                <div className="space-y-2 rounded-xl border border-emerald-500/40 bg-emerald-500/10 p-4">
                  <p className="text-xs text-slate-300">
                    Kullanıcı askıya alınmış. Askıdan kaldırmak için aşağıdaki
                    butonu kullanın.
                  </p>
                  <Button
                    variant="ghost"
                    className="border border-emerald-500/40 bg-emerald-500/10 text-emerald-200 hover:bg-emerald-500/20"
                    onClick={() => onUnsuspend()}
                    disabled={isProcessing}
                  >
                    Askıdan kaldır
                  </Button>
                </div>
              ) : (
                <div className="space-y-3 rounded-xl border border-slate-800/70 bg-slate-950/70 p-4">
                  <p className="text-xs text-slate-400">
                    Askıya almak için gerekçeyi paylaşın. Kullanıcıya bilgilendirme
                    e-postası gönderilir.
                  </p>
                  <textarea
                    className="h-24 w-full rounded-lg border border-slate-800/60 bg-slate-950/80 px-3 py-2 text-xs text-slate-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-500/60"
                    placeholder="Örn: Şüpheli hareketler nedeniyle 30 gün askıya alındı."
                    value={reason}
                    onChange={(event) => setReason(event.target.value)}
                  />
                  <Button
                    variant="destructive"
                    onClick={handleSuspend}
                    disabled={isProcessing || !reason.trim()}
                  >
                    Kullanıcıyı askıya al
                  </Button>
                </div>
              )}
            </section>
          </div>

          <div className="border-t border-slate-800/70 px-6 py-3 text-right">
            <Button variant="ghost" className="text-slate-400" onClick={onClose}>
              Kapat
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

function InfoRow({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between text-xs">
      <span className="text-slate-500">{label}</span>
      <span className="font-medium text-slate-200">{children}</span>
    </div>
  );
}

const roleVariant: Record<AdminUser["role"], "info" | "default" | "success"> = {
  admin: "info",
  teacher: "success",
  student: "default",
};

const roleCopy: Record<AdminUser["role"], string> = {
  admin: "Yönetici",
  teacher: "Öğretmen",
  student: "Öğrenci",
};

const statusVariant: Record<string, "success" | "warning" | "destructive"> = {
  active: "success",
  suspended: "destructive",
  pending: "warning",
};

const statusCopy: Record<string, string> = {
  active: "Aktif",
  suspended: "Askıda",
  pending: "Beklemede",
};

const teacherStatusVariant: Record<
  NonNullable<AdminUser["teacher_status"]>,
  "info" | "success" | "destructive"
> = {
  pending: "info",
  approved: "success",
  rejected: "destructive",
};

const teacherStatusCopy: Record<
  NonNullable<AdminUser["teacher_status"]>,
  string
> = {
  pending: "Onay bekliyor",
  approved: "Onaylandı",
  rejected: "Reddedildi",
};

function formatDate(date: string) {
  try {
    return formatDistanceToNow(new Date(date), {
      addSuffix: true,
      locale: tr,
    });
  } catch {
    return "-";
  }
}

