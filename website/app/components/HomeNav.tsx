import Image from "next/image";
import Link from "next/link";

export default function HomeNav() {
  return <header className="home-nav home-shell">
    <a className="home-skip" href="#main-content">Skip to content</a>
    <nav aria-label="Main navigation">
      <Link href="/" className="home-brand" aria-label="Dayflower home"><Image src="/mark.png" alt="" width={30} height={30} />Dayflower</Link>
      <div className="home-nav-links"><Link href="/bouquet">Bouquet</Link><Link href="/photobooth">Photo booth</Link><Link href="/gifts">Gift ideas</Link><Link href="/journal">Journal</Link></div>
      <Link href="/#app" className="home-nav-app">The app <span>Coming soon</span></Link>
    </nav>
  </header>;
}
