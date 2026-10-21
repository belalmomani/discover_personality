-- Similarity v2 + visibility/chat switches. Run AFTER 20260102000000_social.sql. Safe to re-run.
-- * Similarity is computed over ALL shared tests; each test is weighted by its number of questions
--   (weights come from the server-side catalog below, so a client cannot inflate them).
-- * Sensitive tests (dark traits, attachment) are never shared: they are not in the catalog.
-- * Users can hide themselves from "people like you" and switch chat on/off.

alter table public.profiles
  add column if not exists visible boolean not null default true,
  add column if not exists allow_chat boolean not null default true;

-- ---------- catalog of shareable tests (id, number of dimensions, number of questions)
create table if not exists public.assessment_catalog (
  test_id text primary key,
  dims integer not null check (dims > 0),
  items integer not null check (items > 0)
);
alter table public.assessment_catalog enable row level security; -- no policies: read only inside definer functions
revoke all on public.assessment_catalog from authenticated, anon;
insert into public.assessment_catalog (test_id, dims, items) values
  ('main_mbti', 4, 24),
  ('main_enneagram', 9, 36),
  ('main_arfd', 4, 12),
  ('x_bigfive', 5, 20),
  ('x_hexaco', 6, 18),
  ('x_disc', 4, 16),
  ('x_strengths', 4, 12),
  ('x_workstyle', 6, 18),
  ('x_eq', 4, 12),
  ('x_resilience', 1, 6),
  ('x_locus', 1, 6),
  ('x_cognitive', 4, 12),
  ('x_values', 6, 18),
  ('x_moral', 5, 15),
  ('x_risk', 4, 12),
  ('x_decision', 5, 15),
  ('x_nfc', 1, 6),
  ('x_via', 6, 18),
  ('x_psycap', 4, 12)
on conflict (test_id) do update set dims = excluded.dims, items = excluded.items;

-- ---------- shared score vectors (0..1 per dimension; never raw answers)
create table if not exists public.shared_scores (
  user_id uuid not null references auth.users(id) on delete cascade,
  test_id text not null references public.assessment_catalog(test_id),
  dims double precision[] not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, test_id)
);
create index if not exists idx_shared_scores_test on public.shared_scores(test_id);
alter table public.shared_scores enable row level security;
drop policy if exists shared_scores_own on public.shared_scores;
create policy shared_scores_own on public.shared_scores for select to authenticated using ((select auth.uid()) = user_id);
revoke insert, update, delete on public.shared_scores from authenticated, anon;

