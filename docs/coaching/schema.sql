-- Crux coaching backend, v1 (Supabase / Postgres). See DESIGN.md.
-- DRAFT: written 2026-10-04 and not yet run against a database. Apply to a fresh Supabase
-- project in the SQL editor, then run the checks at the bottom as two different test users.
--
-- Principles:
--   * Row Level Security on every table. The page is never trusted to hide data.
--   * Coaches never read athlete tables directly. They go through coach_view_* functions that
--     check for an active connection and build each row from an ALLOW-LIST of fields for the
--     scopes the athlete granted. A field Crux adds later is not shared until it's added here.
--   * Connections are only created or changed through functions (invite, accept, scopes, end).
--   * No messaging. The only free text is a coach note (template or assignment) and one
--     athlete note on a workout result.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- types
create type public.share_scope as enum ('sessions', 'projects', 'effort', 'notes');
--   sessions: dates, gyms, duration, results per attempt, timer used, how it felt
--   projects: climb names, project ids, grades, grade type
--   effort:   RPE and fall reasons
--   notes:    session and attempt notes (off by default)
create type public.connection_status as enum ('pending', 'active', 'ended');
create type public.assignment_status as enum ('assigned', 'completed', 'skipped', 'withdrawn');

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  display_name  text not null check (char_length(display_name) between 1 and 60),
  is_coach      boolean not null default false,
  coach_gym     text check (char_length(coach_gym) <= 80),
  coach_adult_confirmed_at timestamptz,          -- coach ticked "I'm 18 or older"
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------- connections
create table public.coach_connections (
  id                 uuid primary key default gen_random_uuid(),
  athlete_id         uuid not null references public.profiles on delete cascade,
  coach_id           uuid references public.profiles on delete cascade,  -- null until accepted
  status             public.connection_status not null default 'pending',
  scopes             public.share_scope[] not null default '{sessions,projects,effort}',
  invite_code_hash   text unique,          -- sha256 of the code; the code itself is never stored
  invite_expires_at  timestamptz,
  created_at         timestamptz not null default now(),
  accepted_at        timestamptz,
  ended_at           timestamptz,
  check (coach_id is null or coach_id <> athlete_id)
);
create unique index coach_connections_one_live
  on public.coach_connections (athlete_id, coach_id) where status = 'active';

-- ---------------------------------------------------------------- the athlete's own data
-- Sessions are stored exactly as Crux keeps them (attempts included), keyed by Crux's own id.
create table public.training_sessions (
  athlete_id   uuid not null references public.profiles on delete cascade,
  id           text not null,
  started_at   timestamptz not null,
  ended_at     timestamptz,
  location     text,
  data         jsonb not null,
  assignment_id uuid,                      -- set when the session ran an assigned workout
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,
  primary key (athlete_id, id)
);
create table public.training_projects (
  athlete_id   uuid not null references public.profiles on delete cascade,
  id           text not null,
  name         text not null,
  location     text not null default '',
  updated_at   timestamptz not null default now(),
  primary key (athlete_id, id)
);

