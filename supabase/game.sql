-- Isolated game storage. Run on the selected Supabase project.
create schema if not exists game_private;
create table if not exists game_private.settings (
  id int primary key default 1 check (id = 1),
  event_id uuid not null default gen_random_uuid(),
  max_attempts int not null default 1 check (max_attempts between 1 and 20),
  api_secret text not null default encode(gen_random_bytes(32), 'hex')
);
insert into game_private.settings(id) values (1) on conflict (id) do nothing;
create table if not exists game_private.participants (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null,
  name text not null check (char_length(name) between 2 and 60),
  enrollment text not null check (char_length(enrollment) between 3 and 32),
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  unique(event_id,enrollment)
);
create table if not exists game_private.attempts (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null,
  participant_id uuid not null references game_private.participants(id),
  elapsed_ms int not null check (elapsed_ms between 1 and 120000),
  difference_ms int generated always as (abs(elapsed_ms - 3000)) stored,
  created_at timestamptz not null default now()
);
create index if not exists attempts_event_participant_idx on game_private.attempts(event_id,participant_id,difference_ms);
create index if not exists attempts_event_score_idx on game_private.attempts(event_id,difference_ms,created_at);
revoke all on schema game_private from public, anon, authenticated;
revoke all on all tables in schema game_private from public, anon, authenticated;

create or replace function public.challenge_register(p_secret text,p_name text,p_enrollment text,p_token_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s game_private.settings%rowtype; p game_private.participants%rowtype;
begin
 select * into s from game_private.settings where id=1;
 if p_secret is distinct from s.api_secret then raise exception 'Access denied'; end if;
 p_name := btrim(regexp_replace(coalesce(p_name,''),'\s+',' ','g'));
 p_enrollment := upper(btrim(coalesce(p_enrollment,'')));
 if p_name !~ '^[[:alpha:]][[:alpha:] .''-]{1,59}$' or p_enrollment !~ '^[A-Z0-9][A-Z0-9/_-]{2,31}$' or p_token_hash !~ '^[a-f0-9]{64}$' then raise exception 'Enter a valid name and enrollment number'; end if;
 insert into game_private.participants(event_id,name,enrollment,token_hash)
 values(s.event_id,p_name,p_enrollment,p_token_hash) returning * into p;
 return jsonb_build_object('name',p.name,'remaining',s.max_attempts,'maxAttempts',s.max_attempts,'attempts',0);
exception when unique_violation then raise exception 'This enrollment number is already registered for this event';
end $$;

create or replace function public.challenge_status(p_secret text,p_token_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s game_private.settings%rowtype; p game_private.participants%rowtype; n int; best record;
begin
 select * into s from game_private.settings where id=1;
 if p_secret is distinct from s.api_secret then raise exception 'Access denied'; end if;
 select * into p from game_private.participants where event_id=s.event_id and token_hash=p_token_hash;
 if not found then return null; end if;
 select count(*) into n from game_private.attempts where participant_id=p.id and event_id=s.event_id;
 select elapsed_ms,difference_ms into best from game_private.attempts where participant_id=p.id and event_id=s.event_id order by difference_ms,created_at limit 1;
 return jsonb_build_object('name',p.name,'enrollment',p.enrollment,'remaining',greatest(0,s.max_attempts-n),'maxAttempts',s.max_attempts,'attempts',n,'bestMs',best.elapsed_ms,'bestDifferenceMs',best.difference_ms);
end $$;

create or replace function public.challenge_submit(p_secret text,p_token_hash text,p_elapsed_ms int)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s game_private.settings%rowtype; p game_private.participants%rowtype; n int; a game_private.attempts%rowtype;
begin
 select * into s from game_private.settings where id=1;
 if p_secret is distinct from s.api_secret then raise exception 'Access denied'; end if;
 if p_elapsed_ms is null or p_elapsed_ms < 1 or p_elapsed_ms > 120000 then raise exception 'Invalid time'; end if;
 select * into p from game_private.participants where event_id=s.event_id and token_hash=p_token_hash for update;
 if not found then raise exception 'Registration not found'; end if;
 select count(*) into n from game_private.attempts where participant_id=p.id and event_id=s.event_id;
 if n >= s.max_attempts then raise exception 'No attempts remaining'; end if;
 insert into game_private.attempts(event_id,participant_id,elapsed_ms) values(s.event_id,p.id,p_elapsed_ms) returning * into a;
 return jsonb_build_object('elapsedMs',a.elapsed_ms,'differenceMs',a.difference_ms,'remaining',s.max_attempts-n-1,'attempts',n+1,'maxAttempts',s.max_attempts);
end $$;

create or replace function public.challenge_leaderboard(p_secret text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s game_private.settings%rowtype;
begin
 select * into s from game_private.settings where id=1;
 if p_secret is distinct from s.api_secret then raise exception 'Access denied'; end if;
 return coalesce((select jsonb_agg(row_data order by difference_ms, created_at) from (
  select jsonb_build_object('name',p.name,'elapsedMs',a.elapsed_ms,'differenceMs',a.difference_ms,'createdAt',a.created_at) as row_data,a.difference_ms,a.created_at
  from game_private.participants p
  join lateral (select * from game_private.attempts where participant_id=p.id and event_id=s.event_id order by difference_ms,created_at limit 1) a on true
  where p.event_id=s.event_id order by a.difference_ms,a.created_at limit 100
 ) ranked),'[]'::jsonb);
end $$;

create or replace function public.challenge_admin_snapshot(p_secret text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s game_private.settings%rowtype;
begin
 select * into s from game_private.settings where id=1;
 if p_secret is distinct from s.api_secret then raise exception 'Access denied'; end if;
 return jsonb_build_object('maxAttempts',s.max_attempts,'eventId',s.event_id,
  'participants',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'enrollment',p.enrollment,'createdAt',p.created_at,'attempts',coalesce((select jsonb_agg(jsonb_build_object('elapsedMs',a.elapsed_ms,'differenceMs',a.difference_ms,'createdAt',a.created_at) order by a.created_at) from game_private.attempts a where a.participant_id=p.id and a.event_id=s.event_id),'[]'::jsonb)) order by p.created_at) from game_private.participants p where p.event_id=s.event_id),'[]'::jsonb));
end $$;

create or replace function public.challenge_configure(p_secret text,p_max_attempts int)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if p_secret is distinct from (select api_secret from game_private.settings where id=1) then raise exception 'Access denied'; end if;
 if p_max_attempts not between 1 and 20 then raise exception 'Attempts must be between 1 and 20'; end if;
 update game_private.settings set max_attempts=p_max_attempts where id=1;
 return jsonb_build_object('maxAttempts',p_max_attempts);
end $$;

create or replace function public.challenge_reset(p_secret text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare new_event uuid := gen_random_uuid();
begin
 if p_secret is distinct from (select api_secret from game_private.settings where id=1) then raise exception 'Access denied'; end if;
 update game_private.settings set event_id=new_event where id=1;
 return jsonb_build_object('eventId',new_event);
end $$;

revoke all on function public.challenge_register(text,text,text,text), public.challenge_status(text,text), public.challenge_submit(text,text,int), public.challenge_leaderboard(text), public.challenge_admin_snapshot(text), public.challenge_configure(text,int), public.challenge_reset(text) from public;
grant execute on function public.challenge_register(text,text,text,text), public.challenge_status(text,text), public.challenge_submit(text,text,int), public.challenge_leaderboard(text), public.challenge_admin_snapshot(text), public.challenge_configure(text,int), public.challenge_reset(text) to anon;
