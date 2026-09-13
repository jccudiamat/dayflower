# Website security controls

All public writes pass through the website server. Apply migration 0041 before deploying this code, then 0042 after deployment. Migration 0042 removes anonymous/authenticated table access without deleting existing gifts or signups. Never restore the old broad bouquet SELECT policy or public INSERT grants.

Server environment: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and existing email-provider settings. `RATE_LIMIT_SALT` is optional; the server-only service key provides the HMAC secret when it is absent. Never put these secrets in a Flutter asset or `NEXT_PUBLIC_*` variable. Forwarded IP headers are trusted only when running on Vercel, which overwrites them. Other deployments deliberately share a fallback bucket until a trusted proxy integration is implemented.

## Input and output rules

- Public POST endpoints accept JSON objects only, reject unknown request fields, cross-site browser submissions and compressed bodies, and enforce streaming byte limits, UTF-8 validity, nesting limits, and a five-second body deadline.
- Gift creation accepts up to 1.8 MB; email and waitlist requests accept up to 2 KB. Names, notes, captions, addresses, identifiers, enum selections, array counts, and numeric coordinates are bounded. Old gift styles retain safe defaults on reads; newly submitted styles are strictly validated.
- User prose remains plain text. React escapes HTML; canvas renders it as text; email templates explicitly escape it. Do not render user input with `dangerouslySetInnerHTML` or use it as a script, URL, SQL fragment, or provider header.
- Both editors inspect image file signatures and dimensions before browser decoding: JPEG, PNG, or WebP, at most 24 MP and 12,000 pixels per side. Animated PNG/WebP is rejected. Existing file-byte ceilings remain 15 MB for bouquets and 20 MB for the booth.
- Shared photo data receives a second server validation and sequential re-encoding with a four-megapixel decoder limit, 2,048-pixel input side limit, 640-pixel output, three-second decoder timeout, and 180 KB encoded-photo ceiling. Metadata is stripped. Booth photos remain local.
- Gift reads use an exact validated ID and explicit expiration with server-only credentials. Public database scans and inserts are denied. Anyone who actually possesses a gift link can still open it; it is a bearer link, not end-to-end encryption.

## Resource limits

The server-only `claim_website_request` function serializes quota checks and increments under a transaction lock. Counter rows contain keyed hashes rather than raw addresses/IPs and expire automatically. It fails closed when unavailable. All ceilings below use fixed UTC hour/day windows; a boundary can allow two adjacent windows' allowances.

| Action | Per sender/hour | Per sender/day | Site/hour | Site/day | Additional daily caps |
| --- | ---: | ---: | ---: | ---: | --- |
| Create gift | 10 | 40 | 250 | 1,000 | — |
| Waitlist | 5 | 10 | 100 | 500 | 3 per recipient |
| Email gift | 5 | 10 | 100 | 300 | 3 per recipient; 3 per gift |
| Read gift/preview | 300 | 1,000 | 2,000 | 10,000 | — |

A bounded per-instance guard additionally limits matched dynamic/API routes to 60 requests per IP per minute and 600 per instance per minute before database work. It is not a substitute for the persistent limiter or an edge firewall. Invalid email/waitlist bodies are rejected before database work; attempted gift creates are charged before reading their larger body.

CSP uses fresh script nonces, disables inline script attributes and production eval, and blocks objects and framing. HTML is dynamically rendered and not shared-cacheable so a nonce cannot be reused. Inline styles remain allowed for the existing editors. Additional headers set `nosniff`, `DENY`, `no-referrer`, and restrict device permissions while permitting the booth camera. Image optimization accepts only the site's known local asset directories.

## Hosting controls and limitations

Application limits bound normal abusive workloads and paid side effects, but cannot guarantee immunity from DDoS or distributed attacks. Keep Vercel DDoS mitigation enabled, configure WAF rate limits before the application (especially `/api/*`, `/g/*`, and `/_next/image`), and monitor spend/error alerts. Provider account/firewall settings are separate from this repository and must be verified in the Vercel dashboard. If adding a bot challenge, verify it server-side before storing data or sending email; never rely on client checks alone.

The global budgets intentionally cap cost during distributed abuse and may temporarily reject legitimate traffic during an attack. Adjust them with traffic evidence rather than removing them. Expired gifts cease to resolve, but physical row cleanup requires a separately configured retention job; no existing keepsakes are deleted by these migrations.

## Verification

Run `node --test tests/*.mjs emails/send-confirmation.test.mjs`, `npm audit`, lint, and the production build. Verify CSP nonces match emitted scripts, ordinary photo gifts still render, anonymous database scans/inserts are denied, and limiter outages stop side effects. Exercise limits against a test database or a rolled-back transaction; do not burst-send real email. Maintain provider idempotency keys across deployments.
