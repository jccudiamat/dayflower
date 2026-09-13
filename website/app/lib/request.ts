import { record } from "./input";

export class InputError extends Error {
  constructor(message: string, public status = 400) { super(message); }
}

export function checkRequest(request: Request) {
  const allowed = new Set(["https://mydayflower.com", "https://www.mydayflower.com"]);
  if (process.env.VERCEL_URL) allowed.add(`https://${process.env.VERCEL_URL}`);
  if (process.env.NODE_ENV !== "production") allowed.add(new URL(request.url).origin);
  const origin = request.headers.get("origin");
  if ((origin && !allowed.has(origin)) || request.headers.get("sec-fetch-site") === "cross-site") {
    throw new InputError("This request must come from Dayflower.", 403);
  }
  if (!/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(request.headers.get("content-type") ?? "")) {
    throw new InputError("Send a JSON request.", 415);
  }
  if (!/^(?:identity)?$/i.test(request.headers.get("content-encoding") ?? "")) {
    throw new InputError("Compressed requests are not supported.", 415);
  }
}

/** Enforce a byte ceiling while streaming, even without Content-Length. */
export async function readJson(request: Request, maxBytes: number, timeoutMs = 5000): Promise<Record<string, unknown>> {
  const declared = request.headers.get("content-length");
  if (declared !== null && (!/^\d+$/.test(declared) || Number(declared) > maxBytes)) throw new InputError("This request is too large.", 413);
  if (!request.body) throw new InputError("Invalid request.");
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new InputError("The upload took too long.", 408)), timeoutMs); });
  try {
    while (true) {
      const { done, value } = await Promise.race([reader.read(), timeout]);
      if (done) break;
      length += value.byteLength;
      if (length > maxBytes) throw new InputError("This request is too large.", 413);
      chunks.push(value);
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    // Bound nesting before JSON.parse to reject pathological object graphs.
    let depth = 0, quoted = false, escaped = false;
    for (const c of text) {
      if (quoted) { if (escaped) escaped = false; else if (c === "\\") escaped = true; else if (c === '"') quoted = false; }
      else if (c === '"') quoted = true;
      else if (c === "{" || c === "[") { if (++depth > 12) throw new InputError("The request is too complex."); }
      else if (c === "}" || c === "]") depth--;
    }
    const value: unknown = JSON.parse(text);
    if (!record(value)) throw new InputError("Send a JSON object.");
    return value;
  } catch (error) {
    void reader.cancel().catch(() => {});
    if (error instanceof InputError) throw error;
    throw new InputError("Invalid request.");
  } finally { clearTimeout(timer); }
}

export function failure(error: unknown) {
  return Response.json({ error: error instanceof InputError ? error.message : "This service is temporarily unavailable. Please try again later." }, {
    status: error instanceof InputError ? error.status : 503,
    headers: { "Cache-Control": "no-store", ...(error instanceof InputError && error.status === 429 ? { "Retry-After": "3600" } : {}) },
  });
}
