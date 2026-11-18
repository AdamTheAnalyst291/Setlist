import type { HealthResponse } from "@setlist/shared";

type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

export interface AppConfig {
  apiUrl: string;
}

export type ApiHealth = { state: "ok" } | { state: "down"; reason: string };

/**
 * The API's address is not baked into the build: the same build is promoted from Dev to UAT
 * to Prod, so each deploy writes its own /config.json next to the app.
 */
export async function loadConfig(fetchFn: Fetch = fetch): Promise<AppConfig> {
  const response = await fetchFn("/config.json", { cache: "no-store" });
  if (!response.ok) throw new Error(`Could not load /config.json (HTTP ${response.status})`);
  const body = (await response.json()) as Partial<AppConfig>;
  if (typeof body.apiUrl !== "string" || body.apiUrl === "") throw new Error("/config.json has no apiUrl");
  return { apiUrl: body.apiUrl.replace(/\/+$/, "") };
}

export async function checkApiHealth(apiUrl: string, fetchFn: Fetch = fetch): Promise<ApiHealth> {
  try {
    const response = await fetchFn(`${apiUrl}/api/health`);
    if (!response.ok) return { state: "down", reason: `HTTP ${response.status}` };
    const body = (await response.json()) as Partial<HealthResponse>;
    return body.status === "ok" ? { state: "ok" } : { state: "down", reason: "Unexpected response" };
  } catch (error) {
    return { state: "down", reason: error instanceof Error ? error.message : "Request failed" };
  }
}
