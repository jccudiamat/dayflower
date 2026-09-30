import type { Metadata } from "next";
import { url } from "../lib/seo";
import Link from "next/link";
export const metadata: Metadata = { title: "Terms of Service | Dayflower", description: "Terms for the Dayflower website, waitlist, and private-testing app." , alternates: { canonical: url("/terms") }, robots: { index: true, follow: true } };
const sections = [
["Digital bouquet creator", "You can create a bouquet without an account. A shared gift link stores the arrangement, note, and any photos you add so that someone with the link can open it; a private link carries the arrangement in its URL and cannot include photos. Neither type is encrypted or suitable for confidential messages. Check the names, note, and images before sharing. Anyone with the complete link may copy or forward it, and a link you already shared cannot be revoked or changed by editing your draft. Stored gift links stop opening after 400 days. You retain the rights you hold in your original note and uploaded photos and permit Dayflower to store and display them to deliver the gift. Only email gifts to people you have a legitimate reason to contact; do not use the feature for unsolicited messages."],
["Public photo booth","The public website photo booth is free to use without an app account or waitlist signup. Use only photos you have permission to use, and obtain the agreement of people whose photos you share. Your images are processed in the browser. Save your export before closing or refreshing the page, because Dayflower does not keep a copy for recovery. Native sharing is subject to the capabilities and terms of the app you select."],
["External gift links", "The gift guide may link to third-party sellers. Purchases, delivery, refunds, and product claims are handled by the seller under its terms, not by Dayflower. Check the seller's details before buying."],
  [
    "1. About these terms",
    "These terms cover mydayflower.com, its free bouquet creator and photo booth, the app waitlist, and the private-testing Dayflower app. The app is a private space for two linked partners with messaging, calls, photos, activities, financial tracking, and monthly Chapters. Dayflower is an unregistered project operated from the Philippines. For questions, email app.dayflower@gmail.com."
  ],
  [
    "2. Eligibility and accounts",
    "You must be at least 16 years old to use the website, including its bouquet creator, photo booth, and app waitlist. You must be at least 18 years old to use the app. Provide accurate account information, keep credentials secure, and use only accounts you are authorized to access. Pair only with someone who agrees to connect. A pairing invitation is not permission to access someone else’s account or device."
  ],
  [
    "3. Your content and permissions",
    "You retain the rights you hold in your messages, notes, photos, and other original content. You grant Dayflower a limited license to host, process, display, and transmit that content as needed to provide the features you choose. Only upload content you have the right to share, and respect other people’s privacy and consent. Sharing with a partner may allow them to save copies that you cannot later withdraw."
  ],
  [
    "4. Dayflower artwork and software",
    "Dayflower’s original artwork, branding, software, and other service materials remain the property of their respective owners. Using the app does not transfer ownership of its flower illustrations or other supplied assets to you. Your own words and uploaded photos are distinct from the artwork included with the service."
  ],
  [
    "5. Acceptable use",
    "Do not use Dayflower for harassment, threats, stalking, impersonation, unlawful content, non-consensual intimate imagery, or unauthorized monitoring. Do not access other users’ data, bypass access controls, disrupt the service, or send automated spam. Access may be restricted to address misuse or security risks."
  ],
  [
    "6. Private testing and availability",
    "Dayflower is still in private testing. Features may change, be unavailable, or contain errors. A waitlist signup requests a launch notification and does not guarantee an invitation, release date, or particular feature. Keep independent copies of important content. Calls are not an emergency calling service, and reminders should not be your only means of handling critical tasks."
  ],
  [
    "7. Financial tools and other personal records",
    "Financial features organize information you enter. They do not constitute financial advice, banking, brokerage, or a promise of investment results. You are responsible for checking entries and decisions. Mood and relationship features are not medical care, diagnosis, or counseling."
  ],
  [
    "8. Pricing",
    "The landing page currently describes Dayflower as free at launch. Joining the waitlist does not create a paid subscription. Any future paid offering must disclose its price, billing period, cancellation rules, and other applicable terms before you agree to pay."
  ],
  [
    "9. Leaving and shared data",
    "You may stop using the service. Signing out, uninstalling, disconnecting a pair, and deleting an account are different actions. Disconnecting can affect shared content for both partners. Review in-app confirmations before deleting or disconnecting. There is currently no in-app account-deletion tool. Email app.dayflower@gmail.com to request waitlist removal, account deletion, or a copy of your data. The Privacy Policy explains how requests and retained information are handled."
  ],
  [
    "10. Responsibility and your legal rights",
    "To the extent permitted by applicable law, the private-testing service is provided as available without a guarantee of uninterrupted or error-free operation. Nothing in these terms excludes rights, remedies, warranties, or liabilities that cannot lawfully be excluded. These terms do not require you to waive mandatory consumer protections."
  ],
  [
    "11. Changes and contact",
    "Revised terms will carry an updated date. We will communicate material changes where required by law. Questions or requests can be sent to app.dayflower@gmail.com. These terms do not limit rights that cannot be waived under applicable law."
  ]
];
export default function PolicyPage() {
return <main className="site-page mx-auto max-w-3xl px-5 py-16">
<Link href="/" className="text-sm font-semibold text-brand-dark hover:underline">← Dayflower</Link>
<h1 className="mt-8 text-4xl font-bold">Terms of Service</h1>
<p className="mt-3 text-sm text-body">Updated September 30, 2026</p>
<p className="mt-6 text-lg leading-relaxed text-body">Terms for the Dayflower website, waitlist, and private-testing app.</p>
<p className="mt-4 text-sm text-body">Questions and requests: <a className="font-semibold text-brand-dark hover:underline" href="mailto:app.dayflower@gmail.com">app.dayflower@gmail.com</a></p>
<nav aria-label="On this page" className="mt-8 grid gap-2 border-y border-border-soft py-6 text-sm sm:grid-cols-2">{sections.map(([title], i) => <a key={title} href={`#section-${i+1}`} className="text-body hover:underline">{title}</a>)}</nav>
<div className="mt-10 space-y-9">{sections.map(([title,body],i)=><section key={title} id={`section-${i+1}`} className="scroll-mt-8"><h2 className="text-xl font-bold">{title}</h2><p className="mt-3 text-[15px] leading-7 text-body">{body}</p></section>)}</div>
<footer className="mt-12 flex gap-6 border-t border-border-soft pt-6 text-sm text-brand-dark"><Link href="/">Back to Dayflower</Link><Link href="/privacy">Privacy Policy</Link></footer>
</main>;
}
