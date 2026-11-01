-- Existing projects may contain historic shorter enrollments. Keep those rows;
-- NOT VALID still enforces exactly 11 characters for every new registration.
do $$
begin
 if not exists (
  select 1 from pg_constraint
  where conrelid = 'game_private.participants'::regclass
    and conname = 'participants_enrollment_11_check'
 ) then
  alter table game_private.participants
    add constraint participants_enrollment_11_check
    check (char_length(enrollment) = 11) not valid;
 end if;
end $$;

create or replace function public.challenge_register(p_secret text,p_name text,p_enrollment text,p_token_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s game_private.settings%rowtype; p game_private.participants%rowtype;
begin
 select * into s from game_private.settings where id=1;
 if p_secret is distinct from s.api_secret then raise exception 'Access denied'; end if;
 p_name := btrim(regexp_replace(coalesce(p_name,''),'\s+',' ','g'));
 p_enrollment := upper(btrim(coalesce(p_enrollment,'')));
 if char_length(p_enrollment) <> 11 then raise exception 'Enrollment number must be exactly 11 characters'; end if;
 if p_name !~ '^[[:alpha:]][[:alpha:] .''-]{1,59}$' or p_enrollment !~ '^[A-Z0-9][A-Z0-9/_-]{10}$' or p_token_hash !~ '^[a-f0-9]{64}$' then raise exception 'Enter a valid name and enrollment number'; end if;
 insert into game_private.participants(event_id,name,enrollment,token_hash)
 values(s.event_id,p_name,p_enrollment,p_token_hash) returning * into p;
 return jsonb_build_object('name',p.name,'remaining',s.max_attempts,'maxAttempts',s.max_attempts,'attempts',0);
exception when unique_violation then raise exception 'This enrollment number is already registered for this event';
end $$;
