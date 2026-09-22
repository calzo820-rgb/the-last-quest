create unique index if not exists mission_completions_event_mission_unique_idx on public.mission_completions(event_id,mission_id);

create or replace function public.toggle_mission(target_mission uuid)
returns text language plpgsql security definer set search_path = ''
as $$
declare target_event uuid; current_status text; actor_participant uuid; next_status text;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  select m.event_id into target_event from public.missions m where m.id=target_mission and m.status='active';
  if target_event is null then raise exception 'Missione non trovata'; end if;
  select p.id into actor_participant from public.participants p where p.event_id=target_event and p.auth_user_id=auth.uid();
  if actor_participant is null then raise exception 'Non autorizzato'; end if;
  select mc.status into current_status from public.mission_completions mc where mc.event_id=target_event and mc.mission_id=target_mission;
  next_status := case when current_status='completed' then 'cancelled' else 'completed' end;
  insert into public.mission_completions(event_id,mission_id,completed_by,status,completed_at,cancelled_at,cancelled_by)
  values(target_event,target_mission,actor_participant,next_status,now(),case when next_status='cancelled' then now() else null end,case when next_status='cancelled' then actor_participant else null end)
  on conflict(event_id,mission_id) do update set status=excluded.status,
    completed_by=case when excluded.status='completed' then excluded.completed_by else public.mission_completions.completed_by end,
    completed_at=case when excluded.status='completed' then now() else public.mission_completions.completed_at end,
    cancelled_at=case when excluded.status='cancelled' then now() else null end,
    cancelled_by=case when excluded.status='cancelled' then actor_participant else null end;
  return next_status;
end $$;

revoke all on function public.toggle_mission(uuid) from public, anon;
grant execute on function public.toggle_mission(uuid) to authenticated, service_role;
