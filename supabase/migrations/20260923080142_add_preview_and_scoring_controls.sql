alter table public.events
  add column if not exists mission_weight_percent integer not null default 100
  check (mission_weight_percent between 50 and 150);

create or replace function private.insert_event_missions(target_event uuid, preview_only boolean)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  selected_type text;
  selected_mode text;
  selected_weight integer;
  inserted_count integer;
begin
  select e.event_type,e.challenge_mode,e.mission_weight_percent
  into selected_type,selected_mode,selected_weight
  from public.events e where e.id=target_event;
  if selected_type is null then raise exception 'Evento non trovato'; end if;

  delete from public.missions m where m.event_id=target_event and m.status <> 'deleted';

  with eligible as (
    select t.*,
      row_number() over(partition by t.category order by t.id) as category_position
    from private.mission_templates t
    where t.event_type=selected_type and t.enabled
      and (
        (preview_only and t.tone <> 'insane') or
        (not preview_only and ((selected_mode='insane' and t.tone='insane') or (selected_mode<>'insane' and t.tone<>'insane')))
      )
  ), chosen as (
    select e.*
    from eligible e
    where not preview_only or (
      e.category_position=1 and e.category in ('Squadra','Creatività','Social','Coraggio','Finale')
    )
  ), proportional as (
    select c.*,
      floor(c.points * 100.0 / nullif(sum(c.points) over(),0))::integer as floor_points,
      (c.points * 100.0 / nullif(sum(c.points) over(),0)) - floor(c.points * 100.0 / nullif(sum(c.points) over(),0)) as fraction
    from chosen c
  ), normalized as (
    select p.*,
      p.floor_points + case
        when row_number() over(order by p.fraction desc,p.id) <= 100-sum(p.floor_points) over() then 1
        else 0
      end as base_points
    from proportional p
  )
  insert into public.missions(event_id,category,mission_type,title,description,points,min_participants,status,metadata)
  select target_event,n.category,'group',n.title,n.description,
    greatest(1,round(n.base_points * selected_weight / 100.0)::integer),
    n.min_participants,'active',
    jsonb_build_object('template_id',n.id,'tone',n.tone,'challenge_mode',selected_mode,'preview',preview_only,'base_points',n.base_points)
  from normalized n
  order by case n.category
    when 'Squadra' then 1 when 'Creatività' then 2 when 'Social' then 3
    when 'Coraggio' then 4 when 'Finale' then 5 else 6 end,n.id;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end $$;

revoke all on function private.insert_event_missions(uuid,boolean) from public,anon,authenticated;
grant execute on function private.insert_event_missions(uuid,boolean) to service_role;

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
  insert into public.events(owner_user_id,name,event_type,game_mode,status,join_code,purchase_status,challenge_mode,target_score,mission_weight_percent)
  values(auth.uid(),trim(event_name),selected_event_type,'group','DRAFT',new_join_code,'unpaid',selected_mode,100,100)
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
declare event_state text; inserted_count integer;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if not exists(select 1 from public.participants p where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin') then
    raise exception 'Operazione non autorizzata';
  end if;
  select e.status into event_state from public.events e where e.id=target_event for update;
  if event_state is null then raise exception 'Evento non trovato'; end if;
  if event_state <> 'DRAFT' then raise exception 'Le missioni non possono essere rigenerate dopo l’attivazione'; end if;
  if exists(select 1 from public.mission_completions mc where mc.event_id=target_event) then
    raise exception 'Sono già presenti progressi per questo evento';
  end if;
  inserted_count := private.insert_event_missions(target_event,true);
  return inserted_count;
end $$;

revoke all on function public.generate_event_missions(uuid) from public,anon;
grant execute on function public.generate_event_missions(uuid) to authenticated,service_role;

create or replace function public.update_event_scoring(target_event uuid,new_target_score integer,new_mission_weight_percent integer)
returns table(target_score integer,mission_weight_percent integer,total_mission_points integer)
language plpgsql security definer set search_path = ''
as $$
declare event_state text;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if new_target_score not between 60 and 100 then raise exception 'La soglia diploma deve essere tra 60 e 100'; end if;
  if new_mission_weight_percent not between 50 and 150 then raise exception 'Il peso missioni deve essere tra 50 e 150'; end if;
  if not exists(select 1 from public.participants p where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin') then
    raise exception 'Operazione non autorizzata';
  end if;
  select e.status into event_state from public.events e where e.id=target_event for update;
  if event_state not in ('DRAFT','READY') then raise exception 'Il punteggio non è modificabile dopo l’avvio'; end if;

  update public.events e set target_score=new_target_score,mission_weight_percent=new_mission_weight_percent where e.id=target_event;
  update public.missions m
  set points=greatest(1,round(coalesce((m.metadata->>'base_points')::numeric,m.points) * new_mission_weight_percent / 100.0)::integer)
  where m.event_id=target_event and m.status <> 'deleted';

  return query
  select e.target_score,e.mission_weight_percent,coalesce(sum(m.points) filter(where m.status='active'),0)::integer
  from public.events e left join public.missions m on m.event_id=e.id
  where e.id=target_event group by e.id;
end $$;

revoke all on function public.update_event_scoring(uuid,integer,integer) from public,anon;
grant execute on function public.update_event_scoring(uuid,integer,integer) to authenticated,service_role;

create or replace function public.activate_paid_event(target_event uuid, stripe_session_id text)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare activated boolean;
begin
  if stripe_session_id is null or char_length(stripe_session_id) < 8 then raise exception 'Riferimento pagamento non valido'; end if;
  update public.events
  set purchase_status='paid',status=case when status='DRAFT' then 'READY' else status end,
      payment_reference=stripe_session_id,paid_at=coalesce(paid_at,now())
  where id=target_event and purchase_status <> 'refunded'
    and (payment_reference is null or payment_reference=stripe_session_id)
  returning true into activated;
  if coalesce(activated,false) and exists(
    select 1 from public.missions m where m.event_id=target_event and coalesce((m.metadata->>'preview')::boolean,false)
  ) then
    perform private.insert_event_missions(target_event,false);
  end if;
  return coalesce(activated,false);
end $$;

revoke all on function public.activate_paid_event(uuid,text) from public,anon,authenticated;
grant execute on function public.activate_paid_event(uuid,text) to service_role;

update public.events set target_score=100 where target_score>100 and status='DRAFT';
