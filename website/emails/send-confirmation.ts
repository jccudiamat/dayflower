type EmailTemplate = { subject: string; html: string; text: string };
type Settings = { supabaseUrl?: string; serviceKey?: string; resendKey?: string; from?: string; replyTo?: string };
export type ConfirmationStatus = "accepted" | "pending" | "unavailable";

export async function sendConfirmation(email: string, template: EmailTemplate, settings: Settings, fetcher: typeof fetch = fetch): Promise<ConfirmationStatus> {
  const { supabaseUrl, serviceKey, resendKey, from, replyTo } = settings;
  if (!supabaseUrl || !serviceKey || !resendKey || !from) return "unavailable";
  const headers = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" };
  try {
    const claim = await fetcher(`${supabaseUrl}/rest/v1/rpc/claim_waitlist_confirmation`, { method: "POST", headers, body: JSON.stringify({ p_email: email }), signal: AbortSignal.timeout(8000) });
    if (!claim.ok) return "unavailable";
    const rows = await claim.json();
    const row = rows?.[0];
    if (!row?.signup_id) return "unavailable";
    if (row.delivery_state === "accepted") return "accepted";
    if (row.delivery_state !== "claimed") return "pending";
    const result = await fetcher("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json", "Idempotency-Key": `waitlist-confirmation-v1/${row.signup_id}` },
      body: JSON.stringify({ from, to: [email], ...template, ...(replyTo ? { reply_to: replyTo } : {}) }),
      signal: AbortSignal.timeout(10000),
    });
    if (!result.ok) return "pending";
    const receipt = await result.json();
    if (!receipt.id) return "pending";
    const saved = await fetcher(`${supabaseUrl}/rest/v1/waitlist?id=eq.${encodeURIComponent(row.signup_id)}`, {
      method: "PATCH", headers, body: JSON.stringify({ confirmation_accepted_at: new Date().toISOString(), confirmation_provider_id: receipt.id }), signal: AbortSignal.timeout(8000),
    });
    // Do not log addresses, tokens, response bodies, or database contents.
    if (!saved.ok) console.error("Waitlist confirmation: provider receipt could not be persisted.");
    return "accepted";
  } catch {
    // Signup is already saved. A repeated signup can retry after the claim cooldown.
    return "pending";
  }
}