-- ---------------------------------------------------------------- workouts
-- kind 'workout': body = {steps:[...]}
-- kind 'block':   body = {workouts:[{day:1, title, coachNote?, steps:[...]}, ...]}
-- Step types (DESIGN.md section 5): timed | intervals | climbs | task
create table public.workout_templates (
  id          uuid primary key default gen_random_uuid(),
  coach_id    uuid not null references public.profiles on delete cascade,
  kind        text not null check (kind in ('workout', 'block')),
  title       text not null check (char_length(title) between 1 and 80),
  coach_note  text check (char_length(coach_note) <= 1000),
  body        jsonb not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- One row per workout sent. Sending several at once, or a block, creates several rows that share
-- group_id. steps is a frozen copy: editing the template later never changes what was sent.
create table public.workout_assignments (
  id             uuid primary key default gen_random_uuid(),
  connection_id  uuid not null references public.coach_connections on delete cascade,
  coach_id       uuid not null references public.profiles on delete cascade,
  athlete_id     uuid not null references public.profiles on delete cascade,
  template_id    uuid references public.workout_templates on delete set null,
  group_id       uuid,
  group_title    text check (char_length(group_title) <= 80),
  title          text not null check (char_length(title) between 1 and 80),
  steps          jsonb not null check (jsonb_typeof(steps) = 'array'),
  coach_note     text check (char_length(coach_note) <= 1000),
  scheduled_for  date,
  status         public.assignment_status not null default 'assigned',
  created_at     timestamptz not null default now()
);
create index workout_assignments_athlete on public.workout_assignments (athlete_id, scheduled_for);

create table public.workout_results (
  assignment_id  uuid primary key references public.workout_assignments on delete cascade,
  athlete_id     uuid not null references public.profiles on delete cascade,
  session_id     text,                      -- the Crux session it was done in
  completed_at   timestamptz not null default now(),
  steps          jsonb not null,            -- per step: {done|skipped, roundsDone?, attempts?}
  rpe            smallint check (rpe between 1 and 10),
  athlete_note   text check (char_length(athlete_note) <= 500)
);

-- ---------------------------------------------------------------- helpers
-- Scopes the calling coach currently holds for an athlete (empty when not actively connected).
create function public.coach_scopes_for(p_athlete uuid) returns public.share_scope[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(distinct s), '{}')
  from public.coach_connections c, unnest(c.scopes) s
  where c.athlete_id = p_athlete and c.coach_id = auth.uid() and c.status = 'active';
$$;

create function public.is_active_coach_of(p_athlete uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.coach_connections c
                 where c.athlete_id = p_athlete and c.coach_id = auth.uid() and c.status = 'active');
$$;

-- The allow-list. Builds a coach-safe copy of one Crux session for the given scopes.
create function public.filter_session(d jsonb, s public.share_scope[]) returns jsonb
language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', d->'id', 'startedAt', d->'startedAt', 'endedAt', d->'endedAt',
    'location', d->'location', 'timerConfig', d->'timerConfig', 'satisfaction', d->'satisfaction',
    'note', case when 'notes' = any(s) then d->'note' end,
    'attempts', coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'id', a->'id', 'result', a->'result', 'ts', a->'ts',
        'climbName', case when 'projects' = any(s) then a->'climbName' end,
        'projectId', case when 'projects' = any(s) then a->'projectId' end,
        'grade',     case when 'projects' = any(s) then a->'grade' end,
        'gradeType', case when 'projects' = any(s) then a->'gradeType' end,
        'effort',    case when 'effort'   = any(s) then a->'effort' end,
        'reason',    case when 'effort'   = any(s) then a->'reason' end,
        'note',      case when 'notes'    = any(s) then a->'note' end
      )))
      from jsonb_array_elements(coalesce(d->'attempts', '[]'::jsonb)) a
    ), '[]'::jsonb)
  ));
$$;

-- ---------------------------------------------------------------- coach read functions
create function public.coach_view_sessions(p_athlete uuid, p_since timestamptz default now() - interval '120 days')
returns table (id text, started_at timestamptz, ended_at timestamptz, location text, data jsonb, assignment_id uuid)
language plpgsql stable security definer set search_path = public as $$
declare s public.share_scope[] := public.coach_scopes_for(p_athlete);
begin
  if not ('sessions' = any(s)) then return; end if;
  return query
    select t.id, t.started_at, t.ended_at, t.location, public.filter_session(t.data, s), t.assignment_id
    from public.training_sessions t
    where t.athlete_id = p_athlete and not t.deleted and t.started_at >= p_since
    order by t.started_at desc;
end $$;

