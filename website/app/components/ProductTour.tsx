import { ChatSnapshot } from "./Snapshots";
import Link from "next/link";
import "./snapshots.css";

export default function ProductTour() {
  return <section id="app" className="home-app" aria-labelledby="app-title"><div className="home-app-inner">
    <div className="home-app-copy"><p className="home-eyebrow">THE DAYFLOWER APP · IN PRIVATE TESTING</p><h2 id="app-title">A space that belongs<br /><span>to the two of you.</span></h2><p>Stay part of each other’s ordinary days. Dayflower brings your conversations, check-ins, memories, and plans into one shared space for you and your partner.</p>
      <div className="home-app-features">
        <article id="connection"><h3>Keep the conversation close</h3><p>Messages, illustrated flowers, personal notes, and voice and video calls.</p></article>
        <article id="check-ins"><h3>Be part of their day</h3><p>My Day photos, mood check-ins, heartbeats, and your partner’s local time.</p></article>
        <article id="plans"><h3>Plan a little life together</h3><p>Important dates, reunion countdowns, reminders, finances, and monthly Chapters.</p></article>
        <article id="widgets"><h3>Keep the little things nearby</h3><p>Photo keepsakes in the app and Android home-screen widgets for shared moments.</p></article>
      </div><Link href="/#waitlist" className="home-app-link">Join the app waitlist <span aria-hidden="true">↗</span></Link>
    </div><figure className="home-app-preview"><div aria-hidden="true"><ChatSnapshot /></div><figcaption>App preview · illustrative sample content</figcaption></figure>
  </div></section>;
}
