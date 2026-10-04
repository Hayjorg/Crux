-- Crux coaching backend, v1 (Supabase / Postgres). Revision 2, 2026-10-04. See DESIGN.md.
-- DRAFT: not yet run against a database. Apply to a fresh Supabase project in the SQL editor,
-- then run the checks at the bottom as different test users.
--
-- Principles:
--   * Row Level Security on every table. The page is never trusted to hide data.
--   * Coach access hangs off ONE specific connection being active. Disconnecting removes access
--     to everything created under it (blocks, assignments, results). Reconnecting later is a new
--     connection, and nothing from the old one comes back.
--   * Coaches never read the athlete's tables directly. coach_view_* functions build each row
--     from an ALLOW-LIST of fields for that connection's scopes, so a field Crux adds later is
--     private until it's deliberately added here.
--   * Assignments are frozen snapshots of a template. Blocks and assignments are only created
--     through functions, which do the snapshotting. A coach may then change only the note, the
--     date, or withdraw (column-level grants), and only until a result exists.
--   * No messaging, enforced by the shape of the schema: there are no message, comment or thread
--     tables. The only free text is one coach_note on a template, block or assignment, and one
--     athlete_note on a result. There are no replies.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- types
create type public.share_scope as enum
  ('sessions', 'projects', 'attempts', 'effort', 'fall_reasons', 'notes', 'photos');
--   sessions      session summaries: date, gym, duration, flash/send/fall counts, timer, how it felt
--   projects      projects and grades: names, gyms, grades, attempts/sends per project
--   attempts      each attempt's result and time
--   effort        RPE per attempt
--   fall_reasons  why each fall happened
--   notes         session/attempt notes            (off by default)
--   photos        photos/videos (reserved; nothing is served until photo storage exists; off by default)
create type public.connection_status as enum ('pending', 'active', 'ended');
create type public.assignment_status as enum ('assigned', 'completed', 'skipped', 'withdrawn');
create type public.block_status      as enum ('active', 'withdrawn');

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  display_name  text not null check (char_length(display_name) between 1 and 60),
  is_coach      boolean not null default false,
  coach_gym     text check (char_length(coach_gym) <= 80),
  coach_adult_confirmed_at timestamptz,          -- the coach ticked "I'm 18 or older"
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------- connections (many-to-many)
create table public.coach_connections (
  id                 uuid primary key default gen_random_uuid(),
  athlete_id         uuid not null references public.profiles on delete cascade,
  coach_id           uuid references public.profiles on delete cascade,  -- null until accepted
  status             public.connection_status not null default 'pending',
  scopes             public.share_scope[] not null
                       default '{sessions,projects,attempts,effort,fall_reasons}',
  history_from       timestamptz,          -- null = all history; else only sessions from this time
  invite_code_hash   text unique,          -- sha256 of the code; the code itself is never stored
  invite_expires_at  timestamptz,
  created_at         timestamptz not null default now(),
  accepted_at        timestamptz,
  ended_at           timestamptz,
  check (coach_id is null or coach_id <> athlete_id)
);
-- many coaches per athlete and many athletes per coach, but one ACTIVE link per pair
create unique index coach_connections_one_active
  on public.coach_connections (athlete_id, coach_id) where status = 'active';

-- ---------------------------------------------------------------- the athlete's own data
create table public.training_sessions (
  athlete_id    uuid not null references public.profiles on delete cascade,
  id            text not null,             -- Crux's own session id
  started_at    timestamptz not null,
  ended_at      timestamptz,
  location      text,
  data          jsonb not null,            -- the session exactly as Crux stores it
  assignment_id uuid,                      -- set when the session ran an assigned workout
  updated_at    timestamptz not null default now(),
  deleted       boolean not null default false,
  primary key (athlete_id, id)
);
create table public.training_projects (
  athlete_id  uuid not null references public.profiles on delete cascade,
  id          text not null,
  name        text not null,
  location    text not null default '',
  updated_at  timestamptz not null default now(),
  primary key (athlete_id, id)
);

