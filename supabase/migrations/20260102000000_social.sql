-- Social layer: similar people, chat, block/report, virtual coins, gifts, admin.
-- Run AFTER 20260101000000_init.sql. Safe to re-run. Does not touch existing user data.
-- NO real money lives here: coins are virtual; "rewards" are non-withdrawable points.
-- All writes go through SECURITY DEFINER functions; clients get no direct write access.

-- ---------- admin helper
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security; -- no policies: unreadable directly

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;

-- ---------- app settings (editable by admins, no code change)
create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
alter table public.app_settings enable row level security;
drop policy if exists settings_read on public.app_settings;
create policy settings_read on public.app_settings for select to authenticated using (true);
insert into public.app_settings (key, value) values
  ('daily_free_coins', '20'),
  ('free_gift_daily_limit', '5'),
  ('reward_rate_percent', '50'),
  ('chat_min_similarity', '70')
on conflict (key) do nothing;

create or replace function public.setting_int(k text, fallback integer)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce((select value::integer from public.app_settings where key = k), fallback);
$$;

-- ---------- profiles: social columns (users can NOT write them directly)
alter table public.profiles
  add column if not exists username text,
  add column if not exists avatar_emoji text not null default '🙂',
  add column if not exists share_results boolean not null default false,
  add column if not exists show_last_seen boolean not null default true,
  add column if not exists age_confirmed boolean not null default false,
  add column if not exists banned boolean not null default false,
  add column if not exists last_seen timestamptz;

alter table public.profiles drop constraint if exists profiles_username_chk;
alter table public.profiles add constraint profiles_username_chk
  check (username is null or username ~ '^[A-Za-z0-9_ء-ي]{3,20}$');
create unique index if not exists idx_profiles_username on public.profiles (lower(username)) where username is not null;

revoke insert, update, delete on public.profiles from authenticated, anon;

-- ---------- shared feature vectors (8 numbers 0..1; never raw answers)
create table if not exists public.shared_features (
  user_id uuid primary key references auth.users(id) on delete cascade,
  features double precision[] not null check (array_length(features, 1) = 8),
  updated_at timestamptz not null default now()
);
alter table public.shared_features enable row level security;
drop policy if exists shared_features_own on public.shared_features;
create policy shared_features_own on public.shared_features for select to authenticated using ((select auth.uid()) = user_id);
revoke insert, update, delete on public.shared_features from authenticated, anon;

-- ---------- blocks / abuse reports
-- NOTE: `public.reports` already exists (analysis reports from init.sql); moderation reports live in `abuse_reports`.
create table if not exists public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.blocks enable row level security;
drop policy if exists blocks_own on public.blocks;
create policy blocks_own on public.blocks for select to authenticated using ((select auth.uid()) = blocker_id);
revoke insert, update, delete on public.blocks from authenticated, anon;

create table if not exists public.abuse_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid,
  reason text not null check (char_length(reason) between 1 and 500),
  status text not null default 'open' check (status in ('open','reviewed','dismissed','actioned')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.abuse_reports enable row level security;
drop policy if exists abuse_reports_own on public.abuse_reports;
create policy abuse_reports_own on public.abuse_reports for select to authenticated using ((select auth.uid()) = reporter_id);
revoke insert, update, delete on public.abuse_reports from authenticated, anon;
create index if not exists idx_abuse_reports_status on public.abuse_reports(status, created_at desc);

create or replace function public.is_blocked(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.blocks
                 where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a));
$$;

-- ---------- conversations / messages
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);
create index if not exists idx_conv_a on public.conversations(user_a);
create index if not exists idx_conv_b on public.conversations(user_b);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  kind text not null default 'text' check (kind in ('text','gift')),
  body text not null default '',
  gift_id uuid,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (kind = 'gift' or char_length(body) between 1 and 1000)
);
create index if not exists idx_messages_conv on public.messages(conversation_id, created_at);
create index if not exists idx_messages_sender on public.messages(sender_id, created_at desc);

