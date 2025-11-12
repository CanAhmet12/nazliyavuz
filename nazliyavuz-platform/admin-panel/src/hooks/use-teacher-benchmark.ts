import { useQuery } from "@tanstack/react-query";
import {
  fetchTeacherBenchmark,
  type TeacherBenchmarkResponse,
} from "@/lib/api/analytics";
import { useAuthQueryEnabled } from "@/hooks/use-auth-query-enabled";

export const teacherBenchmarkQueryKey = ["admin", "analytics", "teacher-benchmark"];

export function useTeacherBenchmark() {
  const isEnabled = useAuthQueryEnabled();

  return useQuery<TeacherBenchmarkResponse>({
    queryKey: teacherBenchmarkQueryKey,
    queryFn: fetchTeacherBenchmark,
    staleTime: 60 * 1000,
    enabled: isEnabled,
  });
}

