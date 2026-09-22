alter function public.is_event_admin(uuid) set schema private;
alter function public.is_event_member(uuid) set schema private;

grant usage on schema private to authenticated, service_role;
revoke all on function private.is_event_admin(uuid) from public, anon;
revoke all on function private.is_event_member(uuid) from public, anon;
grant execute on function private.is_event_admin(uuid) to authenticated, service_role;
grant execute on function private.is_event_member(uuid) to authenticated, service_role;

drop function if exists public.join_event(uuid,text);
