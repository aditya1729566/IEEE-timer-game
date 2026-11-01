import { NextRequest } from 'next/server';
import { rpc } from '@/lib/db';
import { isAdmin } from '@/lib/security';
import { errorResponse, fail, ok } from '@/lib/http';
export async function POST(request:NextRequest){
  if(!await isAdmin()) return fail('Admin sign-in required',401);
  try{const {maxAttempts}=await request.json();if(!Number.isInteger(maxAttempts)||maxAttempts<1||maxAttempts>20) return fail('Choose 1 to 20 attempts');return ok(await rpc('challenge_configure',{p_max_attempts:maxAttempts}))}catch(e){return errorResponse(e)}
}
