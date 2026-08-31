import type { Metadata } from "next";
import { Quicksand, Lora } from "next/font/google";
import "./globals.css";

const quicksand = Quicksand({
  variable: "--font-quicksand",
  subsets: ["latin"],
});

const lora = Lora({
  variable: "--font-lora",
  subsets: ["latin"],
  style: ["italic", "normal"],
});

export const metadata: Metadata = {
  title: "Dayflower — One flower a day, across any distance",
  description:
    "Dayflower is a private ritual app for long-distance couples. Exchange a daily tulip, send heartbeats, count down to your reunion, and keep each other close — join the waitlist.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${quicksand.variable} ${lora.variable} antialiased`}>
      <body>{children}</body>
    </html>
  );
}
