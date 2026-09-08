import { NextResponse } from "next/server";
import { sendConfirmation } from "../../../emails/send-confirmation";
import { subject, html, text } from "../../../emails/waitlist-confirmation";

// Deliberately loose: real-world addresses are stranger than most regexes
// allow, so this only rejects the obviously-not-an-email. 254 is the RFC 5321
// maximum length.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_EMAIL_LENGTH = 254;

function fail(error: string, status: number) {
  return NextResponse.json({ error }, { status });
}

export async function POST(request: Request) {
  let email: unknown;
  try {
    const data = await request.json();
    email = data?.email;
  } catch {
    return fail("Invalid request.", 400);
  }

  if (typeof email !== "string") {
    return fail("Please enter a valid email address.", 400);
  }

  const normalized = email.trim().toLowerCase();
  if (!EMAIL_RE.test(normalized) || normalized.length > MAX_EMAIL_LENGTH) {
    return fail("Please enter a valid email address.", 400);
  }

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) {
    console.error("Waitlist: SUPABASE_URL / SUPABASE_ANON_KEY are not set.");
    return fail("The waitlist isn't available right now. Please try again later.", 503);
  }

  let res: Response;
  try {
    res = await fetch(`${url}/rest/v1/waitlist`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({ email: normalized, source: "landing" }),
      signal: AbortSignal.timeout(10_000),
    });
  } catch {
    // DNS failure, refused connection, timeout — Supabase never answered.
    console.error("Waitlist: could not reach Supabase.");
    return fail("The waitlist isn't available right now. Please try again later.", 503);
  }

  const error = !res.ok ? await res.json().catch(() => null) : null;
  // Only the email uniqueness conflict counts as an existing signup.
  if (res.ok || (res.status === 409 && error?.code === "23505")) {
    const confirmation = await sendConfirmation(normalized, { subject, html, text }, {
      supabaseUrl: url,
      serviceKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
      resendKey: process.env.RESEND_API_KEY,
      from: process.env.WAITLIST_EMAIL_FROM,
      replyTo: process.env.WAITLIST_EMAIL_REPLY_TO,
    });
    return NextResponse.json({ ok: true, confirmation });
  }
  console.error("Waitlist: insert rejected.", res.status);

  // 404 here means migration 0007 has not been run yet.
  if (res.status === 404) {
    return fail("The waitlist isn't available right now. Please try again later.", 503);
  }
  return fail("Something went wrong. Please try again.", 502);
}
