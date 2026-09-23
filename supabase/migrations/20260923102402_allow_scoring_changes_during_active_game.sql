create or replace function public.update_event_scoring(
  target_event uuid,
  new_target_score integer,
  new_mission_weight_percent integer
)
returns table(
  target_score integer,
  mission_weight_percent integer,
  max_score integer,
  diploma_level text,
  badge_requirement integer
)
language plpgsql
security definer
set search_path=''
as $$
declare
  event_state text;
  selected_type text;
  new_max integer;
  saved_target integer;
  target_ratio numeric;
  selected_level text;
  required_badges integer;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if new_mission_weight_percent not between 50 and 200 then raise exception 'Peso missioni non valido'; end if;
  if new_target_score < 0 then raise exception 'Soglia diploma non valida'; end if;

  if not exists(
    select 1 from public.participants p
    where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin'
  ) then raise exception 'Operazione non autorizzata'; end if;

  select e.status,e.event_type into event_state,selected_type
  from public.events e where e.id=target_event for update;
  if event_state not in ('DRAFT','READY','ACTIVE') then
    raise exception 'Il punteggio non è modificabile dopo la conclusione';
  end if;

  new_max:=private.full_event_max_score(selected_type,new_mission_weight_percent);
  saved_target:=least(new_target_score,new_max);
  target_ratio:=case when new_max>0 then saved_target::numeric/new_max else 0 end;
  selected_level:=case
    when target_ratio<=.35 then 'easy'
    when target_ratio<=.50 then 'medium'
    when target_ratio<1 then 'hard'
    else 'impossible'
  end;
  required_badges:=case selected_level
    when 'easy' then 2 when 'medium' then 4 when 'hard' then 6 else 10
  end;

  update public.events e set
    target_score=saved_target,
    mission_weight_percent=new_mission_weight_percent,
    max_score=new_max,
    diploma_level=selected_level,
    badge_requirement=required_badges
  where e.id=target_event;

  update public.missions m set
    points=greatest(1,round(coalesce((m.metadata->>'base_points')::numeric,m.points)*new_mission_weight_percent/100.0)::integer)
  where m.event_id=target_event and m.status<>'deleted';

  return query select e.target_score,e.mission_weight_percent,e.max_score,e.diploma_level,e.badge_requirement
  from public.events e where e.id=target_event;
end $$;

revoke all on function public.update_event_scoring(uuid,integer,integer) from public,anon;
grant execute on function public.update_event_scoring(uuid,integer,integer) to authenticated,service_role;
