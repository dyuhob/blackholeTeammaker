begin;

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
    client_id, name, title, created_at,
    group_count, team_count, group_size, team_size,
    highest_average, deleted_at
  ) values (
    (p_record->>'client_id')::uuid,
    p_record->>'name',
    p_record->>'name',
    (p_record->>'created_at')::timestamptz,
    (p_record->>'group_count')::smallint,
    (p_record->>'group_count')::smallint,
    (p_record->>'group_size')::smallint,
    (p_record->>'group_size')::smallint,
    (p_record->>'highest_average')::numeric,
    null
  )
  on conflict (client_id) do update set
    name = excluded.name,
    title = excluded.title,
    created_at = excluded.created_at,
    group_count = excluded.group_count,
    team_count = excluded.team_count,
    group_size = excluded.group_size,
    team_size = excluded.team_size,
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

grant execute on function public.save_team_record(jsonb) to anon;

notify pgrst, 'reload schema';

commit;
