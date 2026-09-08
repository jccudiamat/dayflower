import Image from "next/image";
import Link from "next/link";

export default function SiteHeader({ photobooth = false }: { photobooth?: boolean }) {
  return (
    <header className="sticky top-0 z-50 border-b border-border-soft bg-bg/85 backdrop-blur">
      <nav aria-label="Main navigation" className="mx-auto flex min-h-16 max-w-5xl flex-wrap items-center justify-between gap-3 px-5 py-3">
        <Link href="/" aria-label="Dayflower home" className="flex shrink-0 items-center gap-2 rounded text-lg font-bold focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-brand-dark">
          <Image src="/mark.png" alt="" width={360} height={360} className="h-7 w-7" />
          Dayflower
        </Link>
        <div className="flex w-full flex-wrap items-center justify-between gap-3 sm:w-auto sm:justify-end sm:gap-5">
          <Link href="/journal" className="rounded py-2 text-sm font-bold text-brand-dark hover:underline">Journal</Link>
          <Link href="/photobooth" aria-current={photobooth ? "page" : undefined} className={`rounded py-2 text-sm font-bold text-brand-dark hover:underline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-brand-dark ${photobooth ? "underline underline-offset-4" : ""}`}>
            Photo booth
          </Link>
          <Link href="/#waitlist" className="gradient-button !h-10 !px-5 text-sm focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-brand-dark">
            Join the waitlist
          </Link>
        </div>
      </nav>
    </header>
  );
}
