import { NextRequest } from 'next/server';
import { rpc } from '@/lib/db';
import { clearRun, getRun, playerHash, setRun } from '@/lib/security';
import { errorResponse, fail, ok } from '@/lib/http';
export const dynamic='force-dynamic';
export async function POST(request:NextRequest){
  try{
    const hash=await playerHash(); if(!hash) return fail('Register before playing',401);
    const {action,elapsedMs}=await request.json();
    if(action==='start'){
      const participant=await rpc<{remaining:number}|null>('challenge_status',{p_token_hash:hash});
      if(!participant) return fail('Registration expired. Register again.',401);
      if(participant.remaining<=0) return fail('No attempts remaining',409);
      const existing=await getRun();
      if(existing && Date.now()-existing<120000) return fail('A timer is already running',409);
      await setRun(Date.now()); return ok({started:true});
    }
    if(action==='cancel'){await clearRun();return ok({cancelled:true})}
    if(action==='stop'){
      const started=await getRun();
      if(!started) return fail('Start the timer first',409);
      await clearRun();
      if(!Number.isInteger(elapsedMs)||elapsedMs<1||elapsedMs>120000) return fail('Invalid time');
      const serverElapsed=Date.now()-started;
      if(serverElapsed<200 || serverElapsed>125000 || Math.abs(serverElapsed-elapsedMs)>5000) return fail('Timer interrupted. Please try again.');
      const result=await rpc('challenge_submit',{p_token_hash:hash,p_elapsed_ms:elapsedMs});
      return ok({result});
    }
    return fail('Unknown action');
  }catch(e){return errorResponse(e)}
}
