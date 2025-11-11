import { apiClient } from "@/lib/api/client";

export type GrowthDataPoint = {
  month: string;
  count: number;
};

export type ReservationTrendPoint = {
  date: string;
  count: number;
};

export type CategoryPopularityItem = {
  name: string;
  count: number;
};

export type TeacherPerformanceItem = {
  name: string;
  reservations_count: number;
  average_rating: number;
};

export type AdminAnalyticsResponse = {
  success: boolean;
  analytics: {
    user_growth: GrowthDataPoint[];
    reservation_trends: ReservationTrendPoint[];
    category_popularity: CategoryPopularityItem[];
    teacher_performance: TeacherPerformanceItem[];
  };
};

export async function fetchAdminAnalytics(): Promise<AdminAnalyticsResponse> {
  const { data } = await apiClient.get<AdminAnalyticsResponse>(
    "/admin/analytics",
  );

  return data;
}

export type RoleDistributionItem = {
  role: string;
  count: number;
  percentage: number;
  growth_30d: number;
};

export type TeacherStatusItem = {
  status: string;
  count: number;
  percentage: number;
};

export type StudentActivitySegment = {
  segment: string;
  label: string;
  count: number;
  percentage: number;
};

export type RetentionSegment = {
  segment: string;
  label: string;
  count: number;
  percentage: number;
};

export type MarketingPreference = {
  key: string;
  label: string;
  count: number;
  percentage: number;
};

export type CohortEntry = {
  label: string;
  students: number;
  teachers: number;
};

export type FocusMetric = {
  key: string;
  label: string;
  value: number;
  description?: string;
};

export type TopCategoryEntry = {
  name: string;
  count: number;
};

export type UserSegmentation = {
  totals: {
    total_users: number;
    students: number;
    teachers: number;
    admins: number;
    new_last_30_days: number;
    active_last_7_days: number;
  };
  role_distribution: RoleDistributionItem[];
  teacher_status: TeacherStatusItem[];
  student_activity: StudentActivitySegment[];
  retention: {
    students: RetentionSegment[];
    teachers: RetentionSegment[];
  };
  marketing: MarketingPreference[];
  cohorts: CohortEntry[];
  focus: FocusMetric[];
  top_categories: TopCategoryEntry[];
};

export type UserSegmentationResponse = {
  success: boolean;
  segmentation: UserSegmentation;
};

export async function fetchUserSegmentation(): Promise<UserSegmentationResponse> {
  const { data } = await apiClient.get<UserSegmentationResponse>(
    "/admin/analytics/user-segmentation",
  );

  return data;
}

export type TeacherLeader = {
  id: number;
  name: string;
  email: string;
  rating_avg: number;
  rating_count: number;
  average_rating_per_lesson: number | null;
  rated_lessons: number;
  total_lessons: number;
  lessons_last_30_days: number;
  lessons_last_90_days: number;
  activity_trend_30_vs_90: number | null;
  unique_students: number;
  total_revenue: number;
  average_revenue_per_lesson: number;
  first_reservation_at: string | null;
  last_reservation_at: string | null;
  active_days: number | null;
  lessons_per_active_day: number;
  cancellations: number;
  cancellation_rate: number;
  ranking_score: number;
};

export type TeacherBenchmarkDistributionItem = {
  bucket: string | number;
  count: number;
  percentage: number;
  label?: string;
};

export type TeacherBenchmarkResponse = {
  success: boolean;
  benchmark: {
    summary: {
      total_teachers: number;
      active_7_days: number;
      active_30_days: number;
      average_rating: number;
      average_lessons_per_teacher: number;
      average_revenue_per_teacher: number;
      total_revenue: number;
    };
    leaders: {
      top_performers: TeacherLeader[];
      emerging: TeacherLeader[];
      attention: TeacherLeader[];
    };
    distribution: {
      ratings: TeacherBenchmarkDistributionItem[];
      workload: TeacherBenchmarkDistributionItem[];
      activity: TeacherBenchmarkDistributionItem[];
    };
  };
};

export async function fetchTeacherBenchmark(): Promise<TeacherBenchmarkResponse> {
  const { data } = await apiClient.get<TeacherBenchmarkResponse>(
    "/admin/analytics/teacher-benchmark",
  );

  return data;
}

