import { rpc } from '@/lib/db';
import { errorResponse, ok } from '@/lib/http';
export const dynamic='force-dynamic';
export async function GET(){try{return ok({entries:await rpc('challenge_leaderboard')})}catch(e){return errorResponse(e)}}
