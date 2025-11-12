import { useQuery } from "@tanstack/react-query";
import {
  fetchPendingTeachers,
  type PendingTeacherResponse,
} from "@/lib/api/admin";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

const TEACHER_APPROVALS_KEY = ["admin", "teachers", "pending"];

export function useTeacherApprovals() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<PendingTeacherResponse>({
    queryKey: TEACHER_APPROVALS_KEY,
    queryFn: fetchPendingTeachers,
    refetchInterval: 30 * 1000,
    enabled: isEnabled,
  });
}

