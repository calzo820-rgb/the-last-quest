insert into private.mission_templates(event_type,category,title,description,points,tone,min_participants)
select event_type,category,title,description,points,'balanced',min_participants
from (values
  ('Squadra','Il simbolo del gruppo','Scegliete un oggetto come mascotte dell’evento e realizzate una foto ufficiale tutti insieme.',15,3),
  ('Creatività','La scena muta','Raccontate un momento memorabile in un video di quindici secondi senza pronunciare una parola.',15,2),
  ('Memoria','La storia a staffetta','Inventate una storia: ogni partecipante aggiunge una frase senza sapere come finirà.',15,3),
  ('Social','La catena dei complimenti','Ogni persona dedica un complimento sincero a un altro membro del gruppo, senza ripetizioni.',15,3),
  ('Coraggio','La posa impossibile','Create una posa di gruppo originale e mantenetela per dieci secondi in un’unica ripresa.',15,3),
  ('Scoperta','Il dettaglio nascosto','Trovate nel luogo dell’evento un dettaglio curioso che nessuno aveva ancora notato e fotografatelo.',15,2),
  ('Finale','Capsula del tempo','Registrate insieme un messaggio da riguardare tra un anno, con una previsione per ciascun partecipante.',15,3)
) as mission(category,title,description,points,min_participants)
cross join (values
  ('bachelor_party'),('bachelorette_party'),('birthday'),('graduation'),('trip'),('weekend'),('other')
) as event_kind(event_type)
on conflict(event_type,title) do update set
  category=excluded.category,
  description=excluded.description,
  points=excluded.points,
  tone='balanced',
  min_participants=excluded.min_participants,
  enabled=true;
