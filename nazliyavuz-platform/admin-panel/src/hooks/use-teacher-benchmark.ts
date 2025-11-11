import { useQuery } from "@tanstack/react-query";
import {
  fetchTeacherBenchmark,
  type TeacherBenchmarkResponse,
} from "@/lib/api/analytics";

export const teacherBenchmarkQueryKey = ["admin", "analytics", "teacher-benchmark"];

export function useTeacherBenchmark() {
  return useQuery<TeacherBenchmarkResponse>({
    queryKey: teacherBenchmarkQueryKey,
    queryFn: fetchTeacherBenchmark,
    staleTime: 60 * 1000,
  });
}

