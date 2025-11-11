import { apiClient } from "@/lib/api/client";

export type ExperimentVariant = {
  id: number;
  name: string;
  key: string;
  is_control: boolean;
  traffic_allocation: number;
  assignments: number;
  conversions: number;
  conversion_rate: number;
  conversion_value: number;
};

export type ExperimentMetrics = {
  assignments: number;
  conversions: number;
  conversion_rate: number;
  conversion_value: number;
};

export type Experiment = {
  id: number;
  name: string;
  key: string;
  status: "draft" | "running" | "paused" | "completed";
  type: string;
  traffic_allocation: number;
  starts_at?: string | null;
  ends_at?: string | null;
  hypothesis?: string | null;
  success_metric?: string | null;
  variants: ExperimentVariant[];
  metrics: ExperimentMetrics;
};

export type ExperimentsResponse = {
  success: boolean;
  experiments: Experiment[];
};

export type ExperimentPayload = {
  name: string;
  key: string;
  type?: string;
  status?: "draft" | "running" | "paused" | "completed";
  traffic_allocation?: number;
  hypothesis?: string;
  success_metric?: string;
  target_filters?: Record<string, unknown>;
  starts_at?: string | null;
  ends_at?: string | null;
  variants: Array<{
    name: string;
    key: string;
    is_control?: boolean;
    traffic_allocation?: number;
  }>;
};

export async function fetchExperiments(): Promise<ExperimentsResponse> {
  const { data } = await apiClient.get<ExperimentsResponse>("/admin/experiments");
  return data;
}

export async function createExperiment(payload: ExperimentPayload): Promise<{ success: boolean; experiment: Experiment }> {
  const { data } = await apiClient.post<{ success: boolean; experiment: Experiment }>(
    "/admin/experiments",
    payload,
  );
  return data;
}

export async function updateExperiment(experimentId: number, payload: Partial<ExperimentPayload>): Promise<{ success: boolean; experiment: Experiment }> {
  const { data } = await apiClient.put<{ success: boolean; experiment: Experiment }>(
    `/admin/experiments/${experimentId}`,
    payload,
  );
  return data;
}

export async function updateExperimentStatus(
  experimentId: number,
  status: "draft" | "running" | "paused" | "completed",
): Promise<{ success: boolean; experiment: Experiment }> {
  const { data } = await apiClient.post<{ success: boolean; experiment: Experiment }>(
    `/admin/experiments/${experimentId}/status`,
    { status },
  );
  return data;
}

export type VariantPayload = {
  name: string;
  key: string;
  is_control?: boolean;
  traffic_allocation?: number;
};

export async function createVariant(
  experimentId: number,
  payload: VariantPayload,
): Promise<{ success: boolean; variant: ExperimentVariant }> {
  const { data } = await apiClient.post<{ success: boolean; variant: ExperimentVariant }>(
    `/admin/experiments/${experimentId}/variants`,
    payload,
  );
  return data;
}

export async function updateVariant(
  experimentId: number,
  variantId: number,
  payload: Partial<VariantPayload>,
): Promise<{ success: boolean; variant: ExperimentVariant }> {
  const { data } = await apiClient.put<{ success: boolean; variant: ExperimentVariant }>(
    `/admin/experiments/${experimentId}/variants/${variantId}`,
    payload,
  );
  return data;
}

export async function deleteVariant(experimentId: number, variantId: number): Promise<{ success: boolean }> {
  const { data } = await apiClient.delete<{ success: boolean }>(
    `/admin/experiments/${experimentId}/variants/${variantId}`,
  );
  return data;
}

