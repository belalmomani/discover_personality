-- MANUAL RLS check. Run in Supabase SQL Editor AFTER the migration + seed.
-- It creates two throw-away users, verifies isolation, then rolls everything back.
-- (Not executed by the author: no Supabase project was available.)
begin;

insert into auth.users (id, instance_id, aud, role, email)
values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rls-a@example.test'),
       ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rls-b@example.test');

-- user A writes a session
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
insert into public.assessment_sessions (id, user_id) values ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-0000000000a1');

do $$ begin
  if (select count(*) from public.assessment_sessions) <> 1 then raise exception 'FAIL: A cannot see own session'; end if;
end $$;

-- user A cannot insert a row for user B
do $$ begin
  begin
    insert into public.assessment_sessions (id, user_id) values ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-0000000000b2');
    raise exception 'FAIL: A inserted a row for B';
  exception when insufficient_privilege or others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
end $$;

-- user B sees nothing of A
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.assessment_sessions) <> 0 then raise exception 'FAIL: B can see A data'; end if;
  update public.assessment_sessions set status = 'in_progress' where id = '11111111-1111-4111-8111-111111111111';
  if found then raise exception 'FAIL: B updated A data'; end if;
  delete from public.assessment_sessions where id = '11111111-1111-4111-8111-111111111111';
  if found then raise exception 'FAIL: B deleted A data'; end if;
end $$;

-- questions are readable, not writable
do $$ begin
  if (select count(*) from public.questions) <> 72 then raise exception 'FAIL: questions not seeded (run seed.sql)'; end if;
  begin
    delete from public.questions;
    if found then raise exception 'FAIL: questions deletable'; end if;
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
end $$;

select 'RLS CHECK PASSED' as result;
rollback;
