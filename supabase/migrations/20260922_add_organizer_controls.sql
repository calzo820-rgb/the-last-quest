create or replace function public.update_event_mission(target_mission uuid,new_title text,new_description text,new_points integer,new_status text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare target_event uuid; event_state text;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  select m.event_id,e.status into target_event,event_state from public.missions m join public.events e on e.id=m.event_id where m.id=target_mission;
  if target_event is null then raise exception 'Missione non trovata'; end if;
  if not exists(select 1 from public.participants p where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin') then raise exception 'Non autorizzato'; end if;
  if char_length(trim(new_title)) not between 2 and 100 or char_length(trim(new_description)) not between 5 and 500 then raise exception 'Testo non valido'; end if;
  if new_points not between 1 and 50 or new_status not in ('active','inactive') then raise exception 'Valori non validi'; end if;
  if event_state in ('COMPLETED','MEMORY') then raise exception 'Evento già concluso'; end if;
  update public.missions set title=trim(new_title),description=trim(new_description),points=new_points,status=new_status where id=target_mission;
  return found;
end $$;

revoke all on function public.update_event_mission(uuid,text,text,integer,text) from public,anon;
grant execute on function public.update_event_mission(uuid,text,text,integer,text) to authenticated,service_role;

create or replace function public.set_event_status(target_event uuid,new_status text)
returns text language plpgsql security definer set search_path=''
as $$
declare current_status text; paid text;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if not exists(select 1 from public.participants p where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin') then raise exception 'Non autorizzato'; end if;
  select e.status,e.purchase_status into current_status,paid from public.events e where e.id=target_event for update;
  if current_status is null then raise exception 'Evento non trovato'; end if;
  if paid <> 'paid' and new_status <> 'DRAFT' then raise exception 'Evento non pagato'; end if;
  if not ((current_status='DRAFT' and new_status='READY') or (current_status='READY' and new_status='ACTIVE') or (current_status='ACTIVE' and new_status='COMPLETED') or (current_status='COMPLETED' and new_status='MEMORY') or current_status=new_status) then raise exception 'Transizione non consentita'; end if;
  update public.events set status=new_status,completed_at=case when new_status='COMPLETED' then now() else completed_at end where id=target_event;
  return new_status;
end $$;

revoke all on function public.set_event_status(uuid,text) from public,anon;
grant execute on function public.set_event_status(uuid,text) to authenticated,service_role;
