create table if not exists public.mission_media (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  uploaded_by uuid not null references auth.users(id) on delete cascade,
  media_type text not null check (media_type in ('photo','video')),
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null,
  file_size integer not null check (file_size > 0 and file_size <= 52428800),
  created_at timestamptz not null default now()
);

alter table public.mission_media enable row level security;
grant select,insert,delete on public.mission_media to authenticated;
grant all on public.mission_media to service_role;

create policy mission_media_member_select on public.mission_media for select to authenticated using (public.is_event_member(event_id));
create policy mission_media_self_insert on public.mission_media for insert to authenticated with check (
  uploaded_by=(select auth.uid()) and public.is_event_member(event_id)
  and exists(select 1 from public.missions m where m.id=mission_id and m.event_id=event_id)
);
create policy mission_media_owner_delete on public.mission_media for delete to authenticated
using (uploaded_by=(select auth.uid()) or public.is_event_admin(event_id));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('mission-proofs','mission-proofs',false,52428800,array['image/jpeg','image/png','image/webp','video/mp4','video/webm'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy mission_proofs_member_read on storage.objects for select to authenticated using (
  bucket_id='mission-proofs' and exists(select 1 from public.participants p where p.auth_user_id=(select auth.uid()) and p.event_id::text=(storage.foldername(name))[1])
);
create policy mission_proofs_member_upload on storage.objects for insert to authenticated with check (
  bucket_id='mission-proofs' and (storage.foldername(name))[2]=(select auth.uid())::text
  and exists(select 1 from public.participants p where p.auth_user_id=(select auth.uid()) and p.event_id::text=(storage.foldername(name))[1])
);
create policy mission_proofs_owner_delete on storage.objects for delete to authenticated using (
  bucket_id='mission-proofs' and ((storage.foldername(name))[2]=(select auth.uid())::text
  or exists(select 1 from public.participants p where p.auth_user_id=(select auth.uid()) and p.role='admin' and p.event_id::text=(storage.foldername(name))[1]))
);
