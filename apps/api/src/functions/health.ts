import { app, type HttpRequest, type HttpResponseInit, type InvocationContext } from "@azure/functions";
import type { HealthResponse } from "@setlist/shared";

export async function health(_request: HttpRequest, _context: InvocationContext): Promise<HttpResponseInit> {
  const body: HealthResponse = { status: "ok" };
  return { status: 200, jsonBody: body };
}

app.http("health", { methods: ["GET"], authLevel: "anonymous", route: "health", handler: health });