-- ---------------------------------------------------------------- coach library (templates)
-- workout: the workout document, format v1 (DESIGN.md section 5): {v:1, title, steps:[...]}
create table public.workout_templates (
  id          uuid primary key default gen_random_uuid(),
  coach_id    uuid not null references public.profiles on delete cascade,
  title       text not null check (char_length(title) between 1 and 80),
  coach_note  text check (char_length(coach_note) <= 1000),
  workout     jsonb not null check ((workout->>'v') = '1' and jsonb_typeof(workout->'steps') = 'array'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.block_templates (
  id           uuid primary key default gen_random_uuid(),
  coach_id     uuid not null references public.profiles on delete cascade,
  title        text not null check (char_length(title) between 1 and 80),  -- "Red River Prep: 4 weeks"
  coach_note   text check (char_length(coach_note) <= 1000),
  length_days  int  not null check (length_days between 1 and 366),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
-- A workout template can't be deleted while a block template uses it.
create table public.block_template_items (
  id                   uuid primary key default gen_random_uuid(),
  block_template_id    uuid not null references public.block_templates on delete cascade,
  day_offset           int  not null check (day_offset >= 0),   -- 0 = the block's first day
  workout_template_id  uuid not null references public.workout_templates on delete restrict,
  coach_note           text check (char_length(coach_note) <= 1000)
);

-- ---------------------------------------------------------------- assigned work
-- A training block is a real object: an assigned plan over a date range, holding assignments.
create table public.training_blocks (
  id                 uuid primary key default gen_random_uuid(),
  connection_id      uuid not null references public.coach_connections on delete cascade,
  coach_id           uuid not null references public.profiles on delete cascade,
  athlete_id         uuid not null references public.profiles on delete cascade,
  block_template_id  uuid references public.block_templates on delete set null,  -- where it came from
  title              text not null check (char_length(title) between 1 and 80),
  coach_note         text check (char_length(coach_note) <= 1000),
  start_date         date not null,
  end_date           date not null,
  status             public.block_status not null default 'active',
  created_at         timestamptz not null default now(),
  check (end_date >= start_date)
);

-- One assigned workout: a frozen snapshot. block_id is null for a workout sent on its own.
create table public.workout_assignments (
  id             uuid primary key default gen_random_uuid(),
  connection_id  uuid not null references public.coach_connections on delete cascade,
  coach_id       uuid not null references public.profiles on delete cascade,
  athlete_id     uuid not null references public.profiles on delete cascade,
  block_id       uuid references public.training_blocks on delete cascade,
  template_id    uuid references public.workout_templates on delete set null,   -- provenance only
  title          text not null check (char_length(title) between 1 and 80),
  workout        jsonb not null,           -- frozen copy of the template's workout document
  coach_note     text check (char_length(coach_note) <= 1000),
  scheduled_for  date,
  status         public.assignment_status not null default 'assigned',
  created_at     timestamptz not null default now()
);
create index workout_assignments_athlete_date on public.workout_assignments (athlete_id, scheduled_for);
create index workout_assignments_block on public.workout_assignments (block_id);

create table public.workout_results (
  assignment_id  uuid primary key references public.workout_assignments on delete cascade,
  athlete_id     uuid not null references public.profiles on delete cascade,
  session_id     text,                      -- the Crux session it was done in
  completed_at   timestamptz not null default now(),
  steps          jsonb not null,            -- {stepId: {status, ...type-specific}} (DESIGN.md section 5)
  rpe            smallint check (rpe between 1 and 10),
  athlete_note   text check (char_length(athlete_note) <= 500)   -- "Note for your coach"
);

-- ---------------------------------------------------------------- helpers
-- Is this connection active, with the caller as its coach?
create function public.coach_connection_active(p_connection uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.coach_connections c
                 where c.id = p_connection and c.coach_id = auth.uid() and c.status = 'active');
$$;

-- The caller's active connection with this athlete (at most one, by the unique index).
create function public.my_connection_with(p_athlete uuid) returns public.coach_connections
language sql stable security definer set search_path = public as $$
  select c from public.coach_connections c
  where c.athlete_id = p_athlete and c.coach_id = auth.uid() and c.status = 'active';
$$;

-- The allow-list. A coach-safe copy of one Crux session for the given scopes.
create function public.filter_session(d jsonb, s public.share_scope[]) returns jsonb
language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', d->'id', 'startedAt', d->'startedAt', 'endedAt', d->'endedAt', 'location', d->'location',
    'timerConfig', d->'timerConfig', 'satisfaction', d->'satisfaction',
    'counts', (select jsonb_build_object(
                 'flash', count(*) filter (where a->>'result' = 'flash'),
                 'send',  count(*) filter (where a->>'result' = 'send'),
                 'fall',  count(*) filter (where a->>'result' = 'fall'))
               from jsonb_array_elements(coalesce(d->'attempts', '[]'::jsonb)) a),
    'note', case when 'notes' = any(s) then d->'note' end,
    'attempts', case when 'attempts' = any(s) then coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'id', a->'id', 'result', a->'result', 'ts', a->'ts',
        'climbName', case when 'projects'     = any(s) then a->'climbName' end,
        'projectId', case when 'projects'     = any(s) then a->'projectId' end,
        'grade',     case when 'projects'     = any(s) then a->'grade' end,
        'gradeType', case when 'projects'     = any(s) then a->'gradeType' end,
        'effort',    case when 'effort'       = any(s) then a->'effort' end,
        'reason',    case when 'fall_reasons' = any(s) then a->'reason' end,
        'note',      case when 'notes'        = any(s) then a->'note' end)))
      from jsonb_array_elements(coalesce(d->'attempts', '[]'::jsonb)) a), '[]'::jsonb) end
  ));
