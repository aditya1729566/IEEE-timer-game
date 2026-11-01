import { rpc } from '@/lib/db';
import { isAdmin } from '@/lib/security';
import { errorResponse, fail, ok } from '@/lib/http';
export const dynamic='force-dynamic';
export async function GET(){if(!await isAdmin()) return fail('Admin sign-in required',401);try{return ok(await rpc('challenge_admin_snapshot'))}catch(e){return errorResponse(e)}}
