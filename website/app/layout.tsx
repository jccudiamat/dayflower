import type { Metadata } from "next";
import { Quicksand, Lora } from "next/font/google";
import "./globals.css";
import { connection } from "next/server";

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
  metadataBase: new URL("https://mydayflower.com"),
  title: "Dayflower | One flower a day, across any distance",
  description:
    "A private app for exactly two people. Somewhere to land on each other every day when you can't be in the same room. Join the waitlist.",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  // Nonces are unique to a request, so HTML must never be prerendered/cached.
  await connection();
  return (
    <html lang="en" className={`${quicksand.variable} ${lora.variable} antialiased`}>
      <body>{children}</body>
    </html>
  );
}
