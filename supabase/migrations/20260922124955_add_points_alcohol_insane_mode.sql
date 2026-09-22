alter table public.events
  add column if not exists challenge_mode text not null default 'classic'
    check (challenge_mode in ('classic','insane')),
  add column if not exists target_score integer not null default 100
    check (target_score between 1 and 1000);

create table if not exists public.event_counters (
  event_id uuid primary key references public.events(id) on delete cascade,
  alcohol_count integer not null default 0 check (alcohol_count between 0 and 200),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
create index if not exists event_counters_updated_by_idx on public.event_counters(updated_by);

alter table public.event_counters enable row level security;
grant select on public.event_counters to authenticated;
grant all on public.event_counters to service_role;

drop policy if exists event_counters_member_select on public.event_counters;
create policy event_counters_member_select on public.event_counters
for select to authenticated using (private.is_event_member(event_id));

insert into public.event_counters(event_id)
select id from public.events
on conflict(event_id) do nothing;

create or replace function public.change_alcohol_count(target_event uuid, change_by integer)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare new_count integer;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if change_by not in (-1,1) then raise exception 'Variazione non valida'; end if;
  if not exists(
    select 1 from public.participants p
    join public.events e on e.id=p.event_id
    where p.event_id=target_event and p.auth_user_id=auth.uid() and e.status in ('READY','ACTIVE')
  ) then raise exception 'Evento non disponibile'; end if;
  if change_by=-1 and not exists(
    select 1 from public.participants p
    where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin'
  ) then raise exception 'Solo l’organizzatore può correggere il conteggio'; end if;
  insert into public.event_counters(event_id,alcohol_count,updated_at,updated_by)
  values(target_event,greatest(0,change_by),now(),auth.uid())
  on conflict(event_id) do update set
    alcohol_count=greatest(0,least(200,public.event_counters.alcohol_count+change_by)),
    updated_at=now(),updated_by=auth.uid()
  returning alcohol_count into new_count;
  return new_count;
end $$;

revoke all on function public.change_alcohol_count(uuid,integer) from public,anon;
grant execute on function public.change_alcohol_count(uuid,integer) to authenticated,service_role;

insert into private.mission_templates(event_type,category,title,description,points,tone,min_participants)
select event_type,category,title,description,points,'insane',min_participants
from (values
  ('Social','La folla vi segue','Coinvolgete almeno quindici persone consenzienti in un coro dedicato al protagonista.',35,4),
  ('Creatività','Trailer da festival','Girate e montate un trailer di 60 secondi con almeno cinque scene, titoli e colonna sonora originale.',40,3),
  ('Squadra','Un solo movimento','Realizzate una coreografia continua di due minuti con tutto il gruppo, senza tagli e senza errori.',45,4),
  ('Coraggio','Il palco improvvisato','Ottenete il permesso di esibirvi davanti a un pubblico e completate un numero di almeno novanta secondi.',50,2),
  ('Social','Giro del mondo','Registrate auguri per il protagonista in dieci lingue diverse, pronunciati da persone consenzienti.',40,2),
  ('Creatività','Cinema in presa unica','Ricreate una scena famosa in un unico piano sequenza di almeno un minuto.',35,3),
  ('Squadra','La catena impossibile','Completate cinque mini-prove consecutive coinvolgendo ogni membro del gruppo senza interruzioni.',45,4),
  ('Coraggio','Finale leggendario','Create un finale pubblico memorabile che riunisca almeno venti persone consenzienti nella stessa inquadratura.',50,5)
) as challenge(category,title,description,points,min_participants)
cross join (values
  ('bachelor_party'),('bachelorette_party'),('birthday'),('graduation'),('trip'),('weekend'),('other')
) as event_kind(event_type)
on conflict(event_type,title) do update set
  category=excluded.category,description=excluded.description,points=excluded.points,
  tone='insane',min_participants=excluded.min_participants,enabled=true;

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
declare selected_type text; selected_mode text; inserted_count integer;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if not exists(select 1 from public.participants p where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin') then raise exception 'Operazione non autorizzata'; end if;
  select e.event_type,e.challenge_mode into selected_type,selected_mode from public.events e where e.id=target_event;
  if selected_type is null then raise exception 'Evento non trovato'; end if;
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

do $$
begin
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='event_counters'
  ) then alter publication supabase_realtime add table public.event_counters; end if;
end $$;
