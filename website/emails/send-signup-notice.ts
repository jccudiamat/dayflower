const OWNER_ADDRESS = "app.dayflower@gmail.com";

type Settings = { resendKey?: string; from?: string };

/** Alert the operator only after the waitlist insert succeeds. */
export async function sendSignupNotice(email: string, settings: Settings, fetcher: typeof fetch = fetch): Promise<boolean> {
  const { resendKey, from } = settings;
  if (!resendKey || !from) return false;

  try {
    const response = await fetcher("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [OWNER_ADDRESS],
        subject: "New Dayflower waitlist signup",
        text: `A new address joined the Dayflower app waitlist:\n\n${email}\n\nView the complete list in Supabase → Table Editor → public.waitlist.`,
      }),
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) return false;
    const receipt = await response.json();
    return typeof receipt?.id === "string" && receipt.id.length > 0;
  } catch {
    return false;
  }
}
