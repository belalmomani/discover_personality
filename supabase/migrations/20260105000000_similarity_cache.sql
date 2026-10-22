-- Similarity cache. Run AFTER 20260104000000_chat_images.sql. Safe to re-run.
-- Before: find_similar computed the weighted similarity against EVERY user on EVERY call.
-- Now: pair values are stored once and refreshed only when a user's published scores actually change,
--      so find_similar is an indexed read. Stored pairs are those with similarity >= 40
--      (the listing threshold is never lower than 40; admins can still set a higher one).

create table if not exists public.similarity_cache (
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  similarity integer not null,
  tests_used integer not null,
  questions_used integer not null,
  updated_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index if not exists idx_similarity_cache_b on public.similarity_cache(user_b, similarity desc);
alter table public.similarity_cache enable row level security; -- internal table: no policies, no client grants
revoke all on public.similarity_cache from authenticated, anon;

-- Recompute every pair that involves `uid` (called only when its scores changed).
create or replace function public.refresh_similarity_for(uid uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.similarity_cache where user_a = uid or user_b = uid;
  insert into public.similarity_cache (user_a, user_b, similarity, tests_used, questions_used)
  select least(uid, o.user_id), greatest(uid, o.user_id), s.similarity, s.tests_used, s.questions_used
  from (select distinct user_id from public.shared_scores where user_id <> uid) o
  cross join lateral public.pair_similarity(uid, o.user_id) s
  where s.similarity is not null and s.similarity >= 40;
end;
$$;

-- When a user stops sharing (their score rows are deleted) their cached pairs disappear too.
create or replace function public.purge_similarity()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.similarity_cache where user_a = old.user_id or user_b = old.user_id;
  return old;
end;
$$;
drop trigger if exists trg_purge_similarity on public.shared_scores;
create trigger trg_purge_similarity after delete on public.shared_scores
  for each row execute function public.purge_similarity();

-- Same validation as before, but the cache is refreshed only if something really changed.
create or replace function public.publish_scores_batch(payload jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare e jsonb; tid text; arr double precision[]; prev double precision[]; cat record; n integer := 0; v double precision; changed boolean := false;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.social_eligible(auth.uid()) then raise exception 'not_eligible'; end if;
  if payload is null or jsonb_typeof(payload) <> 'array' or jsonb_array_length(payload) > 40 then raise exception 'invalid_payload'; end if;
  for e in select value from jsonb_array_elements(payload) loop
    tid := e->>'test_id';
    select * into cat from public.assessment_catalog where test_id = tid;
    if not found then raise exception 'unknown_test'; end if;
    select array_agg(x::double precision order by o) into arr from jsonb_array_elements_text(e->'dims') with ordinality as t(x, o);
    if arr is null or array_length(arr, 1) <> cat.dims then raise exception 'invalid_scores'; end if;
    foreach v in array arr loop
      if v is null or v < 0 or v > 1 then raise exception 'invalid_scores'; end if;
    end loop;
    select dims into prev from public.shared_scores where user_id = auth.uid() and test_id = tid;
    if prev is distinct from arr then
      changed := true;
      insert into public.shared_scores (user_id, test_id, dims) values (auth.uid(), tid, arr)
      on conflict (user_id, test_id) do update set dims = excluded.dims, updated_at = now();
    end if;
    n := n + 1;
  end loop;
  if changed then perform public.refresh_similarity_for(auth.uid()); end if;
  return n;
end;
$$;

-- Discovery reads the cache instead of computing similarity against every user.
create or replace function public.find_similar(min_similarity integer default null, lim integer default 50)
returns table (user_id uuid, username text, avatar_emoji text, similarity integer, tests_used integer, questions_used integer, can_chat boolean)
language plpgsql stable security definer set search_path = public as $$
declare threshold integer := greatest(coalesce(min_similarity, public.setting_int('chat_min_similarity', 70)), 40);
begin
  if auth.uid() is null or not public.social_eligible(auth.uid()) then return; end if;
  return query
    with mine as (
      select c.user_b as other, c.similarity, c.tests_used, c.questions_used from public.similarity_cache c where c.user_a = auth.uid()
      union all
      select c.user_a, c.similarity, c.tests_used, c.questions_used from public.similarity_cache c where c.user_b = auth.uid()
    )
    select p.id, p.username, p.avatar_emoji, m.similarity, m.tests_used, m.questions_used, (p.allow_chat and me.allow_chat)
    from mine m
    join public.profiles p on p.id = m.other
    join public.profiles me on me.id = auth.uid()
    where m.similarity >= threshold
      and p.username is not null and p.share_results and p.age_confirmed and not p.banned and p.visible
      and not public.is_blocked(auth.uid(), p.id)
    order by m.similarity desc, p.username
    limit least(greatest(lim, 1), 100);
end;
$$;

-- One-time backfill for users who already shared scores.
do $$
declare u uuid;
begin
  for u in select distinct user_id from public.shared_scores loop
    perform public.refresh_similarity_for(u);
  end loop;
end $$;

revoke all on function public.refresh_similarity_for(uuid) from public, anon, authenticated;
revoke all on function public.purge_similarity() from public, anon, authenticated;
