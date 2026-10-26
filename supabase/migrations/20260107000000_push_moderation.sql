-- Push notifications, "delivered" status, automatic content filtering. Run AFTER 20260106000000_catalog_v2.sql. Safe to re-run.
-- * push_tokens is an INTERNAL table (only the Edge Function with the service role reads it).
-- * delivered_at: set when the recipient's app has loaded the message (read implies delivered).
-- * Automatic filter: admin-managed blocked terms + optional "block links" setting (server-enforced trigger).
--   There is NO automatic image moderation (needs a third-party service); images are moderated via reports.

alter table public.messages add column if not exists delivered_at timestamptz;
alter table public.profiles add column if not exists push_enabled boolean not null default false;

insert into public.app_settings (key, value) values ('block_links', '0') on conflict (key) do nothing;

-- ---------- push tokens
create table if not exists public.push_tokens (
  token text primary key check (char_length(token) between 20 and 4096),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'android' check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);
create index if not exists idx_push_tokens_user on public.push_tokens(user_id);
alter table public.push_tokens enable row level security; -- no policies: clients cannot read or write directly
revoke all on public.push_tokens from authenticated, anon;

create or replace function public.register_push_token(p_token text, p_platform text default 'android')
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if char_length(coalesce(p_token, '')) not between 20 and 4096 then raise exception 'invalid_token'; end if;
  if p_platform not in ('android', 'ios', 'web') then raise exception 'invalid_platform'; end if;
  insert into public.push_tokens (token, user_id, platform) values (p_token, auth.uid(), p_platform)
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
  -- keep at most 10 devices per user (newest first)
  delete from public.push_tokens
   where user_id = auth.uid()
     and token not in (select token from public.push_tokens where user_id = auth.uid() order by updated_at desc limit 10);
  update public.profiles set push_enabled = true where id = auth.uid();
end;
$$;

create or replace function public.unregister_push_token(p_token text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from public.push_tokens where token = p_token and user_id = auth.uid();
  if not exists (select 1 from public.push_tokens where user_id = auth.uid()) then
    update public.profiles set push_enabled = false where id = auth.uid();
  end if;
end;
$$;

create or replace function public.disable_push()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from public.push_tokens where user_id = auth.uid();
  update public.profiles set push_enabled = false where id = auth.uid();
end;
$$;

create or replace function public.my_push_enabled()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select push_enabled from public.profiles where id = auth.uid()), false);
$$;

-- ---------- "delivered" status
create or replace function public.mark_delivered()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.messages m set delivered_at = now()
   where m.sender_id <> auth.uid() and m.delivered_at is null
     and exists (select 1 from public.conversations c where c.id = m.conversation_id and auth.uid() in (c.user_a, c.user_b));
end;
$$;

create or replace function public.mark_read(conv uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.messages m set read_at = now(), delivered_at = coalesce(m.delivered_at, now())
   where m.conversation_id = conv and m.sender_id <> auth.uid() and m.read_at is null
     and exists (select 1 from public.conversations c where c.id = conv and auth.uid() in (c.user_a, c.user_b));
end;
$$;

-- ---------- automatic content filter
create table if not exists public.blocked_terms (
  term text primary key check (char_length(term) between 2 and 50 and term = lower(term)),
  created_at timestamptz not null default now()
);
alter table public.blocked_terms enable row level security; -- no policies: managed only through admin functions
revoke all on public.blocked_terms from authenticated, anon;

create or replace function public.message_allowed(p_body text)
returns text language plpgsql stable security definer set search_path = public as $$
declare t text; txt text := lower(coalesce(p_body, ''));
begin
  for t in select term from public.blocked_terms loop
    if position(t in txt) > 0 then return 'content_blocked'; end if;
  end loop;
  if public.setting_int('block_links', 0) = 1
     and txt ~ '(https?://|www\.|[a-z0-9-]+\.(com|net|org|io|me|co|info|xyz|app|ly)\M)' then
    return 'links_blocked';
  end if;
  return null;
end;
$$;

create or replace function public.messages_content_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare r text;
begin
  if new.kind = 'text' then
    r := public.message_allowed(new.body);
    if r is not null then raise exception '%', r; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_messages_content_guard on public.messages;
create trigger trg_messages_content_guard before insert on public.messages
  for each row execute function public.messages_content_guard();

-- ---------- admin: terms, settings (adds block_links), reports with a count of distinct reporters
create or replace function public.admin_list_terms()
returns table (term text) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query select b.term from public.blocked_terms b order by b.term;
end;
$$;

create or replace function public.admin_add_term(p_term text)
returns void language plpgsql security definer set search_path = public as $$
declare t text := lower(btrim(coalesce(p_term, '')));
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if char_length(t) not between 2 and 50 then raise exception 'invalid_term'; end if;
  insert into public.blocked_terms (term) values (t) on conflict (term) do nothing;
end;
$$;

create or replace function public.admin_remove_term(p_term text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  delete from public.blocked_terms where term = lower(btrim(coalesce(p_term, '')));
end;
$$;

create or replace function public.admin_set_setting(k text, v text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if k not in ('daily_free_coins', 'free_gift_daily_limit', 'reward_rate_percent', 'chat_min_similarity', 'block_links') then raise exception 'unknown_setting'; end if;
  if v !~ '^[0-9]{1,6}$' then raise exception 'invalid_value'; end if;
  if k in ('reward_rate_percent', 'chat_min_similarity') and v::integer > 100 then raise exception 'invalid_value'; end if;
  if k = 'block_links' and v::integer > 1 then raise exception 'invalid_value'; end if;
  insert into public.app_settings (key, value) values (k, v)
  on conflict (key) do update set value = excluded.value, updated_at = now();
end;
$$;

drop function if exists public.admin_list_reports(text);
create or replace function public.admin_list_reports(p_status text default 'open')
returns table (id uuid, reporter text, reported_id uuid, reported text, message_body text, reason text, status text, created_at timestamptz, reports_against integer)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
    select r.id, coalesce(rp.username, 'مستخدم'), r.reported_user_id, coalesce(ru.username, 'مستخدم'),
           case when m.kind = 'image' then '[صورة]' else m.body end, r.reason, r.status, r.created_at,
           (select count(distinct r2.reporter_id)::integer from public.abuse_reports r2
             where r2.reported_user_id = r.reported_user_id and r2.status = 'open')
    from public.abuse_reports r
    left join public.profiles rp on rp.id = r.reporter_id
    left join public.profiles ru on ru.id = r.reported_user_id
    left join public.messages m on m.id = r.message_id
    where p_status is null or r.status = p_status
    order by r.created_at desc limit 200;
end;
$$;

-- ---------- execute privileges
do $$
declare f text;
begin
  foreach f in array array[
    'register_push_token(text,text)', 'unregister_push_token(text)', 'disable_push()', 'my_push_enabled()',
    'mark_delivered()', 'mark_read(uuid)', 'admin_list_terms()', 'admin_add_term(text)', 'admin_remove_term(text)',
    'admin_set_setting(text,text)', 'admin_list_reports(text)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  revoke all on function public.message_allowed(text) from public, anon, authenticated;
  revoke all on function public.messages_content_guard() from public, anon, authenticated;
end $$;
