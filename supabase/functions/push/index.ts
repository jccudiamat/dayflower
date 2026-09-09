// Dayflower — turns a row in the thread into a notification on the other
// phone.
//
// Deploy:  npx supabase functions deploy push --no-verify-jwt
//
// `--no-verify-jwt` because the caller is a Postgres trigger, not a signed-in
// user; the shared secret below is what authenticates it instead.
//
// Env it needs (npx supabase secrets set KEY=value):
//   PUSH_SECRET             the same random string stored in Vault as
//                           `push_secret` — see migration 0028
//   FCM_SERVICE_ACCOUNT     the whole service-account JSON, one line
//   SUPABASE_URL            provided automatically
//   SUPABASE_SERVICE_ROLE_KEY  provided automatically
//
// ## Why this exists at all, when everything else in this project is SQL
//
// FCM's v1 API wants an OAuth access token, obtained by signing a JWT with
// the service account's **RS256** key. `pgjwt` (0.2.0, what Supabase ships)
// does HS256 only. So unlike the LiveKit tokens in migration 0026, this one
// genuinely cannot be signed in Postgres — push is where the
// everything-in-the-database approach runs out, and this is the smallest
// possible piece of server to make up the difference.

import { createClient } from "jsr:@supabase/supabase-js@2";

interface Payload {
  message_id: string;
  pair_id: string;
  sender_id: string;
  kind: "call" | "photo" | "flower" | "message";
  call_mode: "voice" | "video" | null;
}

// Cached across warm invocations. Google's tokens last an hour; minting one
// per notification would double the latency of every push and hammer an
// endpoint that rate-limits.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function fcmAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const b64 = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const unsigned = `${b64(header)}.${b64(claims)}`;

  // The PEM arrives with literal \n in the JSON, which has to become real
  // newlines before the base64 body can be pulled out of it.
  const pem = serviceAccount.private_key.replace(/\\n/g, "\n");
  const der = Uint8Array.from(
    atob(pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s/g, "")),
    (c) => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)),
  );
  const jwt = `${unsigned}.${
    btoa(String.fromCharCode(...signature))
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
  }`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`oauth ${res.status}: ${await res.text()}`);

  const json = await res.json();
  cachedToken = { value: json.access_token, expiresAt: now + json.expires_in };
  return cachedToken.value;
}

/// What the notification says, and how loudly.
///
/// A call is the one thing here allowed to take over the screen — it expires
/// if it is not seen while it is happening. Everything else is a banner that
/// waits, matching how the in-app alerts already behave.
function describe(payload: Payload, name: string) {
  switch (payload.kind) {
    case "call":
      return {
        title: name,
        body: payload.call_mode === "video"
          ? "is video calling you"
          : "is calling you",
        priority: "high" as const,
      };
    case "photo":
      return { title: name, body: "shared their day 📷", priority: "normal" as const };
    case "flower":
      return { title: name, body: "sent you a flower 🌷", priority: "normal" as const };
    default:
      return { title: name, body: "sent you a message", priority: "normal" as const };
  }
}

Deno.serve(async (req) => {
  // The trigger's shared secret. Without this, anyone who learns the
  // function URL can push arbitrary notifications to your users.
  const secret = Deno.env.get("PUSH_SECRET");
  if (!secret || req.headers.get("x-push-secret") !== secret) {
    return new Response("no", { status: 401 });
  }

  const payload = (await req.json()) as Payload;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Who to wake: the half of the pair that did not send it.
  const { data: pair } = await supabase
    .from("pairs")
    .select("user_a, user_b")
    .eq("id", payload.pair_id)
    .single();
  if (!pair) return new Response("no pair", { status: 200 });

  const recipient = pair.user_a === payload.sender_id ? pair.user_b : pair.user_a;
  if (!recipient) return new Response("unpaired", { status: 200 });

  const [{ data: tokens }, { data: sender }] = await Promise.all([
    supabase.from("device_tokens").select("token").eq("user_id", recipient),
    supabase.from("users").select("pet_name, display_name").eq("id", payload.sender_id).single(),
  ]);

  // Nobody has registered a device yet. Not an error — the app may simply
  // not have been opened since push shipped.
  if (!tokens?.length) return new Response("no devices", { status: 200 });

  const name = sender?.pet_name ?? sender?.display_name ?? "Someone";
  const { title, body, priority } = describe(payload, name);

  const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
  const accessToken = await fcmAccessToken(serviceAccount);
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  const dead: string[] = [];
  let sent = 0;
  await Promise.all(tokens.map(async ({ token }) => {
    const res = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          // ⚠️ **Data-only, no `notification` block.** A `notification`
          // payload is drawn by the system and never reaches the app when it
          // is backgrounded — which would make a call impossible to ring
          // properly. Data-only hands every message to the Dart background
          // handler, which decides between the full-screen call UI and a
          // quiet banner.
          data: {
            kind: payload.kind,
            messageId: payload.message_id,
            pairId: payload.pair_id,
            callMode: payload.call_mode ?? "",
            title,
            body,
          },
          android: {
            priority: priority === "high" ? "HIGH" : "NORMAL",
            // A call that arrives late is worse than one that never came,
            // so it is not worth storing while the phone is offline.
            ttl: payload.kind === "call" ? "60s" : "86400s",
          },
        },
      }),
    });

    if (!res.ok) {
      const error = await res.json().catch(() => null);
      // The device is gone — app uninstalled, or the token rotated. Reaping
      // it here is the only place that ever learns this.
      if (error?.error?.details?.some((detail: { errorCode?: string }) => detail.errorCode === "UNREGISTERED")) {
        dead.push(token);
      }
      console.error(`fcm rejected push: HTTP ${res.status}`);
    } else {
      sent++;
    }
  }));

  if (dead.length) {
    await supabase.from("device_tokens").delete().in("token", dead);
  }

  return new Response(JSON.stringify({ sent, failed: tokens.length - sent, removed: dead.length }), {
    headers: { "Content-Type": "application/json" },
  });
});
