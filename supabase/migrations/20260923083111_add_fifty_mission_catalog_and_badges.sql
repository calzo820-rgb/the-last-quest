create table if not exists private.mission_categories (
  slug text primary key,
  label text not null unique,
  icon text not null,
  display_order integer not null unique
);

insert into private.mission_categories(slug,label,icon,display_order) values
  ('team','Squadra','🤝',1),
  ('creative','Creatività','🎨',2),
  ('social','Social','🗣️',3),
  ('courage','Coraggio','🔥',4),
  ('finale','Finale','🏆',5)
on conflict(slug) do update set label=excluded.label,icon=excluded.icon,display_order=excluded.display_order;

alter table private.mission_templates
  add column if not exists scope text not null default 'specific' check(scope in ('general','specific')),
  add column if not exists difficulty text not null default 'medium' check(difficulty in ('easy','medium','hard')),
  add column if not exists requires_media boolean not null default true,
  add column if not exists alcohol_related boolean not null default false;

alter table private.mission_templates drop constraint if exists mission_templates_event_type_check;
alter table private.mission_templates add constraint mission_templates_event_type_check
  check(event_type in ('general','bachelor_party','bachelorette_party','birthday','graduation','trip','weekend','other'));

update private.mission_templates set category='Finale' where category='Memoria';
update private.mission_templates set category='Social' where category='Scoperta';
update private.mission_templates
set scope='specific',
    difficulty=case when points<=10 then 'easy' when points<=15 then 'medium' else 'hard' end,
    points=case when points<=10 then 2 when points<=15 then 3 else 5 end
where tone<>'insane';
update private.mission_templates set enabled=false where tone='insane';

insert into private.mission_templates(event_type,category,title,description,points,tone,min_participants,scope,difficulty,requires_media,alcohol_related)
values
('general','Squadra','Il grido ufficiale','Inventate un grido di squadra e registrate una versione perfettamente sincronizzata.',2,'balanced',2,'general','easy',true,false),
('general','Squadra','La formazione','Create una formazione di gruppo riconoscibile e fotografatela da un punto di vista originale.',2,'balanced',3,'general','easy',true,false),
('general','Squadra','Passaggio invisibile','Fate passare un oggetto tra tutti senza mostrarlo direttamente alla videocamera.',3,'balanced',3,'general','medium',true,false),
('general','Squadra','Dieci secondi perfetti','Realizzate un video di dieci secondi in cui tutti eseguono lo stesso movimento nello stesso momento.',3,'balanced',3,'general','medium',true,false),
('general','Squadra','La torre del gruppo','Costruite insieme una piccola struttura usando esclusivamente oggetti disponibili sul posto.',5,'balanced',3,'general','hard',true,false),
('general','Creatività','Titolo da film','Inventate titolo, slogan e locandina vivente del film dedicato al vostro gruppo.',2,'balanced',2,'general','easy',true,false),
('general','Creatività','Pubblicità impossibile','Create uno spot di quindici secondi per promuovere un oggetto scelto casualmente.',3,'balanced',2,'general','medium',true,false),
('general','Creatività','La statua umana','Componete una scultura di gruppo e mantenete la posa per una fotografia.',2,'balanced',3,'general','easy',true,false),
('general','Creatività','Doppiaggio alternativo','Doppiate dal vivo una breve scena senza utilizzare le parole originali.',3,'balanced',2,'general','medium',true,false),
('general','Creatività','Storia in cinque immagini','Raccontate una storia completa usando esattamente cinque fotografie.',5,'balanced',2,'general','hard',true,false),
('general','Social','Il complimento preciso','Fate un complimento sincero e diverso a ogni componente del gruppo.',2,'balanced',2,'general','easy',false,false),
('general','Social','Consiglio dal futuro','Chiedete a una persona esterna un consiglio memorabile per il vostro gruppo.',2,'balanced',2,'general','easy',true,false),
('general','Social','Sondaggio lampo','Raccogliete tre risposte alla stessa domanda curiosa e confrontatele in video.',3,'balanced',2,'general','medium',true,false),
('general','Social','La parola proibita','Convincete una persona esterna a pronunciare una parola scelta dal gruppo senza suggerirla direttamente.',3,'balanced',2,'general','medium',true,false),
('general','Social','Piccolo pubblico','Ottenete, con rispetto e consenso, un applauso da almeno cinque persone.',5,'balanced',3,'general','hard',true,false),
('general','Coraggio','Discorso solenne','Pronunciate un discorso serio di trenta secondi dedicato a un oggetto comune.',2,'balanced',1,'general','easy',true,false),
('general','Coraggio','Karaoke senza base','Cantate insieme un ritornello senza musica per almeno venti secondi.',3,'balanced',2,'general','medium',true,false),
('general','Coraggio','Intervista al campione','Un partecipante risponde a cinque domande come se avesse appena vinto un titolo mondiale.',2,'balanced',2,'general','easy',true,false),
('general','Coraggio','La passerella','Organizzate una breve sfilata di gruppo in un luogo appropriato senza disturbare nessuno.',3,'balanced',3,'general','medium',true,false),
('general','Coraggio','Esibizione autorizzata','Realizzate una piccola esibizione davanti a un pubblico consenziente.',5,'balanced',3,'general','hard',true,false),
('general','Finale','Foto copertina','Scattate la fotografia che potrebbe diventare la copertina ufficiale della Quest.',2,'balanced',2,'general','easy',true,false),
('general','Finale','Messaggio al futuro','Registrate un messaggio del gruppo da riguardare tra un anno.',3,'balanced',2,'general','medium',true,false),
('general','Finale','Premiazione improvvisata','Assegnate a ogni partecipante un premio ironico ma positivo.',3,'balanced',3,'general','medium',true,false),
('general','Finale','Riassunto in trenta secondi','Raccontate tutta l’avventura in un unico video di trenta secondi.',3,'balanced',2,'general','medium',true,false),
('general','Finale','Scena leggendaria','Create una scena conclusiva che coinvolga tutto il gruppo e rappresenti la vostra Quest.',5,'balanced',3,'general','hard',true,false)
on conflict(event_type,title) do update set category=excluded.category,description=excluded.description,points=excluded.points,scope='general',difficulty=excluded.difficulty,requires_media=excluded.requires_media,alcohol_related=false,enabled=true;

