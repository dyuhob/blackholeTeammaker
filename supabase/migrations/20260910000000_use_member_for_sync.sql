begin;

do $$
begin
  if to_regclass('public.member') is null
     and to_regclass('public."user"') is not null then
    alter table public."user" rename to member;
  end if;

  if to_regclass('public.member') is null then
    raise exception 'public.member table does not exist';
  end if;
end
$$;

alter table public.member
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz,
  add column if not exists deleted_at timestamptz;

do $$
declare
  constraint_row record;
begin
  if to_regclass('public.participants') is null then
    return;
  end if;

  for constraint_row in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    join unnest(c.conkey) key(attnum) on true
    join pg_attribute a on a.attrelid = t.oid and a.attnum = key.attnum
    where n.nspname = 'public'
      and t.relname = 'participants'
      and c.contype = 'f'
      and a.attname = 'user_id'
  loop
    execute format(
      'alter table public.participants drop constraint %I',
      constraint_row.conname
    );
  end loop;
end
$$;

alter table public.member alter column id drop identity if exists;
alter table public.member alter column id drop default;
alter table public.member
  alter column id type varchar using id::varchar;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'participants'
      and column_name = 'user_id'
  ) then
    alter table public.participants alter column user_id drop not null;
    alter table public.participants
      alter column user_id type varchar using user_id::varchar;
  end if;
end
$$;

do $$
declare
  timestamp_column text;
begin
  foreach timestamp_column in array array['created_at', 'updated_at', 'deleted_at']
  loop
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'member'
        and column_name = timestamp_column
        and data_type = 'timestamp without time zone'
    ) then
      execute format(
        'alter table public.member alter column %I type timestamptz '
        'using %I at time zone %L',
        timestamp_column,
        timestamp_column,
        'Asia/Seoul'
      );
    end if;
  end loop;
end
$$;

update public.member
set created_at = coalesce(created_at, now()),
    updated_at = coalesce(updated_at, created_at, now());

alter table public.member
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

create unique index if not exists member_id_unique_idx
  on public.member (id);
create index if not exists member_updated_at_idx
  on public.member (updated_at);

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'participants'
      and column_name = 'user_id'
  ) then
    alter table public.participants
      drop constraint if exists participants_user_id_fkey;
    alter table public.participants
      add constraint participants_user_id_fkey
      foreign key (user_id) references public.member(id) not valid;
  end if;
end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists user_set_updated_at on public.member;
drop trigger if exists member_set_updated_at on public.member;
create trigger member_set_updated_at
before insert or update on public.member
for each row execute function public.set_updated_at();

create or replace function public.delete_member(p_member_id varchar)
returns void
language sql
security invoker
set search_path = public
as $$
  update public.member
  set deleted_at = now()
  where id = p_member_id;
$$;

alter table public.member enable row level security;

grant usage on schema public to anon;
grant select, insert, update, delete on public.member to anon;

drop policy if exists shared_user_select on public.member;
drop policy if exists shared_user_insert on public.member;
drop policy if exists shared_user_update on public.member;
drop policy if exists shared_user_delete on public.member;
drop policy if exists shared_member_select on public.member;
drop policy if exists shared_member_insert on public.member;
drop policy if exists shared_member_update on public.member;
drop policy if exists shared_member_delete on public.member;

create policy shared_member_select on public.member
  for select to anon using (true);
create policy shared_member_insert on public.member
  for insert to anon with check (true);
create policy shared_member_update on public.member
  for update to anon using (true) with check (true);
create policy shared_member_delete on public.member
  for delete to anon using (true);

grant execute on function public.delete_member(varchar) to anon;

notify pgrst, 'reload schema';

commit;

-- Expected result after running this migration:
-- select column_name, data_type, is_nullable
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'member'
-- order by ordinal_position;
