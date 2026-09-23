insert into private.mission_templates(event_type,category,title,description,points,tone,min_participants,scope,difficulty,requires_media,alcohol_related)
select event_type,'Coraggio','Il coraggio del protagonista',
  'Il protagonista affronta una prova scelta dal gruppo, sicura e rispettosa, e la racconta in un breve video.',
  3,'balanced',2,'specific','medium',true,false
from (values('bachelor_party'),('bachelorette_party'),('birthday'),('graduation'),('trip'),('weekend'),('other')) kinds(event_type)
on conflict(event_type,title) do update set category=excluded.category,description=excluded.description,points=excluded.points,scope='specific',difficulty='medium',requires_media=true,alcohol_related=false,enabled=true;