insert into private.mission_templates(event_type,category,title,description,points,tone,min_participants,scope,difficulty,requires_media,alcohol_related)
select k.event_type,m.category,m.title,
  replace(m.description,'{OCCASIONE}',k.occasion),m.points,'balanced',m.min_participants,'specific',m.difficulty,true,false
from (values
  ('bachelor_party','addio al celibato'),('bachelorette_party','addio al nubilato'),
  ('birthday','compleanno'),('graduation','laurea'),('trip','viaggio'),
  ('weekend','weekend'),('other','evento')
) k(event_type,occasion)
cross join (values
  ('Squadra','La squadra protagonista','Create un’inquadratura in cui ogni partecipante rappresenta un momento della {OCCASIONE}.',2,2,'easy'),
  ('Squadra','Il patto della Quest','Registrate tutti insieme una promessa divertente da rispettare dopo la {OCCASIONE}.',3,3,'medium'),
  ('Squadra','La missione a catena','Completate cinque azioni consecutive, una per partecipante, senza interrompere la ripresa.',5,3,'hard'),
  ('Creatività','Il manifesto ufficiale','Create il manifesto simbolico della {OCCASIONE} usando persone e oggetti presenti.',3,2,'medium'),
  ('Creatività','La canzone celebrativa','Inventate quattro versi dedicati alla {OCCASIONE} e cantateli insieme.',3,2,'medium'),
  ('Creatività','Il trailer','Registrate un trailer epico di venti secondi sulla {OCCASIONE}.',5,3,'hard'),
  ('Social','La domanda del giorno','Chiedete a tre persone quale sia il segreto per rendere memorabile una {OCCASIONE}.',3,2,'medium'),
  ('Social','Il verdetto esterno','Fate assegnare da una persona esterna un titolo ufficiale al protagonista della {OCCASIONE}.',2,2,'easy'),
  ('Social','La dedica inattesa','Ottenete una breve dedica positiva alla {OCCASIONE} da una persona consenziente.',3,2,'medium'),
  ('Coraggio','La dichiarazione pubblica','Annunciate con tono solenne l’inizio della {OCCASIONE} in un luogo appropriato.',2,1,'easy'),
  ('Coraggio','L’intervista impossibile','Rispondete senza esitazioni a cinque domande ironiche sulla {OCCASIONE}.',3,2,'medium'),
  ('Coraggio','Il minuto da leggenda','Il protagonista conduce un’esibizione di gruppo di almeno sessanta secondi.',5,3,'hard'),
  ('Finale','La frase simbolo','Scegliete e registrate la frase che riassume meglio la {OCCASIONE}.',2,2,'easy'),
  ('Finale','Prima e dopo','Ricreate una foto iniziale mostrando come la {OCCASIONE} ha trasformato il gruppo.',3,3,'medium'),
  ('Finale','I titoli di coda','Registrate dei titoli di coda in cui ogni partecipante racconta il proprio momento preferito.',5,3,'hard'),
  ('Squadra','Il simbolo vivente','Ricreate con i corpi un simbolo collegato alla {OCCASIONE}.',3,3,'medium'),
  ('Creatività','Tre oggetti una storia','Raccontate la {OCCASIONE} inventando una storia che includa tre oggetti scelti casualmente.',3,2,'medium'),
  ('Social','Il consiglio collettivo','Raccogliete tre consigli diversi per il protagonista della {OCCASIONE}.',3,2,'medium')
) m(category,title,description,points,min_participants,difficulty)
on conflict(event_type,title) do update set category=excluded.category,description=excluded.description,points=excluded.points,scope='specific',difficulty=excluded.difficulty,requires_media=true,alcohol_related=false,enabled=true;

