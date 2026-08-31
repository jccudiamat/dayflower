import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Terms of Service — Dayflower",
  description: "Preliminary Terms of Service for the Dayflower app and website.",
};

export default function TermsPage() {
  return (
    <div className="mx-auto max-w-2xl px-5 py-16">
      <p className="text-sm font-semibold">
        <Link href="/" className="text-muted hover:underline">
          🌷 Dayflower
        </Link>{" "}
        <span className="text-muted">/ Terms</span>
      </p>

      <h1 className="mt-6 text-3xl font-bold leading-tight">
        Terms of <span className="gradient-text">Service</span>
      </h1>
      <p className="mt-2 text-sm text-muted">
        Preliminary draft · Last updated July 18, 2026
      </p>

      <div className="mt-4 rounded-2xl border border-border-soft bg-surface-subtle px-4 py-3 text-sm">
        This is a preliminary draft published for transparency while Dayflower is
        in development. It has not been reviewed by a lawyer and will be
        replaced before public launch.
      </div>

      <div className="prose-dayflower mt-8 space-y-6 text-[15px] leading-relaxed">
        <section>
          <h2 className="text-lg font-bold">1. What Dayflower is</h2>
          <p className="mt-2 text-muted">
            Dayflower is a private ritual app for couples. It lets two linked
            partners exchange a daily flower with a note, send heartbeat
            taps, share a reunion countdown, and see each other&apos;s local
            time. The service is provided by the Dayflower team
            (&ldquo;we&rdquo;, &ldquo;us&rdquo;).
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">2. Your account</h2>
          <p className="mt-2 text-muted">
            You need an account (email and password) to use Dayflower. You are
            responsible for keeping your credentials safe and for what
            happens under your account. You must be at least 18 years old.
            One account links to exactly one partner; pairing requires the
            other person&apos;s explicit action (entering your invite code).
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">3. Your content</h2>
          <p className="mt-2 text-muted">
            The notes, flowers, and other content you send belong to you.
            By using Dayflower you give us the limited licence needed to store
            that content and deliver it to your linked partner — that is the
            entire purpose of the app. We do not use your content for
            advertising, and we do not sell it. See the{" "}
            <Link href="/privacy" className="underline">
              Privacy Policy
            </Link>{" "}
            for details.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">4. Acceptable use</h2>
          <p className="mt-2 text-muted">
            Don&apos;t attempt to access another couple&apos;s data, abuse
            the service (e.g. automated spam), or use Dayflower for anything
            unlawful. We may suspend accounts that do.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">5. Paid features</h2>
          <p className="mt-2 text-muted">
            Dayflower&apos;s core ritual is free. Optional premium features may be
            offered as a subscription in the future; pricing and billing
            terms will be added here before any charge exists.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">6. Ending things</h2>
          <p className="mt-2 text-muted">
            You can stop using Dayflower and delete your account at any time.
            Deleting your account removes your profile and the content you
            sent. We may discontinue the service with reasonable notice.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">7. Disclaimers</h2>
          <p className="mt-2 text-muted">
            Dayflower is provided &ldquo;as is&rdquo;, without warranties. To the
            maximum extent permitted by law, we are not liable for indirect
            or consequential damages arising from use of the service. Dayflower
            is a gesture between two people — it is not a substitute for
            communication, counselling, or emergency services.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold">8. Changes & contact</h2>
          <p className="mt-2 text-muted">
            We&apos;ll update these terms as Dayflower grows and note the date at
            the top. Questions:{" "}
            <span className="font-semibold">hello@dayflower.app</span>{" "}
            (placeholder address until the domain goes live).
          </p>
        </section>
      </div>

      <p className="mt-12 border-t border-border-soft pt-6 text-sm text-muted">
        <Link href="/" className="hover:underline">
          ← Back to Dayflower
        </Link>
      </p>
    </div>
  );
}
