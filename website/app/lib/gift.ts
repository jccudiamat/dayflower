import { validateBouquet, type Bouquet } from "../bouquet/model";
import { giftId } from "./input";

/**
 * Server-side storage for shareable gift links.
 *
 * The `#gift=` link stores nothing and never will — it stays the private
 * option. But a URL fragment is never sent to the server, so a link preview
 * (which is a crawler fetching the URL) can only ever see the generic page.
 * Per-gift previews need the bouquet server-readable, which means a row.
 *
 * Database reads and writes are server-only. Public roles cannot scan this
 * table. Every server read must use an exact ID and an explicit expiry check.
 */

/** Comfortably above a full eight-photo bouquet, below the table's check constraint. */
export const MAX_GIFT_BYTES = 1_800_000;

const ID_BYTES = 16; // 128-bit bearer links; legacy 12-character IDs still load.

function env() {
  const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  return url && key ? { url, key } : null;
}

export function newGiftId() {
  const bytes = crypto.getRandomValues(new Uint8Array(ID_BYTES));
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

/** Stores a bouquet and answers with its id, or null if it could not be saved. */
export async function saveGift(bouquet: Bouquet): Promise<string | null> {
  const config = env();
  if (!config) {
    console.error("Gift: server storage is not configured.");
    return null;
  }
  const id = newGiftId();
  try {
    const res = await fetch(`${config.url}/rest/v1/bouquet_gifts`, {
      method: "POST",
      headers: {
        apikey: config.key,
        Authorization: `Bearer ${config.key}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({ id, payload: bouquet }),
      signal: AbortSignal.timeout(15_000),
    });
    if (res.ok) return id;
    console.error("Gift: insert rejected.", res.status);
  } catch {
    console.error("Gift: could not reach storage.");
  }
  return null;
}

/**
 * Reads a gift back. Runs the stored payload through `validateBouquet` again
 * rather than trusting it, including rows created before storage was private.
 */
export async function loadGift(id: string): Promise<Bouquet | null> {
  const config = env();
  if (!config || !giftId(id)) return null;
  try {
    const res = await fetch(`${config.url}/rest/v1/bouquet_gifts?id=eq.${encodeURIComponent(id)}&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&select=payload&limit=1`, {
      headers: { apikey: config.key, Authorization: `Bearer ${config.key}` },
      signal: AbortSignal.timeout(15_000),
      cache: "no-store",
    });
    if (!res.ok) return null;
    const rows = await res.json();
    return Array.isArray(rows) && rows.length ? validateBouquet(rows[0]?.payload) : null;
  } catch {
    return null;
  }
}
