// Dayflower — where two phones should try to reach each other.
//
// Deploy:  dart run tool/deploy_function.dart turn --verify-jwt
//
// 🔴 `--verify-jwt`, unlike `push`. The caller here is a signed-in phone, not
// a Postgres trigger, so Supabase checking the user's token *is* the access
// control: without it, anyone who learned the URL could mint relay
// credentials on this account's bill.
//
// Env it needs (npx supabase secrets set KEY=value, or the dashboard):
//
//   Cloudflare (what this is built for):
//     CF_TURN_KEY_ID      the TURN key's id
//     CF_TURN_API_TOKEN   its API token
//
//   A self-hosted coturn instead, if the bill ever argues for one:
//     TURN_URLS           comma-separated, turn:host:3478?transport=udp,…
//     TURN_SECRET         coturn's static-auth-secret
//
// Neither set is required. With none, this returns STUN only — most calls
// still connect, and `has_relay: false` tells the app to say the network
// refused rather than blaming itself.
//
// ## Why this is a function and not SQL
//
// Every other secret in this project is handed out from Postgres (see
// `livekit_token`, migration 0026). Cloudflare's credentials cannot be:
// they come from an HTTP call to Cloudflare, and Postgres only has `pg_net`,
// which is queued and asynchronous — it cannot answer a request that is
// waiting. The coturn path below *could* live in SQL, and deliberately does
// not: two implementations of "where do we relay" is how they drift.

/// STUN costs nothing, carries no media and no identity: it only answers
/// "what does my address look like from out here". Cloudflare's is free and
/// unmetered; Google's is the second opinion so one being down is not a
/// failed call.
const STUN = [
  { urls: "stun:stun.cloudflare.com:3478" },
  { urls: "stun:stun.l.google.com:19302" },
];

/// Long enough to outlast any real call, short enough that a credential
/// lifted off a phone is worthless by tomorrow.
const TTL_SECONDS = 6 * 60 * 60;

interface IceServer {
  urls: string | string[];
  username?: string;
  credential?: string;
}

async function cloudflare(): Promise<IceServer[] | null> {
  const keyId = Deno.env.get("CF_TURN_KEY_ID");
  const token = Deno.env.get("CF_TURN_API_TOKEN");
  if (!keyId || !token) return null;

  const res = await fetch(
    `https://rtc.live.cloudflare.com/v1/turn/keys/${keyId}/credentials/generate-ice-servers`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ ttl: TTL_SECONDS }),
    },
  );
  if (!res.ok) {
    // Logged rather than thrown: a call with STUN alone still connects for
    // most people, which is a better failure than refusing to dial.
    console.error(`cloudflare turn refused: HTTP ${res.status}`);
    return null;
  }
  const json = await res.json();
  const servers = json?.iceServers;
  if (!servers) return null;
  // The API answers with one object, or an array depending on the endpoint.
  return Array.isArray(servers) ? servers : [servers];
}

/// coturn's REST scheme: the username is an expiry and the password is an
/// HMAC of it, so there is no shared password on the phone to leak.
async function coturn(userId: string): Promise<IceServer[] | null> {
  const urls = Deno.env.get("TURN_URLS");
  const secret = Deno.env.get("TURN_SECRET");
  if (!urls || !secret) return null;

  const username = `${Math.floor(Date.now() / 1000) + TTL_SECONDS}:${userId}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(username),
  );
  const credential = btoa(String.fromCharCode(...new Uint8Array(signature)));

  return [{
    urls: urls.split(",").map((u) => u.trim()).filter(Boolean),
    username,
    credential,
  }];
}

Deno.serve(async (req) => {
  // Supabase has already checked the token (--verify-jwt). This reads the
  // subject out of it only to label the coturn credential, never to decide
  // whether to answer.
  let userId = "anon";
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const payload = auth.split(".")[1];
    if (payload) {
      const claims = JSON.parse(atob(payload.replace(/-/g, "+").replace(/_/g, "/")));
      if (typeof claims?.sub === "string") userId = claims.sub;
    }
  } catch {
    // A token we cannot read is still a token Supabase accepted.
  }

  let relay: IceServer[] | null = null;
  try {
    relay = await cloudflare() ?? await coturn(userId);
  } catch (error) {
    console.error(`turn credentials failed: ${error}`);
  }

  return new Response(
    JSON.stringify({
      servers: [...STUN, ...(relay ?? [])],
      has_relay: relay !== null && relay.length > 0,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
