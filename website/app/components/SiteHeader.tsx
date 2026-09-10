import Image from "next/image";
import Link from "next/link";

export default function SiteHeader({ photobooth = false }: { photobooth?: boolean }) {
  return <header className="site-header"><nav aria-label="Main navigation" className="site-nav">
    <Link href="/" aria-label="Dayflower home" className="site-brand"><Image src="/mark.png" alt="" width={28} height={28} />Dayflower</Link>
    <div className="site-nav-secondary"><Link href="/gifts">Gifts</Link><Link href="/journal">Journal</Link><Link href="/#waitlist">Join the waitlist</Link></div>
    <Link href="/photobooth" aria-current={photobooth ? "page" : undefined} className="site-booth-link">Photo booth <span aria-hidden="true">↗</span></Link>
    <details className="site-mobile-menu"><summary aria-label="More navigation"><span aria-hidden="true">☰</span></summary><div className="site-menu-panel"><Link href="/gifts">Browse gifts</Link><Link href="/#waitlist">Join the app waitlist</Link><Link href="/journal">Read the Journal</Link></div></details>
  </nav></header>;
}