create function public.coach_view_projects(p_athlete uuid)
returns table (id text, name text, location text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not ('projects' = any(public.coach_scopes_for(p_athlete))) then return; end if;
  return query select p.id, p.name, p.location from public.training_projects p where p.athlete_id = p_athlete;
end $$;

-- ---------------------------------------------------------------- connection functions
-- Athlete: make a single-use invite. Returns the code (shown once, never stored).
create function public.create_coach_invite(p_scopes public.share_scope[] default '{sessions,projects,effort}')
returns text language plpgsql volatile security definer set search_path = public as $$
declare raw text := upper(encode(gen_random_bytes(6), 'hex'));   -- 48 bits, 12 hex chars
        code text := substr(raw,1,4) || '-' || substr(raw,5,4) || '-' || substr(raw,9,4);
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  insert into public.coach_connections (athlete_id, scopes, invite_code_hash, invite_expires_at)
  values (auth.uid(), p_scopes, encode(digest(code, 'sha256'), 'hex'), now() + interval '7 days');
  return code;
end $$;

-- Coach: accept an invite. Fails unless the caller is a coach who confirmed they're an adult.
create function public.accept_coach_invite(p_code text)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare c public.coach_connections;
begin
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_coach and p.coach_adult_confirmed_at is not null)
    then raise exception 'turn on your coach profile first'; end if;
  select * into c from public.coach_connections
   where invite_code_hash = encode(digest(upper(trim(p_code)), 'sha256'), 'hex')
     and status = 'pending' and invite_expires_at > now()
   for update;
  if c.id is null then raise exception 'that code is not valid or has expired'; end if;
  if c.athlete_id = auth.uid() then raise exception 'you cannot coach yourself'; end if;
  if exists (select 1 from public.coach_connections x
             where x.athlete_id = c.athlete_id and x.coach_id = auth.uid() and x.status = 'active')
    then raise exception 'you are already connected to this athlete'; end if;  -- (raising rolls back; the invite stays pending)
  update public.coach_connections
     set coach_id = auth.uid(), status = 'active', accepted_at = now(), invite_code_hash = null
   where id = c.id;
  return c.id;
end $$;

-- Athlete: change what a connected (or pending) coach can see. Takes effect on the coach's next read.
create function public.set_coach_scopes(p_connection uuid, p_scopes public.share_scope[])
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update public.coach_connections set scopes = p_scopes
   where id = p_connection and athlete_id = auth.uid() and status <> 'ended';
  if not found then raise exception 'connection not found'; end if;
end $$;

