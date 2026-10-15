-- Personality app: schema, indexes, RLS, account deletion.
-- Run in Supabase SQL Editor (or `supabase db push`). Then run supabase/seed.sql.
-- Never put the service_role key in the app.

-- ---------- helpers
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- tables
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  locale text not null default 'ar',
  ads_consent boolean not null default false,
  ai_consent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.questions (
  id integer primary key,
  system text not null check (system in ('mbti','enneagram','arfd')),
  dimension text not null,
  topic text not null default '',
  reverse boolean not null default false,
  text_ar text not null,
  sort_order integer not null,
  created_at timestamptz not null default now()
);

create table if not exists public.assessment_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'completed' check (status in ('in_progress','completed')),
  scoring_version integer not null default 1,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.assessment_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  question_id integer not null references public.questions(id),
  value smallint not null check (value between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (session_id, question_id)
);

create table if not exists public.assessment_results (
  session_id uuid primary key references public.assessment_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  mbti jsonb not null,
  enneagram jsonb not null,
  arfd jsonb not null,
  mbti_type text not null,
  arfd_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reports (
  session_id uuid primary key references public.assessment_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content jsonb not null,
  source text not null default 'local' check (source in ('local','ai')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.development_plans (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid references public.assessment_sessions(id) on delete set null,
  plan jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.progress_logs (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.development_plans(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  day smallint not null check (day between 1 and 30),
  done boolean not null default false,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_id, day)
);

-- ---------- indexes
create index if not exists idx_sessions_user on public.assessment_sessions(user_id, created_at desc);
create index if not exists idx_answers_session on public.answers(session_id);
create index if not exists idx_answers_user on public.answers(user_id);
create index if not exists idx_results_user on public.assessment_results(user_id);
create index if not exists idx_reports_user on public.reports(user_id);
create index if not exists idx_plans_user on public.development_plans(user_id);
create index if not exists idx_plans_session on public.development_plans(session_id);
create index if not exists idx_progress_plan on public.progress_logs(plan_id);
create index if not exists idx_progress_user on public.progress_logs(user_id);

-- ---------- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array['profiles','assessment_sessions','answers','assessment_results','reports','development_plans','progress_logs']
  loop
    execute format('drop trigger if exists trg_%1$s_updated on public.%1$s', t);
    execute format('create trigger trg_%1$s_updated before update on public.%1$s for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- ---------- row level security
alter table public.profiles enable row level security;
alter table public.questions enable row level security;
alter table public.assessment_sessions enable row level security;
alter table public.answers enable row level security;
alter table public.assessment_results enable row level security;
alter table public.reports enable row level security;
alter table public.development_plans enable row level security;
alter table public.progress_logs enable row level security;

-- questions: public read-only (no write policy => no writes for anon/authenticated)
drop policy if exists questions_read on public.questions;
create policy questions_read on public.questions for select to anon, authenticated using (true);

-- profiles
drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_insert_own on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
drop policy if exists profiles_delete_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert_own on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy profiles_delete_own on public.profiles for delete to authenticated using ((select auth.uid()) = id);

-- sessions
drop policy if exists sessions_select_own on public.assessment_sessions;
drop policy if exists sessions_insert_own on public.assessment_sessions;
drop policy if exists sessions_update_own on public.assessment_sessions;
drop policy if exists sessions_delete_own on public.assessment_sessions;
create policy sessions_select_own on public.assessment_sessions for select to authenticated using ((select auth.uid()) = user_id);
create policy sessions_insert_own on public.assessment_sessions for insert to authenticated with check ((select auth.uid()) = user_id);
create policy sessions_update_own on public.assessment_sessions for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy sessions_delete_own on public.assessment_sessions for delete to authenticated using ((select auth.uid()) = user_id);

-- children of sessions: owner AND the session must belong to the same user
do $$
declare t text;
begin
  foreach t in array array['answers','assessment_results','reports']
  loop
    execute format('drop policy if exists %1$s_select_own on public.%1$s', t);
    execute format('drop policy if exists %1$s_insert_own on public.%1$s', t);
    execute format('drop policy if exists %1$s_update_own on public.%1$s', t);
    execute format('drop policy if exists %1$s_delete_own on public.%1$s', t);
    execute format('create policy %1$s_select_own on public.%1$s for select to authenticated using ((select auth.uid()) = user_id)', t);
    execute format($p$create policy %1$s_insert_own on public.%1$s for insert to authenticated with check ((select auth.uid()) = user_id and exists (select 1 from public.assessment_sessions s where s.id = session_id and s.user_id = (select auth.uid())))$p$, t);
    execute format($p$create policy %1$s_update_own on public.%1$s for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id and exists (select 1 from public.assessment_sessions s where s.id = session_id and s.user_id = (select auth.uid())))$p$, t);
    execute format('create policy %1$s_delete_own on public.%1$s for delete to authenticated using ((select auth.uid()) = user_id)', t);
  end loop;
end $$;

-- plans
drop policy if exists plans_select_own on public.development_plans;
drop policy if exists plans_insert_own on public.development_plans;
drop policy if exists plans_update_own on public.development_plans;
drop policy if exists plans_delete_own on public.development_plans;
create policy plans_select_own on public.development_plans for select to authenticated using ((select auth.uid()) = user_id);
create policy plans_insert_own on public.development_plans for insert to authenticated
  with check ((select auth.uid()) = user_id
    and (session_id is null or exists (select 1 from public.assessment_sessions s where s.id = session_id and s.user_id = (select auth.uid()))));
create policy plans_update_own on public.development_plans for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id
    and (session_id is null or exists (select 1 from public.assessment_sessions s where s.id = session_id and s.user_id = (select auth.uid()))));
create policy plans_delete_own on public.development_plans for delete to authenticated using ((select auth.uid()) = user_id);

-- progress logs
drop policy if exists progress_select_own on public.progress_logs;
drop policy if exists progress_insert_own on public.progress_logs;
drop policy if exists progress_update_own on public.progress_logs;
drop policy if exists progress_delete_own on public.progress_logs;
create policy progress_select_own on public.progress_logs for select to authenticated using ((select auth.uid()) = user_id);
create policy progress_insert_own on public.progress_logs for insert to authenticated
  with check ((select auth.uid()) = user_id
    and exists (select 1 from public.development_plans p where p.id = plan_id and p.user_id = (select auth.uid())));
create policy progress_update_own on public.progress_logs for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id
    and exists (select 1 from public.development_plans p where p.id = plan_id and p.user_id = (select auth.uid())));
create policy progress_delete_own on public.progress_logs for delete to authenticated using ((select auth.uid()) = user_id);

-- ---------- profile auto-creation on sign up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- account deletion (called from the app via rpc('delete_my_account'))
-- Deleting the auth user cascades to every table above (all FKs are ON DELETE CASCADE).
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
