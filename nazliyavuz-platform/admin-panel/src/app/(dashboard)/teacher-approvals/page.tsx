"use client";

import { useTeacherApprovals } from "@/hooks/use-teacher-approvals";
import { useMutationToast } from "@/hooks/use-mutation-toast";
import {
  approveTeacher,
  rejectTeacher,
  type PendingTeacher,
} from "@/lib/api/admin";
import { TeacherCard } from "@/components/admin/teacher-approvals/teacher-card";
import { EmptyState } from "@/components/admin/teacher-approvals/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { AlertCircle } from "lucide-react";
import { usersQueryKey } from "@/hooks/use-admin-users";
import { useQueryClient } from "@tanstack/react-query";

export default function TeacherApprovalsPage() {
  const queryClient = useQueryClient();
  const {
    data,
    isLoading,
    isFetching,
    error,
    refetch: refetchPendingTeachers,
  } = useTeacherApprovals();

  const approveMutation = useMutationToast(approveTeacher, {
    successMessage: "Öğretmen başarıyla onaylandı.",
    onSuccess: async () => {
      await refetchPendingTeachers();
      void queryClient.invalidateQueries({ queryKey: usersQueryKey });
    },
  });

  const rejectMutation = useMutationToast(rejectTeacher, {
    successMessage: "Öğretmen başvurusu reddedildi.",
    onSuccess: async () => {
      await refetchPendingTeachers();
      void queryClient.invalidateQueries({ queryKey: usersQueryKey });
    },
  });

  const pendingTeachers = data?.pending_teachers ?? [];

  const handleApprove = async (teacher: PendingTeacher) => {
    await approveMutation.mutateAsync({ userId: teacher.id });
  };

  const handleReject = async (teacher: PendingTeacher, reason: string) => {
    await rejectMutation.mutateAsync({ userId: teacher.id, reason });
  };

  return (
    <div className="space-y-4 md:space-y-6">
      <header className="flex flex-col gap-3 rounded-xl border border-slate-800/80 bg-slate-950/60 p-4 md:rounded-2xl md:gap-4 md:p-5 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h2 className="text-base font-semibold text-slate-100 md:text-lg">
            Öğretmen Onay Süreci
          </h2>
          <p className="mt-1 text-xs text-slate-400 md:text-sm">
            Bekleyen öğretmen başvurularını inceleyip karar verin.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant="info" className="text-xs md:text-sm">
            {pendingTeachers.length} bekleyen başvuru
          </Badge>
          <Button
            variant="outline"
            size="sm"
            className="min-h-[36px] border-slate-800 bg-slate-950 text-slate-300 active:scale-[0.98] hover:bg-slate-900/80 md:min-h-0"
            onClick={() => refetchPendingTeachers()}
            disabled={isFetching}
          >
            Listeyi yenile
          </Button>
        </div>
      </header>

      {error && (
        <div className="flex items-center gap-2 rounded-xl border border-rose-500/40 bg-rose-500/10 px-3 py-2.5 text-xs text-rose-200 md:gap-3 md:px-4 md:py-3 md:text-sm">
          <AlertCircle className="h-3.5 w-3.5 shrink-0 md:h-4 md:w-4" />
          <span>Öğretmen başvuruları yüklenirken bir hata oluştu. Lütfen tekrar deneyin.</span>
        </div>
      )}

      {isLoading ? (
        <TeacherApprovalsSkeleton />
      ) : pendingTeachers.length === 0 ? (
        <EmptyState
          onRefresh={() => refetchPendingTeachers()}
          isLoading={isFetching}
        />
      ) : (
        <div className="grid gap-3 md:gap-5 md:grid-cols-2">
          {pendingTeachers.map((teacher) => (
            <TeacherCard
              key={teacher.id}
              teacher={teacher}
              onApprove={handleApprove}
              onReject={handleReject}
              isProcessing={
                approveMutation.isPending || rejectMutation.isPending
              }
            />
          ))}
        </div>
      )}
    </div>
  );
}

function TeacherApprovalsSkeleton() {
  return (
    <div className="grid gap-5 md:grid-cols-2">
      {Array.from({ length: 4 }).map((_, index) => (
        <div
          key={index}
          className="rounded-2xl border border-slate-800/60 bg-slate-950/60 p-5"
        >
          <Skeleton className="h-5 w-40" />
          <Skeleton className="mt-2 h-4 w-32" />
          <Skeleton className="mt-2 h-3 w-24" />
          <Skeleton className="mt-4 h-16 w-full" />
          <div className="mt-6 flex gap-2">
            <Skeleton className="h-10 flex-1" />
            <Skeleton className="h-10 flex-1" />
            <Skeleton className="h-10 flex-1" />
          </div>
        </div>
      ))}
    </div>
  );
}