$$;

-- ---------------------------------------------------------------- coach reads
create function public.coach_view_sessions(p_athlete uuid)
returns table (id text, started_at timestamptz, ended_at timestamptz, location text, data jsonb, assignment_id uuid)
language plpgsql stable security definer set search_path = public as $$
declare c public.coach_connections := public.my_connection_with(p_athlete);
begin
  if c.id is null or not ('sessions' = any(c.scopes)) then return; end if;
  return query
    select t.id, t.started_at, t.ended_at, t.location, public.filter_session(t.data, c.scopes),
           a.id   -- only this connection's own assignments are linked
    from public.training_sessions t
    left join public.workout_assignments a on a.id = t.assignment_id and a.connection_id = c.id
    where t.athlete_id = p_athlete and not t.deleted
      and t.started_at >= coalesce(c.history_from, '-infinity'::timestamptz)
    order by t.started_at desc;
end $$;

create function public.coach_view_projects(p_athlete uuid)
returns table (id text, name text, location text, attempts bigint, sends bigint, latest_grade text)
language plpgsql stable security definer set search_path = public as $$
declare c public.coach_connections := public.my_connection_with(p_athlete);
begin
  if c.id is null or not ('projects' = any(c.scopes)) then return; end if;
  return query
    select p.id, p.name, p.location,
           count(a.v),
           count(a.v) filter (where a.v->>'result' in ('send', 'flash')),
           (array_agg(a.v->>'grade' order by (a.v->>'ts')::bigint desc) filter (where a.v->>'grade' is not null))[1]
    from public.training_projects p
    left join public.training_sessions t
           on t.athlete_id = p.athlete_id and not t.deleted
          and t.started_at >= coalesce(c.history_from, '-infinity'::timestamptz)
    left join lateral jsonb_array_elements(coalesce(t.data->'attempts', '[]'::jsonb)) as a(v)
           on a.v->>'projectId' = p.id
    where p.athlete_id = p_athlete
    group by p.id, p.name, p.location;
end $$;

-- ---------------------------------------------------------------- connecting
-- Athlete: make a single-use invite. Returns the code, which is shown once and never stored.
create function public.create_coach_invite(
  p_scopes public.share_scope[] default '{sessions,projects,attempts,effort,fall_reasons}',
  p_history_from timestamptz default null)
returns text language plpgsql volatile security definer set search_path = public, extensions as $$
declare raw text := upper(encode(gen_random_bytes(6), 'hex'));     -- 48 bits, 12 hex chars
        code text := substr(raw,1,4) || '-' || substr(raw,5,4) || '-' || substr(raw,9,4);
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  insert into public.coach_connections (athlete_id, scopes, history_from, invite_code_hash, invite_expires_at)
  values (auth.uid(), p_scopes, p_history_from, encode(digest(code, 'sha256'), 'hex'), now() + interval '7 days');
  return code;