do $$
declare constraint_name text;
begin
  select c.conname into constraint_name
  from pg_constraint c join pg_class t on t.oid=c.conrelid join pg_namespace n on n.oid=t.relnamespace
  where n.nspname='public' and t.relname='events' and pg_get_constraintdef(c.oid) like '%mission_weight_percent%';
  if constraint_name is not null then execute format('alter table public.events drop constraint %I',constraint_name); end if;
end $$;

alter table public.events
  add column if not exists diploma_level text not null default 'medium' check(diploma_level in ('easy','medium','hard','impossible')),
  add column if not exists badge_requirement integer not null default 4 check(badge_requirement between 1 and 10),
  add column if not exists max_score integer not null default 0 check(max_score>=0),
  add constraint events_mission_weight_percent_safe check(mission_weight_percent between 50 and 200);

create or replace function private.insert_event_missions(target_event uuid, preview_only boolean)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare selected_type text; selected_weight integer; inserted_count integer;
begin
  select e.event_type,e.mission_weight_percent into selected_type,selected_weight
  from public.events e where e.id=target_event;
  if selected_type is null then raise exception 'Evento non trovato'; end if;
  delete from public.missions m where m.event_id=target_event and m.status<>'deleted';

  with specific_ranked as (
    select t.*,row_number() over(partition by t.category order by t.id) category_rank
    from private.mission_templates t
    where t.event_type=selected_type and t.scope='specific' and t.enabled and t.tone<>'insane'
  ), selected_templates as (
    (select t.* from private.mission_templates t
     where t.event_type='general' and t.scope='general' and t.enabled order by t.id limit 25)
    union all
    (select s.id,s.event_type,s.category,s.title,s.description,s.points,s.tone,s.min_participants,s.enabled,s.scope,s.difficulty,s.requires_media,s.alcohol_related
     from specific_ranked s where s.category_rank<=5 order by s.category,s.id)
  ), preview_templates as (
    select s.*,row_number() over(partition by s.category order by case when s.scope='specific' then 0 else 1 end,s.id) category_position
    from selected_templates s
  ), chosen as (
    select p.* from preview_templates p where not preview_only or p.category_position=1
  )
  insert into public.missions(event_id,category,mission_type,title,description,points,min_participants,status,metadata)
  select target_event,c.category,'group',c.title,c.description,
    greatest(1,round(c.points*selected_weight/100.0)::integer),c.min_participants,'active',
    jsonb_build_object('template_id',c.id,'scope',c.scope,'difficulty',c.difficulty,'preview',preview_only,'base_points',c.points,'requires_media',c.requires_media,'alcohol_related',c.alcohol_related)
  from chosen c
  order by case c.category when 'Squadra' then 1 when 'Creatività' then 2 when 'Social' then 3 when 'Coraggio' then 4 when 'Finale' then 5 else 6 end,c.id;
  get diagnostics inserted_count=row_count;
  return inserted_count;
end $$;

create or replace function private.full_event_max_score(selected_type text,selected_weight integer)
returns integer language sql stable security definer set search_path=''
as $$
  with specific_ranked as (
    select t.points,row_number() over(partition by t.category order by t.id) category_rank
    from private.mission_templates t
    where t.event_type=selected_type and t.scope='specific' and t.enabled and t.tone<>'insane'
  ), chosen as (
    (select t.points from private.mission_templates t where t.event_type='general' and t.scope='general' and t.enabled order by t.id limit 25)
    union all
    (select s.points from specific_ranked s where s.category_rank<=5)
  ) select coalesce(sum(greatest(1,round(points*selected_weight/100.0)::integer)),0)::integer from chosen
$$;

revoke all on function private.full_event_max_score(text,integer) from public,anon,authenticated;
grant execute on function private.full_event_max_score(text,integer) to service_role;