alter table public.conversations enable row level security;
alter table public.messages enable row level security;
drop policy if exists conv_participant on public.conversations;
create policy conv_participant on public.conversations for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));
drop policy if exists msg_participant on public.messages;
create policy msg_participant on public.messages for select to authenticated
  using (exists (select 1 from public.conversations c
                 where c.id = conversation_id and (select auth.uid()) in (c.user_a, c.user_b)));
revoke insert, update, delete on public.conversations, public.messages from authenticated, anon;

-- realtime for the messages table (ignore if unavailable)
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when others then null;
end $$;

-- ---------- virtual economy
create table if not exists public.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  coins bigint not null default 0 check (coins >= 0),
  rewards bigint not null default 0 check (rewards >= 0),
  last_daily_claim date,
  updated_at timestamptz not null default now()
);
alter table public.wallets enable row level security;
drop policy if exists wallets_own on public.wallets;
create policy wallets_own on public.wallets for select to authenticated using ((select auth.uid()) = user_id);
revoke insert, update, delete on public.wallets from authenticated, anon;

create table if not exists public.coin_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  balance_type text not null check (balance_type in ('coins','rewards')),
  delta bigint not null check (delta <> 0),
  reason text not null,
  ref_id uuid,
  created_at timestamptz not null default now()
);
create index if not exists idx_ledger_user on public.coin_ledger(user_id, created_at desc);
alter table public.coin_ledger enable row level security;
drop policy if exists ledger_own on public.coin_ledger;
create policy ledger_own on public.coin_ledger for select to authenticated using ((select auth.uid()) = user_id);
revoke insert, update, delete on public.coin_ledger from authenticated, anon;

-- ledger rows are immutable: corrections are new reversing entries
create or replace function public.ledger_immutable() returns trigger language plpgsql as $$
begin raise exception 'coin_ledger is append-only'; end; $$;
drop trigger if exists trg_ledger_immutable on public.coin_ledger;
create trigger trg_ledger_immutable before update or delete on public.coin_ledger
  for each row execute function public.ledger_immutable();

create table if not exists public.gifts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  emoji text not null,
  image_url text,
  price integer not null check (price >= 0),
  tier text not null check (tier in ('free','basic','mid','rare','seasonal')),
  active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.gifts enable row level security;
drop policy if exists gifts_read on public.gifts;
create policy gifts_read on public.gifts for select to authenticated
  using (public.is_admin() or (active and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now())));
drop policy if exists gifts_admin_write on public.gifts;
create policy gifts_admin_write on public.gifts for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop trigger if exists trg_gifts_updated on public.gifts;
create trigger trg_gifts_updated before update on public.gifts for each row execute function public.set_updated_at();

create table if not exists public.gift_sends (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  gift_id uuid not null references public.gifts(id),
  price integer not null,
  reward integer not null,
  idempotency_key text not null check (char_length(idempotency_key) between 8 and 64),
  message_id uuid,
  created_at timestamptz not null default now(),
  unique (sender_id, idempotency_key)
);
create index if not exists idx_gift_sends_sender on public.gift_sends(sender_id, created_at desc);
alter table public.gift_sends enable row level security;
drop policy if exists gift_sends_own on public.gift_sends;
create policy gift_sends_own on public.gift_sends for select to authenticated
  using ((select auth.uid()) in (sender_id, receiver_id));
revoke insert, update, delete on public.gift_sends from authenticated, anon;

-- seed gifts (only when the table is empty; admins edit them afterwards)
insert into public.gifts (name, emoji, price, tier, sort_order)
select * from (values
  ('ابتسامة'::text, '😊'::text, 0, 'free'::text, 1),
  ('مصافحة', '🤝', 0, 'free', 2),
  ('ورقة زيتون', '🌿', 0, 'free', 3),
  ('فنجان قهوة', '☕', 5, 'basic', 10),
  ('نجمة', '⭐', 10, 'basic', 11),
  ('قلب ذهبي', '💛', 10, 'basic', 12),
  ('ياسمينة', '🌼', 20, 'basic', 13),
  ('كتاب', '📚', 50, 'mid', 20),
  ('نخلة', '🌴', 100, 'mid', 21),
  ('سفينة', '⛵', 200, 'mid', 22),
  ('صقر', '🦅', 500, 'rare', 30),
  ('تاج', '👑', 1000, 'rare', 31),
  ('قلعة', '🏰', 2000, 'rare', 32),
  ('كوكب', '🪐', 5000, 'rare', 33),
  ('فانوس', '🏮', 30, 'seasonal', 40)
) as v(name, emoji, price, tier, sort_order)
where not exists (select 1 from public.gifts);

