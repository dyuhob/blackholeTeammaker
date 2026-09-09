begin;

create extension if not exists pgcrypto;

do $$
begin
  if to_regclass('public."user"') is null
     and to_regclass('public.member') is not null then
    alter table public.member rename to "user";
  end if;
end
$$;

alter table public."user"
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz,
  add column if not exists deleted_at timestamptz;
alter table public.game
  add column if not exists client_id uuid,
  add column if not exists name text,
  add column if not exists group_count smallint,
  add column if not exists group_size smallint,
  add column if not exists highest_average numeric,
  add column if not exists updated_at timestamptz,
  add column if not exists deleted_at timestamptz;
alter table public.participants
  add column if not exists client_id text,
  add column if not exists game_id bigint,
  add column if not exists updated_at timestamptz,
  add column if not exists deleted_at timestamptz;

do $$
declare
  constraint_row record;
begin
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

alter table public.participants alter column user_id drop not null;
alter table public."user"
  alter column id type varchar using id::varchar;
alter table public.participants
  alter column user_id type varchar using user_id::varchar;

do $$
declare
  timestamp_column record;
begin
  for timestamp_column in
    select *
    from (values
      ('user', 'created_at'),
      ('user', 'updated_at'),
      ('user', 'deleted_at'),
      ('game', 'created_at'),
      ('game', 'updated_at'),
      ('game', 'deleted_at'),
      ('participants', 'updated_at'),
      ('participants', 'deleted_at')
    ) columns_to_convert(table_name, column_name)
  loop
    if exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = timestamp_column.table_name
        and c.column_name = timestamp_column.column_name
        and c.data_type = 'timestamp without time zone'
    ) then
      execute format(
        'alter table public.%I alter column %I type timestamptz '
        'using %I at time zone %L',
        timestamp_column.table_name,
        timestamp_column.column_name,
        timestamp_column.column_name,
        'Asia/Seoul'
      );
    end if;
  end loop;
end
$$;

update public.game
set name = coalesce(name, title, '팀 편성'),
    group_count = coalesce(group_count, team_count::smallint),
    group_size = coalesce(group_size, team_size::smallint);

update public.game game_row
set highest_average = score.highest_average
from (
  select game_id, max(team_average) as highest_average
  from (
    select game_id, team_no, sum(average) as team_average
    from public.participants
    where deleted_at is null
    group by game_id, team_no
  ) team_scores
  group by game_id
) score
where game_row.id = score.game_id
  and game_row.highest_average is null;

update public.game
set highest_average = 0
where highest_average is null;

update public."user"
set created_at = coalesce(created_at, now()),
    updated_at = coalesce(updated_at, created_at, now());
update public.game
set client_id = coalesce(client_id, gen_random_uuid()),
    created_at = coalesce(created_at, now()),
    updated_at = coalesce(updated_at, created_at, now());
update public.participants
set client_id = coalesce(client_id, gen_random_uuid()::text),
    updated_at = coalesce(updated_at, now());

alter table public."user"
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;
alter table public.game
  alter column client_id set not null,
  alter column name set not null,
  alter column group_count set not null,
  alter column group_size set not null,
  alter column highest_average set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;
alter table public.participants
  alter column client_id set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

create sequence if not exists public.game_id_seq;
alter sequence public.game_id_seq owned by public.game.id;
do $$
declare
  maximum_id bigint;
begin
  select max(id) into maximum_id from public.game;
  perform setval(
    'public.game_id_seq',
    greatest(coalesce(maximum_id, 1), 1),
    maximum_id is not null
  );
end
$$;
alter table public.game
  alter column id set default nextval('public.game_id_seq');

create unique index if not exists user_id_unique_idx
  on public."user" (id);
create unique index if not exists game_id_unique_idx
  on public.game (id);
create unique index if not exists game_client_id_unique_idx
  on public.game (client_id);
create unique index if not exists participants_game_client_unique_idx
  on public.participants (game_id, client_id);
create index if not exists user_updated_at_idx
  on public."user" (updated_at);
create index if not exists game_updated_at_idx
  on public.game (updated_at);
create index if not exists participants_game_id_idx
  on public.participants (game_id);

alter table public.participants
  drop constraint if exists participants_game_id_fkey;
alter table public.participants
  add constraint participants_game_id_fkey
  foreign key (game_id) references public.game(id) not valid;
alter table public.participants
  add constraint participants_user_id_fkey
  foreign key (user_id) references public."user"(id) not valid;

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

drop trigger if exists user_set_updated_at on public."user";
create trigger user_set_updated_at
before insert or update on public."user"
for each row execute function public.set_updated_at();

create or replace function public.delete_member(p_member_id varchar)
returns void
language sql
security invoker
set search_path = public
as $$
  update public."user"
  set deleted_at = now()
  where id = p_member_id;
$$;

