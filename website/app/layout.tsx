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
    "A private app for exactly two people — somewhere to land on each other every day when you can't be in the same room. Join the waitlist.",
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
