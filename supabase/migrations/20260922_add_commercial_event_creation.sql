alter table public.events
  add column if not exists join_code text,
  add column if not exists purchase_status text not null default 'unpaid'
    check (purchase_status in ('unpaid','paid','refunded'));

update public.events
set join_code = upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))
where join_code is null;

alter table public.events alter column join_code set not null;
alter table public.events add constraint events_join_code_format check (join_code ~ '^[A-Z0-9]{6,10}$');
create unique index if not exists events_join_code_unique_idx on public.events(join_code);

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
declare new_event_id uuid; new_join_code text; attempts int := 0;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if char_length(trim(event_name)) not between 1 and 120 then raise exception 'Titolo non valido'; end if;
  if char_length(trim(protagonist_name)) not between 1 and 60 then raise exception 'Nome non valido'; end if;
  if selected_event_type not in ('bachelor_party','bachelorette_party','birthday','graduation','trip','weekend','other') then raise exception 'Tipo evento non valido'; end if;
  loop
    attempts := attempts + 1;
    new_join_code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from public.events e where e.join_code=new_join_code);
    if attempts > 8 then raise exception 'Impossibile generare il codice'; end if;
  end loop;
  insert into public.events(owner_user_id,name,event_type,game_mode,status,join_code,purchase_status)
  values(auth.uid(),trim(event_name),selected_event_type,'group','DRAFT',new_join_code,'unpaid') returning id into new_event_id;
  insert into public.participants(event_id,auth_user_id,display_name,role) values(new_event_id,auth.uid(),trim(protagonist_name),'admin');
  insert into public.event_settings(event_id,preferences) values(new_event_id,jsonb_build_object('tone',selected_tone,'duration',selected_duration));
  insert into public.protagonists(event_id,display_name) values(new_event_id,trim(protagonist_name));
  return query select new_event_id,new_join_code;
end $$;

create or replace function public.join_event_by_code(event_code text, participant_name text)
returns table(event_id uuid, participant_id uuid)
language plpgsql security definer set search_path = ''
as $$
declare found_event_id uuid; found_participant_id uuid;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if char_length(trim(participant_name)) not between 1 and 60 then raise exception 'Nome non valido'; end if;
  select e.id into found_event_id from public.events e
  where e.join_code=upper(trim(event_code)) and e.status in ('READY','ACTIVE','COMPLETED','MEMORY');
  if found_event_id is null then raise exception 'Evento non disponibile'; end if;
  insert into public.participants(event_id,auth_user_id,display_name,role)
  values(found_event_id,auth.uid(),trim(participant_name),'participant')
  on conflict(event_id,auth_user_id) do update set display_name=excluded.display_name
  returning id into found_participant_id;
  return query select found_event_id,found_participant_id;
end $$;

revoke all on function public.create_event(text,text,text,text,text) from public, anon;
grant execute on function public.create_event(text,text,text,text,text) to authenticated, service_role;
revoke all on function public.join_event_by_code(text,text) from public, anon;
grant execute on function public.join_event_by_code(text,text) to authenticated, service_role;
