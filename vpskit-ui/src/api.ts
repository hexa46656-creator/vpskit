export type HealthStatus = {
  status: string;
  environment: string;
};

export type RuntimeService = {
  name: string;
  state: string;
  detail: string;
};

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "";

async function fetchJson<T>(path: string): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`);

  if (!response.ok) {
    throw new Error(`Request failed with status ${response.status}`);
  }

  return response.json() as Promise<T>;
}

export async function fetchHealth(): Promise<HealthStatus> {
  return fetchJson<HealthStatus>("/health");
}

export async function fetchRuntimeServices(): Promise<RuntimeService[]> {
  return fetchJson<RuntimeService[]>("/runtime/services");
}
