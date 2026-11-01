import { NextResponse } from 'next/server';
export function fail(message:string,status=400){return NextResponse.json({error:message},{status,headers:{'Cache-Control':'no-store'}})}
export function ok(data:unknown){return NextResponse.json(data,{headers:{'Cache-Control':'no-store'}})}
export function errorResponse(error:unknown){ const message=error instanceof Error ? error.message : 'Unexpected error'; return fail(message, message.includes('configured')?503:400); }