-- Either side: end the connection now. The athlete keeps every assignment and result; the coach
-- loses access to all of it (the policies below require an active connection).
create function public.end_coach_connection(p_connection uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update public.coach_connections
     set status = 'ended', ended_at = now(), invite_code_hash = null
   where id = p_connection and status <> 'ended' and (athlete_id = auth.uid() or coach_id = auth.uid());
  if not found then raise exception 'connection not found'; end if;
end $$;

-- Athlete: record how an assigned workout went (once per assignment; re-recording replaces it).
create function public.record_workout_result(p_assignment uuid, p_session text, p_steps jsonb,
                                             p_rpe smallint default null, p_note text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not exists (select 1 from public.workout_assignments a
                 where a.id = p_assignment and a.athlete_id = auth.uid() and a.status <> 'withdrawn')
    then raise exception 'assignment not found'; end if;
  insert into public.workout_results (assignment_id, athlete_id, session_id, steps, rpe, athlete_note)
  values (p_assignment, auth.uid(), p_session, p_steps, p_rpe, left(p_note, 500))
  on conflict (assignment_id) do update
    set session_id = excluded.session_id, steps = excluded.steps, rpe = excluded.rpe,
        athlete_note = excluded.athlete_note, completed_at = now();
  update public.workout_assignments set status = 'completed' where id = p_assignment;
end $$;

create function public.skip_workout(p_assignment uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update public.workout_assignments set status = 'skipped'
   where id = p_assignment and athlete_id = auth.uid() and status = 'assigned';
  if not found then raise exception 'assignment not found'; end if;
end $$;

-- ---------------------------------------------------------------- row level security
alter table public.profiles            enable row level security;
alter table public.coach_connections   enable row level security;
alter table public.training_sessions   enable row level security;
alter table public.training_projects   enable row level security;
alter table public.workout_templates   enable row level security;
alter table public.workout_assignments enable row level security;
alter table public.workout_results     enable row level security;

-- profiles: yourself, plus the other side of an active connection (to show their name)
create policy profiles_read on public.profiles for select using (
  id = auth.uid() or exists (
    select 1 from public.coach_connections c where c.status = 'active'
      and ((c.athlete_id = auth.uid() and c.coach_id = profiles.id)
        or (c.coach_id = auth.uid() and c.athlete_id = profiles.id))));
create policy profiles_insert on public.profiles for insert with check (id = auth.uid());
create policy profiles_update on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- connections: read-only to the two people in them; all changes go through the functions above
create policy connections_read on public.coach_connections for select
  using (athlete_id = auth.uid() or coach_id = auth.uid());

-- the athlete's own data: only the athlete (coaches use coach_view_*)
create policy sessions_own on public.training_sessions for all
  using (athlete_id = auth.uid()) with check (athlete_id = auth.uid());
create policy projects_own on public.training_projects for all
  using (athlete_id = auth.uid()) with check (athlete_id = auth.uid());

-- templates: the coach's own library
create policy templates_own on public.workout_templates for all
  using (coach_id = auth.uid()) with check (coach_id = auth.uid());

-- assignments: the athlete always; the coach only while actively connected
create policy assignments_athlete_read on public.workout_assignments for select
  using (athlete_id = auth.uid());
create policy assignments_coach_read on public.workout_assignments for select
  using (coach_id = auth.uid() and public.is_active_coach_of(athlete_id));
create policy assignments_coach_insert on public.workout_assignments for insert with check (
  coach_id = auth.uid() and exists (
    select 1 from public.coach_connections c
    where c.id = connection_id and c.coach_id = auth.uid() and c.athlete_id = workout_assignments.athlete_id
      and c.status = 'active'));
-- a coach may edit or withdraw an assignment that hasn't been done yet
create policy assignments_coach_update on public.workout_assignments for update
  using (coach_id = auth.uid() and status = 'assigned' and public.is_active_coach_of(athlete_id))
  with check (coach_id = auth.uid() and status in ('assigned', 'withdrawn'));

-- results: the athlete always; the coach of that assignment while actively connected
create policy results_athlete_read on public.workout_results for select
  using (athlete_id = auth.uid());
create policy results_coach_read on public.workout_results for select using (
  exists (select 1 from public.workout_assignments a
          where a.id = assignment_id and a.coach_id = auth.uid() and public.is_active_coach_of(a.athlete_id)));

-- functions: callable by signed-in users only
revoke all on function public.coach_scopes_for, public.is_active_coach_of, public.filter_session,
  public.coach_view_sessions, public.coach_view_projects, public.create_coach_invite,
  public.accept_coach_invite, public.set_coach_scopes, public.end_coach_connection,
  public.record_workout_result, public.skip_workout from public, anon;
grant execute on function public.coach_view_sessions, public.coach_view_projects, public.create_coach_invite,
  public.accept_coach_invite, public.set_coach_scopes, public.end_coach_connection,
  public.record_workout_result, public.skip_workout to authenticated;
-- coach_scopes_for, is_active_coach_of and filter_session are used inside policies/functions;
-- they need to be executable by authenticated too because policies run as the caller.
grant execute on function public.coach_scopes_for, public.is_active_coach_of, public.filter_session to authenticated;

-- ---------------------------------------------------------------- checks to run after applying
-- As athlete A:  select create_coach_invite();                      -> code
-- As coach C (is_coach + adult confirmed):  select accept_coach_invite('<code>');
-- As coach C:    select * from coach_view_sessions('<A id>');       -> rows, no 'note' keys
-- As coach C:    select * from training_sessions;                  -> 0 rows (RLS)
-- As coach D (not connected): select * from coach_view_sessions('<A id>');  -> 0 rows
-- As athlete A:  select set_coach_scopes('<conn>', '{sessions}');   then C sees no grade/effort keys
-- As athlete A:  select end_coach_connection('<conn>');             then C sees nothing, incl. results