create or replace function public.save_team_record(p_record jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  saved_game_id bigint;
  participant jsonb;
  active_participant_ids text[] := array[]::text[];
begin
  insert into public.game (
    client_id, name, created_at, group_count, group_size,
    highest_average, deleted_at
  ) values (
    (p_record->>'client_id')::uuid,
    p_record->>'name',
    (p_record->>'created_at')::timestamptz,
    (p_record->>'group_count')::smallint,
    (p_record->>'group_size')::smallint,
    (p_record->>'highest_average')::numeric,
    null
  )
  on conflict (client_id) do update set
    name = excluded.name,
    group_count = excluded.group_count,
    group_size = excluded.group_size,
    highest_average = excluded.highest_average,
    deleted_at = null
  returning id into saved_game_id;

  for participant in
    select value from jsonb_array_elements(p_record->'participants')
  loop
    active_participant_ids := array_append(
      active_participant_ids,
      participant->>'client_id'
    );
    insert into public.participants (
      game_id, client_id, user_id, name, average,
      team_no, auto_insert, deleted_at
    ) values (
      saved_game_id,
      participant->>'client_id',
      nullif(participant->>'user_id', ''),
      participant->>'name',
      (participant->>'average')::integer,
      (participant->>'team_no')::bigint,
      nullif(participant->>'auto_insert', '')::smallint,
      null
    )
    on conflict (game_id, client_id) do update set
      user_id = excluded.user_id,
      name = excluded.name,
      average = excluded.average,
      team_no = excluded.team_no,
      auto_insert = excluded.auto_insert,
      deleted_at = null;
  end loop;

  update public.participants
  set deleted_at = now()
  where game_id = saved_game_id
    and deleted_at is null
    and not (client_id = any(active_participant_ids));

  return jsonb_build_object(
    'id', saved_game_id,
    'client_id', p_record->>'client_id'
  );
end;
$$;

create or replace function public.delete_team_record(
  p_record_client_id uuid
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  deleted_game_id bigint;
begin
  update public.game
  set deleted_at = now()
  where client_id = p_record_client_id
  returning id into deleted_game_id;

  if deleted_game_id is not null then
    update public.participants
    set deleted_at = now()
    where game_id = deleted_game_id;
  end if;
end;
$$;
drop trigger if exists game_set_updated_at on public.game;
create trigger game_set_updated_at
before insert or update on public.game
for each row execute function public.set_updated_at();
drop trigger if exists participants_set_updated_at on public.participants;
create trigger participants_set_updated_at
before insert or update on public.participants
for each row execute function public.set_updated_at();

alter table public."user" enable row level security;
alter table public.game enable row level security;
alter table public.participants enable row level security;

grant usage on schema public to anon;
grant select, insert, update, delete on public."user" to anon;
grant select, insert, update, delete on public.game to anon;
grant select, insert, update, delete on public.participants to anon;
grant usage, select on sequence public.game_id_seq to anon;

drop policy if exists shared_user_select on public."user";
drop policy if exists shared_user_insert on public."user";
drop policy if exists shared_user_update on public."user";
drop policy if exists shared_user_delete on public."user";
create policy shared_user_select on public."user"
  for select to anon using (true);
create policy shared_user_insert on public."user"
  for insert to anon with check (true);
create policy shared_user_update on public."user"
  for update to anon using (true) with check (true);
create policy shared_user_delete on public."user"
  for delete to anon using (true);

drop policy if exists shared_game_select on public.game;
drop policy if exists shared_game_insert on public.game;
drop policy if exists shared_game_update on public.game;
drop policy if exists shared_game_delete on public.game;
create policy shared_game_select on public.game
  for select to anon using (true);
create policy shared_game_insert on public.game
  for insert to anon with check (true);
create policy shared_game_update on public.game
  for update to anon using (true) with check (true);
create policy shared_game_delete on public.game
  for delete to anon using (true);

drop policy if exists shared_participants_select on public.participants;
drop policy if exists shared_participants_insert on public.participants;
drop policy if exists shared_participants_update on public.participants;
drop policy if exists shared_participants_delete on public.participants;
create policy shared_participants_select on public.participants
  for select to anon using (true);
create policy shared_participants_insert on public.participants
  for insert to anon with check (true);
create policy shared_participants_update on public.participants
  for update to anon using (true) with check (true);
create policy shared_participants_delete on public.participants
  for delete to anon using (true);

grant execute on function public.delete_member(varchar) to anon;
grant execute on function public.save_team_record(jsonb) to anon;
grant execute on function public.delete_team_record(uuid) to anon;

commit;

-- Verification after applying this migration:
-- select table_name, column_name, data_type, is_nullable
-- from information_schema.columns
-- where table_schema = 'public'
--   and table_name in ('user', 'game', 'participants')
-- order by table_name, ordinal_position;
--
-- select tablename, policyname, roles, cmd
-- from pg_policies
-- where schemaname = 'public'
-- order by tablename, policyname;
--
-- select routine_name
-- from information_schema.routines
-- where routine_schema = 'public'
--   and routine_name in (
--     'delete_member', 'save_team_record', 'delete_team_record'
--   );