-- =====================================================================
-- Functions (all SECURITY DEFINER; they re-check auth.uid() themselves)
-- =====================================================================

create or replace function public.feature_similarity(a double precision[], b double precision[])
returns integer language sql immutable as $$
  select round((100 * (1 - sqrt((select sum(power(x - y, 2)) from unnest(a, b) as t(x, y))) / sqrt(8)))::numeric)::integer;
$$;

create or replace function public.social_eligible(uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p
                 where p.id = uid and p.username is not null and p.share_results
                   and p.age_confirmed and not p.banned);
$$;

create or replace function public.my_profile()
returns table (username text, avatar_emoji text, share_results boolean, show_last_seen boolean, age_confirmed boolean, banned boolean)
language sql stable security definer set search_path = public as $$
  select p.username, p.avatar_emoji, p.share_results, p.show_last_seen, p.age_confirmed, p.banned
  from public.profiles p where p.id = auth.uid();
$$;

create or replace function public.save_my_profile(p_username text, p_emoji text, p_share boolean, p_show_last_seen boolean, p_age_confirmed boolean)
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
           show_last_seen = p_show_last_seen, age_confirmed = p_age_confirmed
     where id = auth.uid() and not banned;
  exception when unique_violation then
    raise exception 'username_taken';
  end;
  if not p_share then delete from public.shared_features where user_id = auth.uid(); end if;
end;
$$;

create or replace function public.publish_features(vec double precision[])
returns void language plpgsql security definer set search_path = public as $$
declare v double precision;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.social_eligible(auth.uid()) then raise exception 'not_eligible'; end if;
  if vec is null or array_length(vec, 1) <> 8 then raise exception 'invalid_features'; end if;
  foreach v in array vec loop
    if v is null or v < 0 or v > 1 then raise exception 'invalid_features'; end if;
  end loop;
  insert into public.shared_features (user_id, features) values (auth.uid(), vec)
  on conflict (user_id) do update set features = excluded.features, updated_at = now();
end;
$$;

create or replace function public.find_similar(min_similarity integer default null, lim integer default 50)
returns table (user_id uuid, username text, avatar_emoji text, similarity integer)
language plpgsql stable security definer set search_path = public as $$
declare threshold integer := coalesce(min_similarity, public.setting_int('chat_min_similarity', 70));
begin
  if auth.uid() is null or not public.social_eligible(auth.uid()) then return; end if;
  return query
    select p.id, p.username, p.avatar_emoji, public.feature_similarity(me.features, sf.features) as s
    from public.shared_features me
    join public.shared_features sf on sf.user_id <> me.user_id
    join public.profiles p on p.id = sf.user_id
    where me.user_id = auth.uid()
      and p.username is not null and p.share_results and p.age_confirmed and not p.banned
      and not public.is_blocked(auth.uid(), sf.user_id)
      and public.feature_similarity(me.features, sf.features) >= threshold
    order by s desc, p.username
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
  select public.feature_similarity(m.features, o.features) into sim
    from public.shared_features m, public.shared_features o
   where m.user_id = auth.uid() and o.user_id = other;
  if sim is null or sim < public.setting_int('chat_min_similarity', 70) then raise exception 'not_similar_enough'; end if;
  insert into public.conversations (user_a, user_b) values (a, b)
  on conflict (user_a, user_b) do nothing;
  select id into cid from public.conversations where user_a = a and user_b = b;
  return cid;
end;
$$;

