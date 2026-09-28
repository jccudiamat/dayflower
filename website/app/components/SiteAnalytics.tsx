"use client";

import { Analytics } from "@vercel/analytics/next";
import { publicAnalyticsEvent } from "../lib/public-analytics";

export default function SiteAnalytics() {
  return <Analytics beforeSend={publicAnalyticsEvent} />;
}
