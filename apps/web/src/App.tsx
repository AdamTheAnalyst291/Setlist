import type { HealthResponse } from "@setlist/shared";

const placeholder: HealthResponse = { status: "ok" };

export function App() {
  return <h1>Crowd Setlists ({placeholder.status})</h1>;
}
