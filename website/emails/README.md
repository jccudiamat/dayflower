# Waitlist confirmation email

Preview locally at `/api/email-preview` (404 in production). The template includes inline HTML and a plain-text alternative; no tracking pixel is added by the template.

## Enable sending

1. Apply `supabase/migrations/0033_waitlist_confirmation.sql` after the existing waitlist migration. It preserves signups, adds receipt tracking, and restricts public inserts to email/source.
2. Verify a sending domain in Resend and set these **server-only** environment variables locally and in Vercel Production:
   - `RESEND_API_KEY`
   - `WAITLIST_EMAIL_FROM` — a verified sender, e.g. `Dayflower <hello@mydayflower.com>` (example, not a configured mailbox).
   - `SUPABASE_SERVICE_ROLE_KEY` — used only by the server for confirmation claims and receipt updates.
   - `WAITLIST_EMAIL_REPLY_TO` — optional monitored reply address.
   Existing `SUPABASE_URL` and `SUPABASE_ANON_KEY` remain required for signup insertion.
3. Deploy the website and photo booth together: the email links to `/photobooth`.
4. Submit an authorized test address, check the inbox, and verify `confirmation_provider_id` and `confirmation_accepted_at` in Supabase. Resubmit to check it does not send again.

## Delivery behavior

The signup is saved before delivery is attempted. Database claims serialize simultaneous requests and impose a five-minute retry cooldown. Resend uses a stable per-signup idempotency key, which Resend retains for 24 hours. Persisted acceptance prevents later repeat sends. Provider acceptance is not proof of inbox delivery; bounces/spam placement require provider-side inspection.

If configuration or delivery fails, the signup still succeeds and the UI explicitly reports that confirmation was not sent. A repeated signup retries after the cooldown. There is no automatic background retry job or launch-email campaign implemented here. If Resend accepts an email but persisting its receipt fails, review provider history before retrying after the 24-hour idempotency window to avoid a duplicate. Do not rotate the template/sender during ambiguous retries within that window.

Never put credentials in `NEXT_PUBLIC_*` variables or commit them. Resend domain verification is separate from setting up an inbox to receive replies.

Run isolated tests with `node --test emails/send-confirmation.test.mjs`. Tests mock all requests and send no email.

References: https://resend.com/docs/api-reference/emails/send-email and https://resend.com/docs/dashboard/emails/idempotency-keys
