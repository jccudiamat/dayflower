import type { Metadata } from "next";
import { url } from "../lib/seo";
import Link from "next/link";
export const metadata: Metadata = { title: "Privacy Policy | Dayflower", description: "How the Dayflower website, waitlist, and private-testing app handle information." , alternates: { canonical: url("/privacy") }, robots: { index: true, follow: true } };
const sections = [
["Website analytics", "mydayflower.com uses Vercel Web Analytics to count page views and see which pages people reach. It does not set cookies or store anything in your browser for this, and it does not follow you to other websites. Vercel counts a repeat visit using a value derived from the incoming request, such as your IP address and browser user agent, which is hashed with a salt that changes daily; it is not a profile and does not persist beyond that. What is recorded is the page visited, the referring link, an approximate country, and general device, browser, and operating-system type. Nothing you type, upload, or create on this site is included, and analytics is not used in the bouquet creator’s or photo booth’s handling of your images. Analytics runs on the website only, not in the app."],
["Delivery security checks", "When enabled, Cloudflare Turnstile checks browser and network signals before sending a gift by email to help prevent automated abuse. The website verifies a short-lived token with Cloudflare. Your bouquet, message, and recipient email are not included in that verification request."],
["Digital bouquet creator", "The bouquet creator works without an account. Your unfinished bouquet and note are saved in this browser’s local storage when available. Clear this website’s browser data to remove the local draft. There are two kinds of gift link. A shared link (mydayflower.com/g/…) stores the arrangement, note, and any photos you added on our server so the recipient can open it and so messaging and mail apps can show a preview card; that preview names the sender and recipient you entered but not the contents. A private link instead carries the whole arrangement in the URL fragment (the part after #), which is not sent to our server in the page request, and cannot include photos. Neither link is encrypted: anyone who receives the complete link can open and copy its contents. We record when a stored gift was created and when it was first opened. A stored gift link stops resolving after 400 days; the current storage setup does not automatically erase its expired database record. Sharing sends the link through the app you choose. Each link keeps the version created at that time; later edits do not update or revoke earlier links. Downloaded bouquet images remain on your device."],
["Public photo booth","The public photo booth does not require an account. Selected photos, camera captures, crops, and generated strips are processed locally in your browser and are not uploaded to Dayflower servers. We do not maintain a booth gallery. Closing the page or clearing the session releases the photos held by the tool. Downloaded files remain on your device. Using Share sends the exported image through the app you choose. Camera access is optional and can be stopped in the tool or revoked in browser settings. Advertising spaces are currently placeholders; no ad network is loaded by the booth."],
  [
    "1. Scope and operator",
    "This policy covers mydayflower.com and the Dayflower app, which is in private testing. Dayflower is an unregistered project operated from the Philippines. For privacy questions or requests, email app.dayflower@gmail.com."
  ],
  [
    "2. Website and waitlist",
    "When you join the waitlist, we send your email address to Supabase with a landing-page source label. We use it to send a signup confirmation and notify you when Dayflower is ready. Confirmation emails are delivered through Resend, which processes the recipient address and message for delivery. We store confirmation attempt times and provider acceptance receipts to reduce duplicates; acceptance does not guarantee inbox delivery. Joining the waitlist does not create an app account or enroll your partner. If you choose to email a bouquet, Resend processes the recipient address and gift-link message to deliver it; the recipient address is not stored with the bouquet in our database. Hosting and network providers process connection information, such as IP addresses and request details, to deliver and secure the website."
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
    "We use information to provide the features you request, including authenticating accounts, linking partners, delivering content and calls, synchronizing activity, and providing reminders and notifications. We also use limited technical information to secure, maintain, and troubleshoot the service. Waitlist information is used to send the requested confirmation and launch notice. These activities rely on your request or our service relationship, our legitimate interest in running and securing Dayflower, or consent where applicable. Your partner can see content shared within the couple’s space. Financial visibility depends on the account’s ownership and partner-visibility settings; do not assume every financial record is private or every record is shared. A recipient can save or screenshot content outside the app."
  ],
  [
    "7. Providers and security",
    "Supabase supports authentication, database storage, and uploaded media. Vercel hosts the website, Cloudflare provides domain/DNS and security-check services, and Resend delivers requested emails. When app notifications and calls are enabled, Firebase Cloud Messaging, platform delivery services, and LiveKit also process data needed for those features. Authorized operators and providers may have access for service operation, support, and security; access is not limited literally to two people. Access controls reduce unauthorized access, but this policy does not promise end-to-end encryption or absolute security. Service processing may occur outside the Philippines."
  ],
  [
    "8. Device storage and tracking",
    "The app stores session information, preferences, and some cached content on your device. Uninstalling it or clearing local data does not necessarily erase server-side records. The reviewed website code does not add advertising trackers or a marketing analytics SDK. Hosting logs and essential app storage are separate from advertising tracking."
  ],
  [
    "9. Retention, deletion, and choices",
    "Waitlist records are kept while needed to send the requested launch notice, unless you ask us to remove your address sooner. App account and shared-content records are kept while needed to provide the app, unless you request deletion or a different period is required for legal or security reasons. Shared gift links stop opening after 400 days, but expired gift records are not yet automatically purged; you can request removal of a gift you created by sending its link. You can edit or remove supported content in the app, clear browser drafts, and revoke device permissions. Disconnecting a pair is different from deleting an account and can remove shared records for both partners. There is currently no in-app account-deletion tool. To request waitlist removal, access, correction, export, or account or content deletion, email app.dayflower@gmail.com, preferably from the address linked to your record. We may ask you to verify your identity and will explain any effect on shared content or information we must retain. Deleting a screen item or account does not instantly remove copies held in provider backups or security logs, whose retention periods can differ. You may also have rights to object to processing and to complain to the Philippine National Privacy Commission or another applicable authority."
  ],
  [
    "10. Age, changes, and contact",
    "The website is intended for people aged 16 and over. The Dayflower app is intended for adults aged 18 and over. If you believe someone below the relevant age has provided personal information, email app.dayflower@gmail.com. We will update this policy when our practices materially change and show the latest revision date above."
  ]
];
export default function PolicyPage() {
return <main className="site-page mx-auto max-w-3xl px-5 py-16">
<Link href="/" className="text-sm font-semibold text-brand-dark hover:underline">← Dayflower</Link>
<h1 className="mt-8 text-4xl font-bold">Privacy Policy</h1>
<p className="mt-3 text-sm text-body">Updated September 30, 2026</p>
<p className="mt-6 text-lg leading-relaxed text-body">How the Dayflower website, waitlist, and private-testing app handle information.</p>
<p className="mt-4 text-sm text-body">Privacy requests: <a className="font-semibold text-brand-dark hover:underline" href="mailto:app.dayflower@gmail.com">app.dayflower@gmail.com</a></p>
<nav aria-label="On this page" className="mt-8 grid gap-2 border-y border-border-soft py-6 text-sm sm:grid-cols-2">{sections.map(([title], i) => <a key={title} href={`#section-${i+1}`} className="text-body hover:underline">{title}</a>)}</nav>
<div className="mt-10 space-y-9">{sections.map(([title,body],i)=><section key={title} id={`section-${i+1}`} className="scroll-mt-8"><h2 className="text-xl font-bold">{title}</h2><p className="mt-3 text-[15px] leading-7 text-body">{body}</p></section>)}</div>
<footer className="mt-12 flex flex-wrap gap-6 border-t border-border-soft pt-6 text-sm text-brand-dark"><Link href="/">Back to Dayflower</Link><Link href="/terms">Terms of Service</Link><a href="https://privacy.gov.ph/data-subject-rights/">Privacy rights in the Philippines</a></footer>
</main>;
}
