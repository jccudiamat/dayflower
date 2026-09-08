import type { Metadata } from "next";
import Link from "next/link";
export const metadata: Metadata = { title: "Privacy Policy — Dayflower", description: "How the Dayflower website, waitlist, and private-testing app handle information." };
const sections = [
["Public photo booth","The public photo booth does not require an account. Selected photos, camera captures, crops, and generated strips are processed locally in your browser and are not uploaded to Dayflower servers. We do not maintain a booth gallery. Closing the page or clearing the session releases the photos held by the tool. Downloaded files remain on your device. Using Share sends the exported image through the app you choose. Camera access is optional and can be stopped in the tool or revoked in browser settings. Advertising spaces are currently placeholders; no ad network is loaded by the booth."],
  [
    "1. Scope and operator",
    "This policy covers the Dayflower app and mydayflower.com. The app is in private testing. Operator identity, country, and the privacy contact are pending confirmation in this review draft."
  ],
  [
    "2. Website and waitlist",
    "When you join the waitlist, we send your email address to Supabase with a landing-page source label. We use it to send a signup confirmation and notify you when Dayflower is ready. Confirmation emails are delivered through Resend, which processes the recipient address and message for delivery. We store confirmation attempt times and provider acceptance receipts to reduce duplicates; acceptance does not guarantee inbox delivery. Joining the waitlist does not create an app account or enroll your partner. Hosting and network providers process connection information, such as IP addresses and request details, to deliver and secure the website."
  ],
  [
    "3. Account and profile information",
    "The app uses Supabase for account authentication. We process account identifiers, email addresses, authentication information, and the profile details you provide, such as your name, nickname, avatar, birthday, and time zone. Pairing records connect your account to your chosen partner. The app estimates distance using selected time-zone cities; this is not a live GPS location."
  ],
  [
    "4. Content and activity in the app",
    "Depending on the features you use, we process flowers, messages, notes, photos, photo strips, mood selections, heartbeat events, and associated timestamps. Events include dates, titles, places, and notes you enter. Reminders, financial accounts and entries, savings information, monthly goals, and Chapter reviews are also processed when you use those tools. These entries may be sensitive: only add information you want the service to hold."
  ],
  [
    "5. Calls, permissions, and notifications",
    "Voice and video calls process microphone audio, camera video when enabled, connection information, and call status/history through the app’s calling infrastructure. Calls use LiveKit technology. The app requests camera, microphone, photo access, and notification permissions as needed for the relevant feature. Push notifications use device tokens and platform information with Firebase Cloud Messaging and platform delivery services. Notifications may reveal activity on a lock screen; control previews and permissions in your device settings."
  ],
  [
    "6. How information is used and shared",
    "We use information to authenticate accounts, link partners, deliver content and calls, synchronize activity, provide reminders and notifications, and maintain and troubleshoot the service. Your partner can see content shared within the couple’s space. Financial visibility depends on the account’s ownership and partner-visibility settings; do not assume every financial record is private or every record is shared. A recipient can save or screenshot content outside the app."
  ],
  [
    "7. Providers and security",
    "Supabase supports authentication, database storage, and uploaded media. Vercel hosts the website, and Cloudflare provides domain/DNS services. Notification and calling infrastructure also process the data needed for those features. Authorized operators and providers may have access for service operation, support, and security; access is not limited literally to two people. Access controls reduce unauthorized access, but this policy does not promise end-to-end encryption or absolute security. Service processing may occur outside your country. Exact hosting regions and the deployed calling/email providers remain to be confirmed for the final policy."
  ],
  [
    "8. Device storage and tracking",
    "The app stores session information, preferences, and some cached content on your device. Uninstalling it or clearing local data does not necessarily erase server-side records. The reviewed website code does not add advertising trackers or a marketing analytics SDK. Hosting logs and essential app storage are separate from advertising tracking."
  ],
  [
    "9. Retention, deletion, and choices",
    "You can edit or remove supported content through the app and revoke device permissions. Disconnecting a pair is different from deleting your authentication account and can remove shared records for both partners. We have not verified a complete in-app account-erasure workflow, so this draft does not promise one. Server data, media, logs, and backups may have different deletion behavior; deleting a screen item does not establish that every copy has been erased. Retention periods, backup expiry, and the export/account-erasure request process must be confirmed before this draft is published as final. Depending on your location, you may have rights to access, correct, erase, export, or object to processing of your information and to complain to a data-protection authority."
  ],
  [
    "10. Age, changes, and contact",
    "Dayflower is intended for adults aged 18 and over. This policy will be updated as the service changes, with the revision date shown above. A verified privacy contact must be added before publication; hello@mydayflower.com has not been confirmed as a working mailbox."
  ]
];
export default function PolicyPage() {
return <main className="mx-auto max-w-3xl px-5 py-16">
<Link href="/" className="text-sm font-semibold text-brand-dark hover:underline">← Dayflower</Link>
<h1 className="mt-8 text-4xl font-bold">Privacy Policy</h1>
<p className="mt-3 text-sm text-body">Review draft · Updated September 6, 2026</p>
<p className="mt-6 text-lg leading-relaxed text-body">How the Dayflower website, waitlist, and private-testing app handle information.</p>
<aside className="mt-6 rounded-2xl border border-border-soft bg-surface-subtle p-5 text-sm leading-relaxed text-body"><strong>Draft for review.</strong> Operator details, a working contact address, and retention/deletion procedures still need confirmation before publication.</aside>
<nav aria-label="On this page" className="mt-8 grid gap-2 border-y border-border-soft py-6 text-sm sm:grid-cols-2">{sections.map(([title], i) => <a key={title} href={`#section-${i+1}`} className="text-body hover:underline">{title}</a>)}</nav>
<div className="mt-10 space-y-9">{sections.map(([title,body],i)=><section key={title} id={`section-${i+1}`} className="scroll-mt-8"><h2 className="text-xl font-bold">{title}</h2><p className="mt-3 text-[15px] leading-7 text-body">{body}</p></section>)}</div>
<footer className="mt-12 flex gap-6 border-t border-border-soft pt-6 text-sm text-brand-dark"><Link href="/">Back to Dayflower</Link><Link href="/terms">Terms of Service</Link></footer>
</main>;
}
