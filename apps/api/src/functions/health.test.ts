import { HttpRequest, InvocationContext } from "@azure/functions";
import { describe, expect, it } from "vitest";
import { health } from "./health.js";

describe("GET /api/health", () => {
  it("responds 200 with status ok", async () => {
    const request = new HttpRequest({ method: "GET", url: "http://localhost:7071/api/health" });
    const response = await health(request, new InvocationContext());

    expect(response.status).toBe(200);
    expect(response.jsonBody).toEqual({ status: "ok" });
  });
});