end $$;

-- Coach: accept an invite. The caller must have a coach profile with the adult confirmation.
create function public.accept_coach_invite(p_code text)
returns uuid language plpgsql volatile security definer set search_path = public, extensions as $$
declare c public.coach_connections;
begin
  if not exists (select 1 from public.profiles p
                 where p.id = auth.uid() and p.is_coach and p.coach_adult_confirmed_at is not null)
    then raise exception 'turn on your coach profile first'; end if;
  select * into c from public.coach_connections
   where invite_code_hash = encode(digest(upper(trim(p_code)), 'sha256'), 'hex')
     and status = 'pending' and invite_expires_at > now()
   for update;
  if c.id is null then raise exception 'that code is not valid or has expired'; end if;
  if c.athlete_id = auth.uid() then raise exception 'you cannot coach yourself'; end if;
  if exists (select 1 from public.coach_connections x
             where x.athlete_id = c.athlete_id and x.coach_id = auth.uid() and x.status = 'active')
    then raise exception 'you are already connected to this athlete'; end if;
  update public.coach_connections
     set coach_id = auth.uid(), status = 'active', accepted_at = now(), invite_code_hash = null
   where id = c.id;
  return c.id;
end $$;

-- Athlete: change what one coach can see (persistent; applies on the coach's next read).
create function public.set_coach_sharing(p_connection uuid, p_scopes public.share_scope[], p_history_from timestamptz)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update public.coach_connections set scopes = p_scopes, history_from = p_history_from
   where id = p_connection and athlete_id = auth.uid() and status <> 'ended';
  if not found then raise exception 'connection not found'; end if;
end $$;

-- Either side: end now. Every coach policy checks the specific connection, so the coach loses
-- access to everything under it (past results included). The athlete keeps it all.
create function public.end_coach_connection(p_connection uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update public.coach_connections
     set status = 'ended', ended_at = now(), invite_code_hash = null
   where id = p_connection and status <> 'ended' and (athlete_id = auth.uid() or coach_id = auth.uid());
  if not found then raise exception 'connection not found'; end if;
end $$;

-- ---------------------------------------------------------------- assigning (snapshots)
-- Coach: send one workout from their library, on its own or into one of this connection's blocks.
create function public.assign_workout(p_connection uuid, p_template uuid, p_scheduled_for date,
                                      p_coach_note text default null, p_block uuid default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare c public.coach_connections; t public.workout_templates; b public.training_blocks; new_id uuid;
begin
  select * into c from public.coach_connections where id = p_connection and coach_id = auth.uid() and status = 'active';
  if c.id is null then raise exception 'not connected'; end if;
  select * into t from public.workout_templates where id = p_template and coach_id = auth.uid();
  if t.id is null then raise exception 'workout not found'; end if;
  if p_block is not null then
    select * into b from public.training_blocks where id = p_block and connection_id = c.id and status = 'active';
    if b.id is null then raise exception 'block not found'; end if;
    if p_scheduled_for is null or p_scheduled_for not between b.start_date and b.end_date
      then raise exception 'date is outside the block'; end if;
  end if;
  insert into public.workout_assignments
    (connection_id, coach_id, athlete_id, block_id, template_id, title, workout, coach_note, scheduled_for)
  values (c.id, auth.uid(), c.athlete_id, p_block, t.id, t.title, t.workout,
          coalesce(p_coach_note, t.coach_note), p_scheduled_for)
  returning id into new_id;
  return new_id;
end $$;

-- Coach: assign a block template from a start date. Creates the training block and one
-- snapshot assignment per item, all in one transaction.
create function public.assign_block(p_connection uuid, p_block_template uuid, p_start date,
                                    p_coach_note text default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare c public.coach_connections; bt public.block_templates; blk uuid;
begin
  select * into c from public.coach_connections where id = p_connection and coach_id = auth.uid() and status = 'active';
  if c.id is null then raise exception 'not connected'; end if;
  select * into bt from public.block_templates where id = p_block_template and coach_id = auth.uid();
  if bt.id is null then raise exception 'block not found'; end if;
  if exists (select 1 from public.block_template_items i where i.block_template_id = bt.id and i.day_offset >= bt.length_days)
    then raise exception 'a workout in this block is placed after its last day'; end if;
  insert into public.training_blocks (connection_id, coach_id, athlete_id, block_template_id, title, coach_note, start_date, end_date)
  values (c.id, auth.uid(), c.athlete_id, bt.id, bt.title, coalesce(p_coach_note, bt.coach_note),
          p_start, p_start + bt.length_days - 1)
  returning id into blk;
  insert into public.workout_assignments
    (connection_id, coach_id, athlete_id, block_id, template_id, title, workout, coach_note, scheduled_for)
  select c.id, auth.uid(), c.athlete_id, blk, t.id, t.title, t.workout,
         coalesce(i.coach_note, t.coach_note), p_start + i.day_offset
  from public.block_template_items i
  join public.workout_templates t on t.id = i.workout_template_id
  where i.block_template_id = bt.id;
  return blk;
end $$;

-- Coach: withdraw a whole block. Its unfinished workouts are withdrawn; done ones keep their results.
create function public.withdraw_block(p_block uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update public.training_blocks set status = 'withdrawn'
   where id = p_block and coach_id = auth.uid() and public.coach_connection_active(connection_id);
  if not found then raise exception 'block not found'; end if;
  update public.workout_assignments set status = 'withdrawn' where block_id = p_block and status = 'assigned';
end $$;

-- ---------------------------------------------------------------- results (athlete)
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
alter table public.profiles             enable row level security;
alter table public.coach_connections    enable row level security;
alter table public.training_sessions    enable row level security;
alter table public.training_projects    enable row level security;
alter table public.workout_templates    enable row level security;
alter table public.block_templates      enable row level security;
alter table public.block_template_items enable row level security;
alter table public.training_blocks      enable row level security;
alter table public.workout_assignments  enable row level security;
alter table public.workout_results      enable row level security;

-- profiles: yourself; an athlete sees the name of any coach they've ever connected (so workouts
-- they keep still say who sent them); a coach sees an athlete's name only while connected
create policy profiles_read on public.profiles for select using (
  id = auth.uid() or exists (
    select 1 from public.coach_connections c
    where (c.athlete_id = auth.uid() and c.coach_id = profiles.id)
       or (c.coach_id = auth.uid() and c.athlete_id = profiles.id and c.status = 'active')));
create policy profiles_insert on public.profiles for insert with check (id = auth.uid());
create policy profiles_update on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- connections: read-only to the two people in them; every change goes through the functions above
create policy connections_read on public.coach_connections for select
  using (athlete_id = auth.uid() or coach_id = auth.uid());

-- the athlete's own data: only the athlete (coaches read via coach_view_*)
create policy sessions_own on public.training_sessions for all
  using (athlete_id = auth.uid()) with check (athlete_id = auth.uid());
create policy projects_own on public.training_projects for all
  using (athlete_id = auth.uid()) with check (athlete_id = auth.uid());

-- the coach's library
create policy workout_templates_own on public.workout_templates for all
  using (coach_id = auth.uid()) with check (coach_id = auth.uid());
create policy block_templates_own on public.block_templates for all
  using (coach_id = auth.uid()) with check (coach_id = auth.uid());
create policy block_items_own on public.block_template_items for all
  using (exists (select 1 from public.block_templates b where b.id = block_template_id and b.coach_id = auth.uid()))
  with check (
    exists (select 1 from public.block_templates b where b.id = block_template_id and b.coach_id = auth.uid())
    and exists (select 1 from public.workout_templates w where w.id = workout_template_id and w.coach_id = auth.uid()));

-- training blocks: the athlete always; the coach only while THAT connection is active
create policy blocks_athlete_read on public.training_blocks for select using (athlete_id = auth.uid());
create policy blocks_coach_read on public.training_blocks for select
  using (coach_id = auth.uid() and public.coach_connection_active(connection_id));
create policy blocks_coach_update on public.training_blocks for update
  using (coach_id = auth.uid() and status = 'active' and public.coach_connection_active(connection_id))
  with check (coach_id = auth.uid());

-- assignments: the athlete always; the coach only while THAT connection is active
create policy assignments_athlete_read on public.workout_assignments for select using (athlete_id = auth.uid());
create policy assignments_coach_read on public.workout_assignments for select
  using (coach_id = auth.uid() and public.coach_connection_active(connection_id));
create policy assignments_coach_update on public.workout_assignments for update
  using (coach_id = auth.uid() and status = 'assigned' and public.coach_connection_active(connection_id))
  with check (coach_id = auth.uid() and status in ('assigned', 'withdrawn'));

-- results: the athlete always; the assigning coach only while that assignment's connection is active
create policy results_athlete_read on public.workout_results for select using (athlete_id = auth.uid());
create policy results_coach_read on public.workout_results for select using (
  exists (select 1 from public.workout_assignments a
          where a.id = assignment_id and a.coach_id = auth.uid() and public.coach_connection_active(a.connection_id)));

-- ---------------------------------------------------------------- privileges
-- Blocks, assignments and results are created only by the functions above. A coach may change
-- just these columns: an assignment's note, date and status (to withdraw); a block's note.
-- The workout snapshot itself can never be edited.
revoke insert, update, delete on public.training_blocks, public.workout_assignments, public.workout_results,
  public.coach_connections from anon, authenticated;
grant update (coach_note, scheduled_for, status) on public.workout_assignments to authenticated;
-- TODO before shipping phase 4: a trigger keeping a re-dated block workout inside its block's dates.
grant update (coach_note) on public.training_blocks to authenticated;

revoke all on function
  public.coach_connection_active(uuid), public.my_connection_with(uuid), public.filter_session(jsonb, public.share_scope[]),
  public.coach_view_sessions(uuid), public.coach_view_projects(uuid),
  public.create_coach_invite(public.share_scope[], timestamptz), public.accept_coach_invite(text),
  public.set_coach_sharing(uuid, public.share_scope[], timestamptz), public.end_coach_connection(uuid),
  public.assign_workout(uuid, uuid, date, text, uuid), public.assign_block(uuid, uuid, date, text),
  public.withdraw_block(uuid), public.record_workout_result(uuid, text, jsonb, smallint, text),
  public.skip_workout(uuid)
  from public, anon;
grant execute on function
  public.coach_connection_active(uuid), public.my_connection_with(uuid), public.filter_session(jsonb, public.share_scope[]),
  public.coach_view_sessions(uuid), public.coach_view_projects(uuid),
  public.create_coach_invite(public.share_scope[], timestamptz), public.accept_coach_invite(text),
  public.set_coach_sharing(uuid, public.share_scope[], timestamptz), public.end_coach_connection(uuid),
  public.assign_workout(uuid, uuid, date, text, uuid), public.assign_block(uuid, uuid, date, text),
  public.withdraw_block(uuid), public.record_workout_result(uuid, text, jsonb, smallint, text),
  public.skip_workout(uuid)
  to authenticated;

-- ---------------------------------------------------------------- checks to run after applying
-- Users: athlete A, coaches C and D (both with is_coach + adult confirmation).
--  1. A: select create_coach_invite();               C: select accept_coach_invite('<code>');
--  2. C: select * from coach_view_sessions('<A>');   -> rows; no 'note' keys; attempts have reasons
--  3. C: select * from training_sessions;           -> 0 rows (RLS)
--  4. D: select * from coach_view_sessions('<A>');   -> 0 rows (not connected)
--  5. A: select set_coach_sharing('<conn>', '{sessions}', null);  C: sessions have counts, no 'attempts'
--  6. C: select assign_block('<conn>', '<block template>', current_date);  A: sees the block + its workouts
--  7. C: update workout_assignments set workout = '{}' where ...;            -> permission denied (frozen)
--  8. A: select record_workout_result('<assignment>', 's1', '{}', 7, 'felt strong');  C: sees the result
--  9. A: select end_coach_connection('<conn>');      C: sees no blocks, assignments or results; A still does
-- 10. A invites C again; C accepts.                  C: still sees NONE of the old blocks/assignments/results
-- 11. A connects D too (many-to-many). C and D each see only their own assignments and results.
