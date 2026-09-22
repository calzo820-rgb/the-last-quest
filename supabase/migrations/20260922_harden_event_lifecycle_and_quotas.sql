create or replace function public.create_event(
  event_name text,
  selected_event_type text,
  protagonist_name text,
  selected_tone text default 'balanced',
  selected_duration text default 'evening'
)
returns table(event_id uuid, join_code text)
language plpgsql security definer set search_path = ''
as $$
declare new_event_id uuid; new_join_code text; attempts int := 0; selected_mode text;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if char_length(trim(event_name)) not between 1 and 120 then raise exception 'Titolo non valido'; end if;
  if char_length(trim(protagonist_name)) not between 1 and 60 then raise exception 'Nome non valido'; end if;
  if selected_event_type not in ('bachelor_party','bachelorette_party','birthday','graduation','trip','weekend','other') then raise exception 'Tipo evento non valido'; end if;
  if (select count(*) from public.events e where e.owner_user_id=auth.uid() and e.purchase_status='unpaid') >= 5 then
    raise exception 'Hai già troppe bozze da completare';
  end if;
  if (select count(*) from public.events e where e.owner_user_id=auth.uid()) >= 100 then
    raise exception 'Limite eventi raggiunto';
  end if;
  selected_mode := case when lower(selected_tone) like 'folle%' then 'insane' else 'classic' end;
  loop
    attempts := attempts + 1;
    new_join_code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from public.events e where e.join_code=new_join_code);
    if attempts > 8 then raise exception 'Impossibile generare il codice'; end if;
  end loop;
  insert into public.events(owner_user_id,name,event_type,game_mode,status,join_code,purchase_status,challenge_mode,target_score)
  values(auth.uid(),trim(event_name),selected_event_type,'group','DRAFT',new_join_code,'unpaid',selected_mode,case when selected_mode='insane' then 200 else 100 end)
  returning id into new_event_id;
  insert into public.participants(event_id,auth_user_id,display_name,role) values(new_event_id,auth.uid(),trim(protagonist_name),'admin');
  insert into public.event_settings(event_id,preferences) values(new_event_id,jsonb_build_object('tone',selected_tone,'duration',selected_duration,'challenge_mode',selected_mode));
  insert into public.protagonists(event_id,display_name) values(new_event_id,trim(protagonist_name));
  insert into public.event_counters(event_id) values(new_event_id);
  return query select new_event_id,new_join_code;
end $$;

revoke all on function public.create_event(text,text,text,text,text) from public,anon;
grant execute on function public.create_event(text,text,text,text,text) to authenticated,service_role;

create or replace function public.generate_event_missions(target_event uuid)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare selected_type text; selected_mode text; event_state text; inserted_count integer;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if not exists(select 1 from public.participants p where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin') then raise exception 'Operazione non autorizzata'; end if;
  select e.event_type,e.challenge_mode,e.status into selected_type,selected_mode,event_state from public.events e where e.id=target_event for update;
  if selected_type is null then raise exception 'Evento non trovato'; end if;
  if event_state <> 'DRAFT' then raise exception 'Le missioni non possono essere rigenerate dopo l’attivazione'; end if;
  if exists(select 1 from public.mission_completions mc where mc.event_id=target_event) then raise exception 'Sono già presenti progressi per questo evento'; end if;
  delete from public.missions m where m.event_id=target_event and m.status <> 'deleted';
  insert into public.missions(event_id,category,mission_type,title,description,points,min_participants,status,metadata)
  select target_event,t.category,'group',t.title,t.description,t.points,t.min_participants,'active',jsonb_build_object('template_id',t.id,'tone',t.tone,'challenge_mode',selected_mode)
  from private.mission_templates t
  where t.event_type=selected_type and t.enabled
    and ((selected_mode='insane' and t.tone='insane') or (selected_mode<>'insane' and t.tone<>'insane'))
  order by t.id;
  get diagnostics inserted_count = row_count;
  return inserted_count;
end $$;

revoke all on function public.generate_event_missions(uuid) from public,anon;
grant execute on function public.generate_event_missions(uuid) to authenticated,service_role;

create or replace function public.toggle_mission(target_mission uuid)
returns text language plpgsql security definer set search_path = ''
as $$
declare target_event uuid; event_state text; current_status text; actor_participant uuid; next_status text;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  select m.event_id,e.status into target_event,event_state
  from public.missions m join public.events e on e.id=m.event_id
  where m.id=target_mission and m.status='active';
  if target_event is null then raise exception 'Missione non trovata'; end if;
  if event_state not in ('READY','ACTIVE') then raise exception 'Evento non modificabile'; end if;
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

revoke all on function public.toggle_mission(uuid) from public,anon;
grant execute on function public.toggle_mission(uuid) to authenticated,service_role;
