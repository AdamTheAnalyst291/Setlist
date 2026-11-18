import { describe, expect, it, vi } from "vitest";
import { checkApiHealth, loadConfig } from "./health.js";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

describe("loadConfig", () => {
  it("reads the API URL from /config.json and drops a trailing slash", async () => {
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({ apiUrl: "https://api.example.net/" }));

    await expect(loadConfig(fetchFn)).resolves.toEqual({ apiUrl: "https://api.example.net" });
    expect(fetchFn).toHaveBeenCalledWith("/config.json", { cache: "no-store" });
  });

  it("throws when the file is missing", async () => {
    const fetchFn = vi.fn().mockResolvedValue(new Response("nope", { status: 404 }));

    await expect(loadConfig(fetchFn)).rejects.toThrow(/config\.json/);
  });

  it("throws when apiUrl is absent", async () => {
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({}));

    await expect(loadConfig(fetchFn)).rejects.toThrow(/apiUrl/);
  });
});

describe("checkApiHealth", () => {
  it("reports ok when the API answers status ok", async () => {
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({ status: "ok" }));

    await expect(checkApiHealth("https://api.example.net", fetchFn)).resolves.toEqual({ state: "ok" });
    expect(fetchFn).toHaveBeenCalledWith("https://api.example.net/api/health");
  });

  it("reports down with the HTTP status when the API fails", async () => {
    const fetchFn = vi.fn().mockResolvedValue(new Response("boom", { status: 503 }));

    await expect(checkApiHealth("https://api.example.net", fetchFn)).resolves.toEqual({
      state: "down",
      reason: "HTTP 503",
    });
  });

  it("reports down when the request cannot be made", async () => {
    const fetchFn = vi.fn().mockRejectedValue(new TypeError("Failed to fetch"));

    await expect(checkApiHealth("https://api.example.net", fetchFn)).resolves.toEqual({
      state: "down",
      reason: "Failed to fetch",
    });
  });

  it("reports down when the body is not the expected shape", async () => {
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({ status: "degraded" }));

    await expect(checkApiHealth("https://api.example.net", fetchFn)).resolves.toEqual({
      state: "down",
      reason: "Unexpected response",
    });
  });
});
