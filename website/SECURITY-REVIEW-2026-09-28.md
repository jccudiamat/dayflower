# Website security review — September 28, 2026

## Result

The tested application protections pass. This review found an outdated framework with a published critical advisory and applied the available patch, plus two defense-in-depth changes. It does not establish that the site is immune to attacks or that all hosting-account controls are configured. The outstanding operational checks below are part of public-launch readiness.

Scope: the Next.js website, its public gift/waitlist/email endpoints, browser image handling, email templates, database access code and migrations, installed dependencies, client build assets, and low-volume production checks against mydayflower.com. Flutter app authorization, infrastructure penetration testing, account takeover testing, production load tests, and historical compromise assessment were outside scope. No real email was sent, no signup/gift was created, and no private database rows were retrieved.

## Changes

1. **Framework security patch:** Next.js and eslint-config-next upgraded from 16.3.5 to 16.3.6; React and React DOM updated together from 19.2.4 to the current 19.2 patch, 19.2.8. The installed Next.js version was within the affected package range for [CVE-2026-94545 / GHSA-vcvr-r3jv-pc5j](https://github.com/vercel/next.js/security/advisories/GHSA-vcvr-r3jv-pc5j), involving Node ImageResponse with attacker-controlled SVG input. The gift preview uses validated indices into fixed color/artwork lists; an exploitable attacker-controlled SVG input path was not established here. Updating removes reliance on that constraint for this advisory. Both initial and final npm audits reported zero findings, demonstrating why the [maintainer advisory](https://nextjs.org/blog/nextjs-security-update-september-22-2026) also needed checking.
2. **Analytics privacy:** a beforeSend filter drops private gift routes and fragment gifts. Only explicit public-page paths are accepted; all query strings and fragments are removed before forwarding an event. Previously there was no application-level filter to protect bearer gift URLs. This is preventive hardening, not evidence of a historical disclosure.
3. **Structured-data escaping:** embedded JSON-LD now escapes `<`, preventing a future content value from closing its script container. Current callers use application-authored content; no user-controlled exploit was established. A regression test confirms that malicious-looking markup remains JSON data and multilingual text survives unchanged.

## Verification

- Production build and ESLint passed on the patched dependencies.
- All **47** tests passed: gift/booth rendering, malformed inputs, script-delimiter escaping, analytics URL filtering, email header/control injection, cross-origin submissions, body byte/depth/time limits, invalid/oversized image handling, server re-encoding, rate-limiter outages, and CAPTCHA rejection/order. Mail-provider calls were mocked.
- `npm audit --json`: **0 reported vulnerabilities**. This is a registry result, not a universal security guarantee.
- A targeted pattern scan of tracked website sources and generated client JavaScript found no service-role JWTs, private keys, or supported provider-token patterns. It was not a Git-history secret scan.
- **16 low-volume live checks passed:** HTTPS/security headers and unique matching CSP nonces; production eval disabled; HTML not shared-cacheable; development email preview, `.env`, `.env.local`, and `.git/config` return 404; all three public POST routes reject cross-origin submissions; malformed waitlist/email requests return 400; external image optimizer URLs return 400.
- Using the existing anonymous key for the configured Supabase project, HEAD queries with `limit=0` returned 401 for waitlist, bouquet_gifts, and website_rate_buckets. Invalid-argument calls to claim_website_request and claim_waitlist_confirmation also returned 401. No data was read and no rate bucket or email claim was created. Authenticated-role grants were reviewed in migration 0042 but not separately exercised with a production user session.

Existing controls retained: server-only database credentials, cryptographically random gift IDs, gift expiration checks, strict field/enum validation, plain-text user prose, explicit email escaping, persistent quotas with fail-closed behavior, bounded burst guards, image dimension/byte limits, metadata-stripping re-encoding, same-origin JSON checks, and server-verified email CAPTCHA. Gift links remain bearer links: a person who receives one can open it.

## Outstanding operational checks

- **September 30 patch:** Next.js has [announced 16.3.7 for September 30](https://nextjs.org/blog/upcoming-nextjs-security-release-september-2026), addressing nine issues including one critical. It was not available during this review (the registry's latest stable was 16.3.6). Assess the published advisories and update promptly when available; impact cannot be determined from the advance notice alone.
- **Hosting controls:** Vercel WAF/edge rate rules, spend/error alerts, production environment-key settings, account MFA, and log-retention controls were not verified through an authenticated hosting dashboard. Application quotas do not replace these controls.
- **Database operations:** verify backups and restore access, production authenticated-role permissions, and the expired-gift cleanup schedule. Expiry prevents website reads; it does not prove physical deletion of old rows.
- **Email delivery:** automated tests confirm verification fails closed, but a successful live Turnstile challenge and a controlled end-to-end delivery were not performed. No claim is made that provider delivery or CAPTCHA configuration is operational.

Reproduce local checks from `website`: `node --test tests/*.mjs emails/send-confirmation.test.mjs`, `npm audit`, `npm run lint`, and `npm run build`. Low-volume live-check evidence and the targeted scanner are retained in the local `output/security-review/` directory.