create or replace function public.publish_scores_batch(payload jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare e jsonb; tid text; arr double precision[]; cat record; n integer := 0; v double precision;
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
    insert into public.shared_scores (user_id, test_id, dims) values (auth.uid(), tid, arr)
    on conflict (user_id, test_id) do update set dims = excluded.dims, updated_at = now();
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- Weighted similarity between two users over the tests BOTH shared: sum(questions_t * sim_t) / sum(questions_t).
-- sim_t = 100 * (1 - euclidean_distance / sqrt(number_of_dimensions)). Internal only: NOT granted to clients.
create or replace function public.pair_similarity(a uuid, b uuid)
returns table (similarity integer, tests_used integer, questions_used integer)
language sql stable security definer set search_path = public as $$
  with common as (
    select c.items, x.dims as da, y.dims as db
    from public.shared_scores x
    join public.shared_scores y on y.test_id = x.test_id and y.user_id = b
    join public.assessment_catalog c on c.test_id = x.test_id
    where x.user_id = a
  ), sims as (
    select items,
           100 * (1 - sqrt((select sum(power(u - v, 2)) from unnest(da, db) as t(u, v))) / sqrt(cardinality(da))) as sim
    from common
  )
  select round((sum(items * sim) / sum(items))::numeric)::integer, count(*)::integer, sum(items)::integer from sims;
$$;

-- ---------- profile with the new switches
drop function if exists public.my_profile();
create or replace function public.my_profile()
returns table (username text, avatar_emoji text, share_results boolean, show_last_seen boolean, age_confirmed boolean, banned boolean, visible boolean, allow_chat boolean)
language sql stable security definer set search_path = public as $$
  select p.username, p.avatar_emoji, p.share_results, p.show_last_seen, p.age_confirmed, p.banned, p.visible, p.allow_chat
  from public.profiles p where p.id = auth.uid();
$$;

drop function if exists public.save_my_profile(text, text, boolean, boolean, boolean);
create or replace function public.save_my_profile(
  p_username text, p_emoji text, p_share boolean, p_show_last_seen boolean, p_age_confirmed boolean,
  p_visible boolean default true, p_allow_chat boolean default true)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_username is null or p_username !~ '^[A-Za-z0-9_ء-ي]{3,20}$' then raise exception 'invalid_username'; end if;
  if char_length(coalesce(p_emoji, '')) not between 1 and 8 then raise exception 'invalid_emoji'; end if;
  if p_share and not p_age_confirmed then raise exception 'age_required'; end if;
  insert into public.profiles (id) values (auth.uid()) on conflict (id) do nothing;
  begin
    update public.profiles
       set username = p_username, avatar_emoji = p_emoji, share_results = p_share,
           show_last_seen = p_show_last_seen, age_confirmed = p_age_confirmed,
           visible = coalesce(p_visible, true), allow_chat = coalesce(p_allow_chat, true)
     where id = auth.uid() and not banned;
  exception when unique_violation then
    raise exception 'username_taken';
  end;
  if not p_share then
    delete from public.shared_scores where user_id = auth.uid();
    delete from public.shared_features where user_id = auth.uid();
  end if;
end;
$$;

-- ---------- discovery uses the weighted similarity and respects visibility / chat switches
drop function if exists public.find_similar(integer, integer);
create or replace function public.find_similar(min_similarity integer default null, lim integer default 50)
returns table (user_id uuid, username text, avatar_emoji text, similarity integer, tests_used integer, questions_used integer, can_chat boolean)
language plpgsql stable security definer set search_path = public as $$
declare threshold integer := coalesce(min_similarity, public.setting_int('chat_min_similarity', 70));
begin
  if auth.uid() is null or not public.social_eligible(auth.uid()) then return; end if;
  return query
    select p.id, p.username, p.avatar_emoji, s.similarity, s.tests_used, s.questions_used, (p.allow_chat and me.allow_chat)
    from public.profiles me
    join public.profiles p on p.id <> me.id
    cross join lateral public.pair_similarity(me.id, p.id) s
    where me.id = auth.uid()
      and p.username is not null and p.share_results and p.age_confirmed and not p.banned and p.visible
      and s.similarity is not null and s.similarity >= threshold
      and not public.is_blocked(auth.uid(), p.id)
    order by s.similarity desc, p.username
    limit least(greatest(lim, 1), 100);
end;
$$;

create or replace function public.start_conversation(other uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare a uuid; b uuid; cid uuid; sim integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if other is null or other = auth.uid() then raise exception 'invalid_user'; end if;
  if not public.social_eligible(auth.uid()) or not public.social_eligible(other) then raise exception 'not_eligible'; end if;
  if public.is_blocked(auth.uid(), other) then raise exception 'blocked'; end if;
  a := least(auth.uid(), other); b := greatest(auth.uid(), other);
  select id into cid from public.conversations where user_a = a and user_b = b;
  if cid is not null then return cid; end if;
  if exists (select 1 from public.profiles where id in (auth.uid(), other) and not allow_chat) then raise exception 'chat_disabled'; end if;
  if not exists (select 1 from public.profiles where id = other and visible) then raise exception 'not_eligible'; end if;
  select s.similarity into sim from public.pair_similarity(auth.uid(), other) s;
  if sim is null or sim < public.setting_int('chat_min_similarity', 70) then raise exception 'not_similar_enough'; end if;
  insert into public.conversations (user_a, user_b) values (a, b) on conflict (user_a, user_b) do nothing;
  select id into cid from public.conversations where user_a = a and user_b = b;
  return cid;
end;
$$;

-- Every message (text or gift) is refused if either side switched chat off.
create or replace function public.messages_chat_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare c public.conversations;
begin
  select * into c from public.conversations where id = new.conversation_id;
  if found and exists (select 1 from public.profiles where id in (c.user_a, c.user_b) and not allow_chat) then
    raise exception 'chat_disabled';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_messages_chat_guard on public.messages;
create trigger trg_messages_chat_guard before insert on public.messages
  for each row execute function public.messages_chat_guard();

-- ---------- execute privileges
do $$
declare f text;
begin
  foreach f in array array[
    'my_profile()', 'save_my_profile(text,text,boolean,boolean,boolean,boolean,boolean)',
    'find_similar(integer,integer)', 'publish_scores_batch(jsonb)', 'start_conversation(uuid)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  revoke all on function public.pair_similarity(uuid, uuid) from public, anon, authenticated;
  revoke all on function public.messages_chat_guard() from public, anon, authenticated;
end $$;
