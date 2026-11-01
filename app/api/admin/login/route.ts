import { NextRequest } from 'next/server';
import { clearAdmin, isAdmin, safeEqual, setAdmin } from '@/lib/security';
import { fail, ok } from '@/lib/http';
export const dynamic='force-dynamic';
export async function GET(){return ok({authenticated:await isAdmin()})}
export async function POST(request:NextRequest){
  const password=process.env.ADMIN_PASSWORD;
  if(!password) return fail('Admin login is not configured',503);
  const body=await request.json().catch(()=>({}));
  if(typeof body.password!=='string'||!safeEqual(body.password,password)) { await new Promise(r=>setTimeout(r,450)); return fail('Incorrect password',401); }
  await setAdmin(); return ok({authenticated:true});
}
export async function DELETE(){await clearAdmin();return ok({authenticated:false})}
