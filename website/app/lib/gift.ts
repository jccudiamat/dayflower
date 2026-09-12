import { validateBouquet, type Bouquet } from "../bouquet/model";

/**
 * Server-side storage for shareable gift links.
 *
 * The `#gift=` link stores nothing and never will — it stays the private
 * option. But a URL fragment is never sent to the server, so a link preview
 * (which is a crawler fetching the URL) can only ever see the generic page.
 * Per-gift previews need the bouquet server-readable, which means a row.
 *
 * Reads and writes go through PostgREST with the anon key, the same way the
 * waitlist does. RLS is the real gate: insert is open, select is by id and
 * only while the row lives, and nothing may update or delete.
 */

/** Comfortably above a full eight-photo bouquet, below the table's check constraint. */
export const MAX_GIFT_BYTES = 1_800_000;

const ID_BYTES = 9; // 12 base64url characters

function env() {
  const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_ANON_KEY;
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
    console.error("Gift: SUPABASE_URL / SUPABASE_ANON_KEY are not set.");
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
    console.error("Gift: insert rejected.", res.status, await res.text().catch(() => "<unreadable>"));
  } catch (cause) {
    console.error("Gift: could not reach Supabase.", cause);
  }
  return null;
}

/**
 * Reads a gift back. Runs the stored payload through `validateBouquet` again
 * rather than trusting it: the row is public-writable by design, so this is
 * the same gate a pasted `#gift=` payload goes through.
 */
export async function loadGift(id: string): Promise<Bouquet | null> {
  const config = env();
  if (!config || !/^[A-Za-z0-9_-]{8,24}$/.test(id)) return null;
  try {
    const res = await fetch(`${config.url}/rest/v1/bouquet_gifts?id=eq.${encodeURIComponent(id)}&select=payload`, {
      headers: { apikey: config.key, Authorization: `Bearer ${config.key}` },
      signal: AbortSignal.timeout(15_000),
      // A gift never changes, but an expired one must stop resolving, so this
      // is cached for a while rather than forever.
      next: { revalidate: 300 },
    });
    if (!res.ok) return null;
    const rows = await res.json();
    return Array.isArray(rows) && rows.length ? validateBouquet(rows[0]?.payload) : null;
  } catch {
    return null;
  }
}
