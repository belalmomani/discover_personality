-- Chat images. Run AFTER 20260103000000_similarity_v2.sql. Safe to re-run.
-- * Private Storage bucket `chat-images`: max 2 MB, only JPEG / PNG / WebP (enforced by Storage).
-- * Path format: <sender uuid>/<conversation uuid>/<uuid>.<jpg|png|webp>
-- * Only participants of the conversation can upload / read (via short-lived signed URLs).
-- * A message is created only by send_image_message(), which re-checks the stored object
--   (exists, size, mime type, owner path), blocks, bans, chat switch and rate limits.
-- Limitation: Storage trusts the declared content-type; the app also verifies the real file signature
--   (magic bytes) before upload, and images are only ever shown through an image decoder.

alter table public.messages drop constraint if exists messages_kind_check;
alter table public.messages add constraint messages_kind_check check (kind in ('text', 'gift', 'image'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-images', 'chat-images', false, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- ---------- path helpers (policy functions)
create or replace function public.chat_image_path_ok(p_name text)
returns boolean language sql immutable as $$
  select p_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$';
$$;

create or replace function public.chat_image_can_upload(p_name text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare conv uuid; c public.conversations; other uuid;
begin
  if auth.uid() is null or not public.chat_image_path_ok(p_name) then return false; end if;
  if split_part(p_name, '/', 1) <> auth.uid()::text then return false; end if;
  conv := split_part(p_name, '/', 2)::uuid;
  select * into c from public.conversations where id = conv and auth.uid() in (user_a, user_b);
  if not found then return false; end if;
  other := case when c.user_a = auth.uid() then c.user_b else c.user_a end;
  if public.is_blocked(auth.uid(), other) then return false; end if;
  if exists (select 1 from public.profiles where id in (c.user_a, c.user_b) and (banned or not allow_chat)) then return false; end if;
  if (select count(*) from public.messages where sender_id = auth.uid() and kind = 'image' and created_at > now() - interval '1 hour') >= 20 then
    return false;
  end if;
  return true;
end;
$$;

create or replace function public.chat_image_can_read(p_name text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare conv uuid;
begin
  if auth.uid() is null or not public.chat_image_path_ok(p_name) then return false; end if;
  conv := split_part(p_name, '/', 2)::uuid;
  return exists (select 1 from public.conversations c where c.id = conv and auth.uid() in (c.user_a, c.user_b));
end;
$$;

drop policy if exists chat_images_insert on storage.objects;
create policy chat_images_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-images' and public.chat_image_can_upload(name));
drop policy if exists chat_images_select on storage.objects;
create policy chat_images_select on storage.objects for select to authenticated
  using (bucket_id = 'chat-images' and public.chat_image_can_read(name));
drop policy if exists chat_images_delete on storage.objects;
create policy chat_images_delete on storage.objects for delete to authenticated
  using (bucket_id = 'chat-images' and split_part(name, '/', 1) = auth.uid()::text);

-- ---------- the only way to create an image message
create or replace function public.send_image_message(conv uuid, p_path text)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.conversations; other uuid; mid uuid; sz bigint; mt text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into c from public.conversations where id = conv and auth.uid() in (user_a, user_b);
  if not found then raise exception 'forbidden'; end if;
  other := case when c.user_a = auth.uid() then c.user_b else c.user_a end;
  if public.is_blocked(auth.uid(), other) then raise exception 'blocked'; end if;
  if exists (select 1 from public.profiles where id = auth.uid() and banned) then raise exception 'banned'; end if;
  if p_path is null or not public.chat_image_path_ok(p_path)
     or split_part(p_path, '/', 1) <> auth.uid()::text or split_part(p_path, '/', 2) <> conv::text then
    raise exception 'invalid_image';
  end if;
  select (o.metadata->>'size')::bigint, o.metadata->>'mimetype' into sz, mt
    from storage.objects o where o.bucket_id = 'chat-images' and o.name = p_path;
  if not found then raise exception 'invalid_image'; end if;
  if sz is null or sz <= 0 or sz > 2097152 or mt not in ('image/jpeg', 'image/png', 'image/webp') then
    raise exception 'invalid_image';
  end if;
  if (select count(*) from public.messages where sender_id = auth.uid() and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'rate_limited';
  end if;
  if (select count(*) from public.messages where sender_id = auth.uid() and kind = 'image' and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'image_limit';
  end if;
  insert into public.messages (conversation_id, sender_id, kind, body) values (conv, auth.uid(), 'image', p_path) returning id into mid;
  update public.conversations set last_message_at = now() where id = conv;
  return mid;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array['chat_image_path_ok(text)', 'chat_image_can_upload(text)', 'chat_image_can_read(text)', 'send_image_message(uuid,text)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
