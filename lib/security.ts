import { createHmac, createHash, randomBytes, timingSafeEqual } from 'crypto';
import { cookies } from 'next/headers';

const COOKIE = 'challenge_player';
const ADMIN_COOKIE = 'challenge_admin';
export const newToken = () => randomBytes(32).toString('hex');
export const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');
export const safeEqual = (a: string, b: string) => {
  const aa = Buffer.from(a), bb = Buffer.from(b);
  return aa.length === bb.length && timingSafeEqual(aa, bb);
};
export async function playerHash() {
  const token = (await cookies()).get(COOKIE)?.value;
  return token && /^[a-f0-9]{64}$/.test(token) ? hashToken(token) : null;
}
export async function setPlayer(token: string) { (await cookies()).set(COOKIE, token, { httpOnly:true, secure:process.env.NODE_ENV==='production', sameSite:'lax', path:'/', maxAge:60*60*24*30 }); }
export async function clearPlayer() { (await cookies()).delete(COOKIE); }
function signature(value: string) { const key=process.env.SESSION_SECRET; if (!key) throw new Error('Session secret missing'); return createHmac('sha256', key).update(value).digest('hex'); }
export async function setAdmin() { const payload=String(Date.now()+8*60*60*1000); (await cookies()).set(ADMIN_COOKIE, `${payload}.${signature(payload)}`, {httpOnly:true,secure:process.env.NODE_ENV==='production',sameSite:'strict',path:'/',maxAge:8*60*60}); }
export async function isAdmin() { const raw=(await cookies()).get(ADMIN_COOKIE)?.value; if(!raw) return false; const [payload,sig]=raw.split('.'); return !!payload && !!sig && Number(payload)>Date.now() && safeEqual(sig,signature(payload)); }
export async function clearAdmin() { (await cookies()).delete(ADMIN_COOKIE); }
export async function setRun(startedAt:number) { const value=String(startedAt); (await cookies()).set('challenge_run',`${value}.${signature(value)}`,{httpOnly:true,secure:process.env.NODE_ENV==='production',sameSite:'lax',path:'/',maxAge:180}); }
export async function getRun() { const raw=(await cookies()).get('challenge_run')?.value; if(!raw) return null; const [value,sig]=raw.split('.'); return sig && safeEqual(sig,signature(value)) ? Number(value) : null; }
export async function clearRun() { (await cookies()).delete('challenge_run'); }
