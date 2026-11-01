import { NextRequest } from 'next/server';
import { rpc } from '@/lib/db';
import { isAdmin } from '@/lib/security';
import { errorResponse, fail, ok } from '@/lib/http';
export async function POST(request:NextRequest){
  if(!await isAdmin()) return fail('Admin sign-in required',401);
  try{const {confirmation}=await request.json();if(confirmation!=='RESET') return fail('Type RESET to start a new event');return ok(await rpc('challenge_reset'))}catch(e){return errorResponse(e)}
}
