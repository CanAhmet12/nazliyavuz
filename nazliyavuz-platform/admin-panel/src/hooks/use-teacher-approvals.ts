import { useQuery } from "@tanstack/react-query";
import {
  fetchPendingTeachers,
  type PendingTeacherResponse,
} from "@/lib/api/admin";

const TEACHER_APPROVALS_KEY = ["admin", "teachers", "pending"];

export function useTeacherApprovals() {
  return useQuery<PendingTeacherResponse>({
    queryKey: TEACHER_APPROVALS_KEY,
    queryFn: fetchPendingTeachers,
    refetchInterval: 30 * 1000,
  });
}