create or replace function public.create_event(event_name text,selected_event_type text,protagonist_name text,selected_tone text default 'balanced',selected_duration text default 'evening')
returns table(event_id uuid,join_code text)
language plpgsql security definer set search_path=''
as $$
declare new_event_id uuid; new_join_code text; attempts int:=0; selected_mode text; selected_level text; selected_badges int; selected_percent numeric; available_score int;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if char_length(trim(event_name)) not between 1 and 120 then raise exception 'Titolo non valido'; end if;
  if char_length(trim(protagonist_name)) not between 1 and 60 then raise exception 'Nome non valido'; end if;
  if selected_event_type not in ('bachelor_party','bachelorette_party','birthday','graduation','trip','weekend','other') then raise exception 'Tipo evento non valido'; end if;
  if (select count(*) from public.events e where e.owner_user_id=auth.uid() and e.purchase_status='unpaid')>=5 then raise exception 'Hai già troppe bozze da completare'; end if;
  if (select count(*) from public.events e where e.owner_user_id=auth.uid())>=100 then raise exception 'Limite eventi raggiunto'; end if;
  selected_mode:=case when lower(selected_tone) like 'folle%' then 'insane' else 'classic' end;
  selected_level:=case when lower(selected_duration) like '%serata%' then 'easy' when lower(selected_duration) like '%giorno%' then 'medium' when lower(selected_duration) like '%weekend%' then 'hard' else 'impossible' end;
  selected_badges:=case selected_level when 'easy' then 2 when 'medium' then 4 when 'hard' then 6 else 10 end;
  selected_percent:=case selected_level when 'easy' then .35 when 'medium' then .50 when 'hard' then .70 else 1 end;
  available_score:=private.full_event_max_score(selected_event_type,100);
  loop attempts:=attempts+1; new_join_code:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)); exit when not exists(select 1 from public.events e where e.join_code=new_join_code); if attempts>8 then raise exception 'Impossibile generare il codice'; end if; end loop;
  insert into public.events(owner_user_id,name,event_type,game_mode,status,join_code,purchase_status,challenge_mode,target_score,mission_weight_percent,diploma_level,badge_requirement,max_score)
  values(auth.uid(),trim(event_name),selected_event_type,'group','DRAFT',new_join_code,'unpaid',selected_mode,ceil(available_score*selected_percent),100,selected_level,selected_badges,available_score)
  returning id into new_event_id;
  insert into public.participants(event_id,auth_user_id,display_name,role) values(new_event_id,auth.uid(),trim(protagonist_name),'admin');
  insert into public.event_settings(event_id,preferences) values(new_event_id,jsonb_build_object('tone',selected_tone,'duration',selected_duration,'challenge_mode',selected_mode));
  insert into public.protagonists(event_id,display_name) values(new_event_id,trim(protagonist_name));
  insert into public.event_counters(event_id) values(new_event_id);
  return query select new_event_id,new_join_code;
end $$;

create or replace function public.update_event_scoring(target_event uuid,new_diploma_level text,new_mission_weight_percent integer)
returns table(target_score integer,mission_weight_percent integer,max_score integer,diploma_level text,badge_requirement integer)
language plpgsql security definer set search_path=''
as $$
declare event_state text; selected_type text; new_max int; required_badges int; target_percent numeric;
begin
  if auth.uid() is null then raise exception 'Accesso richiesto'; end if;
  if new_diploma_level not in ('easy','medium','hard','impossible') then raise exception 'Difficoltà non valida'; end if;
  if new_mission_weight_percent not between 50 and 200 then raise exception 'Peso missioni non valido'; end if;
  if not exists(select 1 from public.participants p where p.event_id=target_event and p.auth_user_id=auth.uid() and p.role='admin') then raise exception 'Operazione non autorizzata'; end if;
  select e.status,e.event_type into event_state,selected_type from public.events e where e.id=target_event for update;
  if event_state not in ('DRAFT','READY') then raise exception 'Il punteggio non è modificabile dopo l’avvio'; end if;
  required_badges:=case new_diploma_level when 'easy' then 2 when 'medium' then 4 when 'hard' then 6 else 10 end;
  target_percent:=case new_diploma_level when 'easy' then .35 when 'medium' then .50 when 'hard' then .70 else 1 end;
  new_max:=private.full_event_max_score(selected_type,new_mission_weight_percent);
  update public.events e set target_score=ceil(new_max*target_percent),mission_weight_percent=new_mission_weight_percent,max_score=new_max,diploma_level=new_diploma_level,badge_requirement=required_badges where e.id=target_event;
  update public.missions m set points=greatest(1,round(coalesce((m.metadata->>'base_points')::numeric,m.points)*new_mission_weight_percent/100.0)::integer) where m.event_id=target_event and m.status<>'deleted';
  return query select e.target_score,e.mission_weight_percent,e.max_score,e.diploma_level,e.badge_requirement from public.events e where e.id=target_event;
end $$;

revoke all on function public.update_event_scoring(uuid,text,integer) from public,anon;
grant execute on function public.update_event_scoring(uuid,text,integer) to authenticated,service_role;
drop function if exists public.update_event_scoring(uuid,integer,integer);

update public.events e set max_score=private.full_event_max_score(e.event_type,e.mission_weight_percent),diploma_level='medium',badge_requirement=4;
update public.events e set target_score=ceil(e.max_score*.50) where e.status='DRAFT';
