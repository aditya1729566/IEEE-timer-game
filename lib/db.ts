export async function rpc<T>(name: string, data: Record<string, unknown> = {}): Promise<T> {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  const secret = process.env.GAME_DB_SECRET;
  if (!url || !key || !secret) throw new Error('Game database is not configured');
  const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: key, Authorization: `Bearer ${key}` },
    body: JSON.stringify({ p_secret: secret, ...data }), cache: 'no-store'
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) throw new Error(body?.message || 'Database request failed');
  return body as T;
}
