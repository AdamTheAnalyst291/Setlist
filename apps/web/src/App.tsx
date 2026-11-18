import { useEffect, useState } from "react";
import { checkApiHealth, loadConfig, type ApiHealth } from "./health.js";

export function App() {
  const [health, setHealth] = useState<ApiHealth | "checking">("checking");

  useEffect(() => {
    let cancelled = false;
    loadConfig()
      .then((config) => checkApiHealth(config.apiUrl))
      .catch((error: unknown): ApiHealth => ({
        state: "down",
        reason: error instanceof Error ? error.message : "Could not load configuration",
      }))
      .then((result) => {
        if (!cancelled) setHealth(result);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <main>
      <h1>Crowd Setlists</h1>
      <p role="status" data-testid="api-health">
        {health === "checking" && "API: checking…"}
        {health !== "checking" && health.state === "ok" && "API: ok"}
        {health !== "checking" && health.state === "down" && `API: down (${health.reason})`}
      </p>
    </main>
  );
}
