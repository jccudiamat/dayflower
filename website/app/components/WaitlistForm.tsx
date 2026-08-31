"use client";

import { useState } from "react";

type Status = "idle" | "loading" | "success" | "error";

export default function WaitlistForm({ dark = false }: { dark?: boolean }) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (status === "loading") return;
    setStatus("loading");
    setMessage("");
    try {
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      if (res.ok) {
        setStatus("success");
      } else {
        // A crashed route can answer with an HTML error page rather than JSON,
        // so never let parsing decide whether we show a useful message.
        const data = await res.json().catch(() => null);
        setStatus("error");
        setMessage(data?.error ?? "Something went wrong. Please try again.");
      }
    } catch {
      setStatus("error");
      setMessage("Something went wrong. Please try again.");
    }
  }

  if (status === "success") {
    return (
      <div
        className={`waitlist-success ${dark ? "waitlist-success-dark" : ""}`}
        role="status"
      >
        <span className="waitlist-success-emoji" aria-hidden>
          🌷
        </span>
        <p className="waitlist-success-title">You&rsquo;re on the list!</p>
        <p className="waitlist-success-note">
          We&rsquo;ll send one email when Dayflower blooms — nothing else.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="waitlist-form" noValidate>
      <div className={`waitlist-row ${dark ? "waitlist-row-dark" : ""}`}>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@example.com"
          aria-label="Email address"
          className="waitlist-input"
          disabled={status === "loading"}
        />
        <button
          type="submit"
          className="gradient-button waitlist-button"
          disabled={status === "loading"}
        >
          {status === "loading" ? "Joining…" : "Join the waitlist"}
        </button>
      </div>
      {status === "error" && (
        <p className="waitlist-error" role="alert">
          {message}
        </p>
      )}
    </form>
  );
}
