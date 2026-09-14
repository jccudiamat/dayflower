"use client";

import Script from "next/script";
import { useEffect, useRef, useState } from "react";

type Turnstile = {
  render: (element: HTMLElement, options: Record<string, unknown>) => string;
  remove: (id: string) => void;
};
declare global { interface Window { turnstile?: Turnstile } }

export default function DeliveryCheck({ onToken }: { onToken: (token: string) => void }) {
  const host = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState("");
  const sitekey = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY;
  useEffect(() => {
    if (!ready || !sitekey || !host.current || !window.turnstile) return;
    const api = window.turnstile;
    const id = api.render(host.current, {
      sitekey, action: "gift-email", theme: "light", size: "flexible",
      callback: (token: string) => { setError(""); onToken(token); },
      "expired-callback": () => onToken(""),
      "timeout-callback": () => onToken(""),
      "error-callback": () => { onToken(""); setError("Verification could not load. Check your connection and retry."); },
    });
    return () => { api.remove(id); onToken(""); };
  }, [ready, sitekey, onToken]);
  return <div className="bouquet-delivery-check">
    {sitekey ? <>
      <Script id="delivery-turnstile" src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
        onReady={() => setReady(true)} onError={() => { onToken(""); setError("Verification could not load. Please reload and try again."); }} />
      <div ref={host} />
      {error && <p role="alert">{error}</p>}
    </> : <p role="status">Email delivery is temporarily unavailable. You can still copy your gift link.</p>}
  </div>;
}
