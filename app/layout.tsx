import type { Metadata } from 'next';
import './globals.css';
import './handoff.css';
import './ieee-brand.css';
export const metadata: Metadata = { title: 'The 3-Second Challenge | Tech Club', description: 'Start. Stop. Conquer. The Tech Club timing challenge.' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }
