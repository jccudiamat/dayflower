import Image from "next/image";
import Link from "next/link";

export default function SiteHeader({ photobooth = false, bouquet = false }: { photobooth?: boolean; bouquet?: boolean }) {
  return <header className="site-header"><nav aria-label="Main navigation" className="site-nav">
    <Link href="/" aria-label="Dayflower home" className="site-brand"><Image src="/mark.png" alt="" width={28} height={28} />Dayflower</Link>
    <div className="site-nav-secondary"><Link href="/bouquet" aria-current={bouquet ? "page" : undefined}>Bouquet</Link><Link href="/photobooth" aria-current={photobooth ? "page" : undefined}>Booth</Link><Link href="/gifts">Gifts</Link><Link href="/journal">Journal</Link></div>
    <Link href="/#waitlist" className="site-waitlist-link">Join the waitlist</Link>
  </nav></header>;
}
