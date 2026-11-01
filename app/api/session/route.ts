import { NextRequest } from 'next/server';
import { rpc } from '@/lib/db';
import { clearPlayer, clearRun, hashToken, newToken, playerHash, setPlayer } from '@/lib/security';
import { errorResponse, fail, ok } from '@/lib/http';
export const dynamic='force-dynamic';

export async function GET() {
  try {
    await clearRun();
    const hash=await playerHash();
    if (!hash) return ok({participant:null});
    const participant=await rpc('challenge_status',{p_token_hash:hash});
    if (!participant) await clearPlayer();
    return ok({participant});
  } catch(e) { return errorResponse(e); }
}
export async function POST(request:NextRequest) {
  try {
    if (Number(request.headers.get('content-length')||0)>2048) return fail('Request too large',413);
    const existing=await playerHash();
    if(existing) { const participant=await rpc('challenge_status',{p_token_hash:existing}); if(participant) return ok({participant}); }
    const {name,enrollment}=await request.json();
    if(typeof name!=='string'||typeof enrollment!=='string'||!currentName(name)||!currentEnrollment(enrollment)) return fail('Enter a valid name and enrollment number');
    const token=newToken();
    const participant=await rpc('challenge_register',{p_name:name,p_enrollment:enrollment,p_token_hash:hashToken(token)});
    await setPlayer(token);
    return ok({participant});
  } catch(e) { return errorResponse(e); }
}
function currentName(v:string) {return /^[A-Za-z][A-Za-z .'-]{1,59}$/.test(v.trim())}
function currentEnrollment(v:string) {return /^[A-Za-z0-9][A-Za-z0-9/_-]{2,31}$/.test(v.trim())}
