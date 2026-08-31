import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy Policy — Dayflower",
  description: "Preliminary Privacy Policy for the Dayflower app and website.",
};

export default function PrivacyPage() {
  return (
    <div className="mx-auto max-w-2xl px-5 py-16">
      <p className="text-sm font-semibold">
        <Link href="/" className="text-muted hover:underline">
          🌷 Dayflower
        </Link>{" "}
        <span className="text-muted">/ Privacy</span>
      </p>

      <h1 className="mt-6 text-3xl font-bold leading-tight">
        Privacy <span className="gradient-text">Policy</span>
      </h1>
      <p className="mt-2 text-sm text-muted">
        Preliminary draft · Last updated July 18, 2026
      </p>

      <div className="mt-4 rounded-2xl border border-border-soft bg-surface-subtle px-4 py-3 text-sm">
        This is a preliminary draft published for transparency while Dayflower is
        in development. It has not been reviewed by a lawyer and will be
        replaced before public launch.
      </div>

      <div className="mt-8 space-y-6 text-[15px] leading-relaxed">
        <section>
          <h2 className="text-lg font-bold">The short version</h2>
          <p className="mt-2 text-muted">
            Dayflower exists so two people can share small daily gestures. Your
            data is visible to exactly two parties: you and your linked
            partner. No ads, no data sales, no third-party analytics.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">1. What we collect</h2>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-muted">
            <li>
              <span className="font-semibold">Account:</span> your email
              address and a hashed password.
            </li>
            <li>
              <span className="font-semibold">Profile:</span> the name,
              nickname, and timezone you choose to share.
            </li>
            <li>
              <span className="font-semibold">Couple content:</span> the
              flowers and notes you exchange, heartbeat taps (timestamps),
              and your shared reunion details.
            </li>
            <li>
              <span className="font-semibold">Waitlist:</span> if you join
              the waitlist on this site, your email address.
            </li>
          </ul>
          <p className="mt-2 text-muted">
            We do not collect your location, contacts, photos (in the
            current version), or anything from other apps.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">2. How it&apos;s used</h2>
          <p className="mt-2 text-muted">
            Solely to run Dayflower: signing you in, syncing your content to your
            linked partner in real time, and sending service emails
            (sign-in codes, password resets). Nothing else.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">3. Where it lives</h2>
          <p className="mt-2 text-muted">
            Data is stored with Supabase (our database and authentication
            provider). Access is protected by row-level security: each row
            of couple content is readable only by the two linked accounts.
            Service emails are delivered via Resend.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">4. Who can see it</h2>
          <p className="mt-2 text-muted">
            Your linked partner sees what you send them — that&apos;s the
            product. We (the developers) can technically access the database
            that hosts your data, and touch it only for debugging or
            support. We never sell or share data with advertisers or data
            brokers.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">5. Deletion & your rights</h2>
          <p className="mt-2 text-muted">
            Deleting your account removes your profile and cascades to the
            content you sent (flowers, heartbeats, shared reunion). You can
            also ask us to export or erase your data at any time —
            email <span className="font-semibold">hello@dayflower.app</span>{" "}
            (placeholder address until the domain goes live).
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">6. Changes</h2>
          <p className="mt-2 text-muted">
            We&apos;ll update this policy as Dayflower grows and note the date at
            the top. Material changes will be announced in the app.
          </p>
        </section>
      </div>

      <p className="mt-12 border-t border-border-soft pt-6 text-sm text-muted">
        <Link href="/" className="hover:underline">
          ← Back to Dayflower
        </Link>{" "}
        · <Link href="/terms" className="hover:underline">Terms of Service</Link>
      </p>
    </div>
  );
}
