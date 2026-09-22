create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.mission_templates (
  id bigint generated always as identity primary key,
  event_type text not null,
  category text not null,
  title text not null,
  description text not null,
  points integer not null check (points between 1 and 50),
  tone text not null default 'balanced',
  min_participants integer,
  enabled boolean not null default true,
  unique(event_type,title)
);

-- The production database contains the curated seed library. This repository
-- keeps the schema and function; export seed data before cloning environments.
create or replace function public.generate_event_missions(target_event uuid)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare selected_type text; inserted_count integer;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if not exists(select 1 from public.participants p where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin') then raise exception 'Operazione non autorizzata'; end if;
  select e.event_type into selected_type from public.events e where e.id=target_event;
  if selected_type is null then raise exception 'Evento non trovato'; end if;
  delete from public.missions m where m.event_id=target_event and m.status <> 'deleted';
  insert into public.missions(event_id,category,mission_type,title,description,points,min_participants,status,metadata)
  select target_event,t.category,'group',t.title,t.description,t.points,t.min_participants,'active',jsonb_build_object('template_id',t.id,'tone',t.tone)
  from private.mission_templates t where t.event_type=selected_type and t.enabled order by t.id;
  get diagnostics inserted_count = row_count;
  return inserted_count;
end $$;

revoke all on function public.generate_event_missions(uuid) from public, anon;
grant execute on function public.generate_event_missions(uuid) to authenticated, service_role;
