/** Shared form rules. User prose remains text; escaping belongs at each output. */
export function textInput(value: string, max: number, multiline = false) {
  return value.normalize("NFC").replace(multiline ? /[\u0000-\u0008\u000b-\u001f\u007f\u202a-\u202e\u2066-\u2069]/g : /[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]/g, "").slice(0, max);
}

export function emailAddress(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 254) return null;
  const email = value.trim().toLowerCase();
  const parts = email.split("@");
  if (parts.length !== 2) return null;
  const [local, domain] = parts;
  if (!local || local.length > 64 || local.startsWith(".") || local.endsWith(".") || local.includes("..") ||
      !/^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+$/.test(local)) return null;
  const labels = domain.split(".");
  if (labels.length < 2 || domain.length > 253 || labels.some(label => !/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(label))) return null;
  return email;
}

export function record(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value) && Object.getPrototypeOf(value) === Object.prototype;
}

export function onlyKeys(value: Record<string, unknown>, keys: readonly string[]) {
  return Object.keys(value).every(key => keys.includes(key));
}

export function giftId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{8,24}$/.test(value);
}