create or replace function public.send_message(conv uuid, text_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.conversations; other uuid; mid uuid; t text := btrim(coalesce(text_body, ''));
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into c from public.conversations where id = conv and auth.uid() in (user_a, user_b);
  if not found then raise exception 'forbidden'; end if;
  other := case when c.user_a = auth.uid() then c.user_b else c.user_a end;
  if public.is_blocked(auth.uid(), other) then raise exception 'blocked'; end if;
  if exists (select 1 from public.profiles where id = auth.uid() and banned) then raise exception 'banned'; end if;
  if char_length(t) not between 1 and 1000 then raise exception 'invalid_message'; end if;
  if (select count(*) from public.messages where sender_id = auth.uid() and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'rate_limited';
  end if;
  insert into public.messages (conversation_id, sender_id, kind, body) values (conv, auth.uid(), 'text', t) returning id into mid;
  update public.conversations set last_message_at = now() where id = conv;
  return mid;
end;
$$;

create or replace function public.mark_read(conv uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.messages m set read_at = now()
   where m.conversation_id = conv and m.sender_id <> auth.uid() and m.read_at is null
     and exists (select 1 from public.conversations c where c.id = conv and auth.uid() in (c.user_a, c.user_b));
end;
$$;

create or replace function public.touch_presence()
returns void language sql security definer set search_path = public as $$
  update public.profiles set last_seen = now() where id = auth.uid();
$$;

create or replace function public.my_conversations()
returns table (conversation_id uuid, other_id uuid, other_username text, other_emoji text, other_last_seen timestamptz,
               last_body text, last_kind text, last_at timestamptz, unread integer)
language sql stable security definer set search_path = public as $$
  select c.id,
         o.id,
         coalesce(o.username, 'مستخدم'),
         o.avatar_emoji,
         case when o.show_last_seen then o.last_seen else null end,
         lm.body, lm.kind, coalesce(lm.created_at, c.last_message_at),
         (select count(*)::integer from public.messages m
           where m.conversation_id = c.id and m.sender_id <> auth.uid() and m.read_at is null)
  from public.conversations c
  join public.profiles o on o.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
  left join lateral (select body, kind, created_at from public.messages
                      where conversation_id = c.id order by created_at desc limit 1) lm on true
  where auth.uid() in (c.user_a, c.user_b)
    and not public.is_blocked(auth.uid(), o.id)
  order by coalesce(lm.created_at, c.last_message_at) desc;
$$;

create or replace function public.block_user(target uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if target is null or target = auth.uid() then raise exception 'invalid_user'; end if;
  insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), target) on conflict do nothing;
end;
$$;

create or replace function public.unblock_user(target uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.blocks where blocker_id = auth.uid() and blocked_id = target;
$$;

create or replace function public.blocked_users()
returns table (user_id uuid, username text)
language sql stable security definer set search_path = public as $$
  select b.blocked_id, coalesce(p.username, 'مستخدم') from public.blocks b
  left join public.profiles p on p.id = b.blocked_id where b.blocker_id = auth.uid();
$$;

create or replace function public.report_user(target uuid, msg uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if target is null or target = auth.uid() then raise exception 'invalid_user'; end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 1 and 500 then raise exception 'invalid_reason'; end if;
  if (select count(*) from public.abuse_reports where reporter_id = auth.uid() and created_at > now() - interval '1 day') >= 20 then
    raise exception 'rate_limited';
  end if;
  insert into public.abuse_reports (reporter_id, reported_user_id, message_id, reason) values (auth.uid(), target, msg, btrim(p_reason));
end;
$$;

-- ---------- wallet / gifts
create or replace function public.my_wallet()
returns table (coins bigint, rewards bigint, last_daily_claim date)
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  insert into public.wallets (user_id) values (auth.uid()) on conflict (user_id) do nothing;
  return query select w.coins, w.rewards, w.last_daily_claim from public.wallets w where w.user_id = auth.uid();
end;
$$;

create or replace function public.claim_daily_coins()
returns bigint language plpgsql security definer set search_path = public as $$
declare w public.wallets; amount integer := public.setting_int('daily_free_coins', 20);
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if exists (select 1 from public.profiles where id = auth.uid() and banned) then raise exception 'banned'; end if;
  insert into public.wallets (user_id) values (auth.uid()) on conflict (user_id) do nothing;
  select * into w from public.wallets where user_id = auth.uid() for update;
  if w.last_daily_claim = (now() at time zone 'utc')::date then raise exception 'already_claimed'; end if;
  if amount <= 0 then raise exception 'daily_coins_disabled'; end if;
  update public.wallets set coins = coins + amount, last_daily_claim = (now() at time zone 'utc')::date, updated_at = now()
   where user_id = auth.uid() returning * into w;
  insert into public.coin_ledger (user_id, balance_type, delta, reason) values (auth.uid(), 'coins', amount, 'daily_free');
  return w.coins;
end;
$$;

create or replace function public.send_gift(conv uuid, p_gift uuid, idem text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  c public.conversations; g public.gifts; other uuid; claimed uuid; mid uuid; existing uuid;
  reward integer; sender_coins bigint; first_id uuid; second_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if idem is null or char_length(idem) not between 8 and 64 then raise exception 'invalid_idempotency_key'; end if;

  select * into c from public.conversations where id = conv and auth.uid() in (user_a, user_b);
  if not found then raise exception 'forbidden'; end if;
  other := case when c.user_a = auth.uid() then c.user_b else c.user_a end;
  if public.is_blocked(auth.uid(), other) then raise exception 'blocked'; end if;
  if exists (select 1 from public.profiles where id = auth.uid() and banned) then raise exception 'banned'; end if;

  select * into g from public.gifts
   where id = p_gift and active and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now());
  if not found then raise exception 'gift_unavailable'; end if;

  if g.price = 0 and (select count(*) from public.gift_sends
                       where sender_id = auth.uid() and price = 0 and created_at >= (now() at time zone 'utc')::date)
                     >= public.setting_int('free_gift_daily_limit', 5) then
    raise exception 'free_limit_reached';
  end if;

  reward := floor(g.price * public.setting_int('reward_rate_percent', 50) / 100.0)::integer;

  -- idempotency: claim the key first; a duplicate/retried request returns the original result
  insert into public.gift_sends (sender_id, receiver_id, conversation_id, gift_id, price, reward, idempotency_key)
  values (auth.uid(), other, conv, g.id, g.price, reward, idem)
  on conflict (sender_id, idempotency_key) do nothing
  returning id into claimed;
  if claimed is null then
    select message_id into existing from public.gift_sends where sender_id = auth.uid() and idempotency_key = idem;
    return existing;
  end if;

  insert into public.wallets (user_id) values (auth.uid()), (other) on conflict (user_id) do nothing;
  -- lock both wallets in a fixed order to avoid deadlocks
  first_id := least(auth.uid(), other); second_id := greatest(auth.uid(), other);
  perform 1 from public.wallets where user_id = first_id for update;
  perform 1 from public.wallets where user_id = second_id for update;

  if g.price > 0 then
    select coins into sender_coins from public.wallets where user_id = auth.uid();
    if sender_coins < g.price then raise exception 'insufficient_coins'; end if;
    update public.wallets set coins = coins - g.price, updated_at = now() where user_id = auth.uid();
    insert into public.coin_ledger (user_id, balance_type, delta, reason, ref_id) values (auth.uid(), 'coins', -g.price, 'gift_sent', claimed);
    if reward > 0 then
      update public.wallets set rewards = rewards + reward, updated_at = now() where user_id = other;
      insert into public.coin_ledger (user_id, balance_type, delta, reason, ref_id) values (other, 'rewards', reward, 'gift_received', claimed);
    end if;
  end if;

  insert into public.messages (conversation_id, sender_id, kind, body, gift_id) values (conv, auth.uid(), 'gift', '', g.id) returning id into mid;
  update public.gift_sends set message_id = mid where id = claimed;
  update public.conversations set last_message_at = now() where id = conv;
  return mid;
end;
$$;

-- ---------- admin
create or replace function public.admin_list_reports(p_status text default 'open')
returns table (id uuid, reporter text, reported_id uuid, reported text, message_body text, reason text, status text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
    select r.id, coalesce(rp.username, 'مستخدم'), r.reported_user_id, coalesce(ru.username, 'مستخدم'),
           m.body, r.reason, r.status, r.created_at
    from public.abuse_reports r
    left join public.profiles rp on rp.id = r.reporter_id
    left join public.profiles ru on ru.id = r.reported_user_id
    left join public.messages m on m.id = r.message_id
    where p_status is null or r.status = p_status
    order by r.created_at desc limit 200;
end;
$$;

create or replace function public.admin_resolve_report(p_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if p_status not in ('reviewed','dismissed','actioned') then raise exception 'invalid_status'; end if;
  update public.abuse_reports set status = p_status, reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
end;
$$;

create or replace function public.admin_set_ban(target uuid, p_banned boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  update public.profiles set banned = p_banned where id = target;
end;
$$;

create or replace function public.admin_set_setting(k text, v text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if k not in ('daily_free_coins','free_gift_daily_limit','reward_rate_percent','chat_min_similarity') then raise exception 'unknown_setting'; end if;
  if v !~ '^[0-9]{1,6}$' then raise exception 'invalid_value'; end if;
  if k in ('reward_rate_percent','chat_min_similarity') and v::integer > 100 then raise exception 'invalid_value'; end if;
  insert into public.app_settings (key, value) values (k, v)
  on conflict (key) do update set value = excluded.value, updated_at = now();
end;
$$;

-- grant virtual coins (never real money); recorded in the append-only ledger
create or replace function public.admin_grant_coins(target uuid, amount integer, note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if amount = 0 or abs(amount) > 100000 then raise exception 'invalid_amount'; end if;
  insert into public.wallets (user_id) values (target) on conflict (user_id) do nothing;
  perform 1 from public.wallets where user_id = target for update;
  update public.wallets set coins = coins + amount, updated_at = now() where user_id = target; -- CHECK blocks negative balance
  insert into public.coin_ledger (user_id, balance_type, delta, reason) values (target, 'coins', amount, 'admin:' || left(coalesce(note, ''), 100));
end;
$$;

create or replace function public.admin_stats()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return json_build_object(
    'users', (select count(*) from public.profiles),
    'social_users', (select count(*) from public.profiles where share_results),
    'conversations', (select count(*) from public.conversations),
    'messages', (select count(*) from public.messages),
    'gift_sends', (select count(*) from public.gift_sends),
    'coins_spent', (select coalesce(sum(-delta), 0) from public.coin_ledger where balance_type = 'coins' and delta < 0),
    'coins_issued', (select coalesce(sum(delta), 0) from public.coin_ledger where balance_type = 'coins' and delta > 0),
    'open_reports', (select count(*) from public.abuse_reports where status = 'open'));
end;
$$;

create or replace function public.am_i_admin() returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin();
$$;

-- ---------- execute privileges: authenticated only
do $$
declare f text;
begin
  foreach f in array array[
    'is_admin()', 'setting_int(text,integer)', 'social_eligible(uuid)', 'my_profile()',
    'save_my_profile(text,text,boolean,boolean,boolean)', 'publish_features(double precision[])',
    'find_similar(integer,integer)', 'start_conversation(uuid)', 'send_message(uuid,text)', 'mark_read(uuid)',
    'touch_presence()', 'my_conversations()', 'block_user(uuid)', 'unblock_user(uuid)', 'blocked_users()',
    'report_user(uuid,uuid,text)', 'my_wallet()', 'claim_daily_coins()', 'send_gift(uuid,uuid,text)',
    'admin_list_reports(text)', 'admin_resolve_report(uuid,text)', 'admin_set_ban(uuid,boolean)',
    'admin_set_setting(text,text)', 'admin_grant_coins(uuid,integer,text)', 'admin_stats()', 'am_i_admin()',
    'is_blocked(uuid,uuid)', 'feature_similarity(double precision[],double precision[])'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- To make yourself an admin (SQL editor, once):
--   insert into public.admin_users (user_id) values ('<your auth.users id>');
