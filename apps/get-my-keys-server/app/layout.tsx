import type { Metadata } from "next";
import { Bebas_Neue, JetBrains_Mono, Noto_Sans_SC } from "next/font/google";

import "./globals.css";

const displayFont = Bebas_Neue({
  variable: "--font-display",
  subsets: ["latin"],
  weight: "400",
});

const bodyFont = Noto_Sans_SC({
  variable: "--font-body",
  subsets: ["latin"],
  weight: ["400", "500", "700"],
});

const monoFont = JetBrains_Mono({
  variable: "--font-mono",
  subsets: ["latin"],
  weight: ["500", "700"],
});

export const metadata: Metadata = {
  title: "Get My Keys",
  description: "Google 登录后生成脱敏展示 Key",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body className={`${displayFont.variable} ${bodyFont.variable} ${monoFont.variable}`}>
        {children}
      </body>
    </html>
  );
}
