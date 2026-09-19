import Image from "next/image";
import Link from "next/link";

/**
 * The homepage's own navigation: transparent, over the scene, not sticky.
 *
 * ⚠️ Separate from `SiteHeader` on purpose. Every other page needs a solid
 * bar that survives scrolling over white; this one needs to disappear into a
 * sunrise. Sharing a component between the two would mean a header that is
 * transparent over the hero and then illegible over the first white section.
 *
 * Every item goes somewhere real: three anchors on this page and two of the
 * site's own routes. Nothing here is a placeholder.
 */
const LINKS = [
  ["Explore", "/#explore"],
  ["Create", "/bouquet"],
  ["Journal", "/journal"],
  ["App", "/#app"],
  ["About", "/#about"],
] as const;

export default function HomeNav() {
  return (
    <header className="home-nav">
      <nav aria-label="Main navigation" className="home-nav-inner">
        <Link href="/" className="home-nav-brand" aria-label="Dayflower home">
          <Image src="/mark.png" alt="" width={30} height={30} />
          Dayflower
        </Link>
        <div className="home-nav-links">
          {LINKS.map(([label, href]) => (
            <Link key={label} href={href}>
              {label}
            </Link>
          ))}
        </div>
        <Link href="/#waitlist" className="home-nav-cta">
          Join waitlist
        </Link>
        <Link href="/bouquet" className="home-nav-heart" aria-label="Send a flower">
          <svg viewBox="0 0 24 24" aria-hidden>
            <path d="M12 20.6s-8-5-8-10.4A4.7 4.7 0 0 1 12 7a4.7 4.7 0 0 1 8 3.2c0 5.4-8 10.4-8 10.4Z" />
          </svg>
        </Link>
      </nav>
    </header>
  );
}
