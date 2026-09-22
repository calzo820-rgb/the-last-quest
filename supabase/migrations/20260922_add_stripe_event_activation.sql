alter table public.events
  add column if not exists payment_reference text,
  add column if not exists paid_at timestamptz;

create unique index if not exists events_payment_reference_unique_idx
  on public.events(payment_reference) where payment_reference is not null;

create or replace function public.activate_paid_event(target_event uuid, stripe_session_id text)
returns boolean
language plpgsql security definer set search_path = ''
as $$
begin
  if stripe_session_id is null or char_length(stripe_session_id) < 8 then raise exception 'Riferimento pagamento non valido'; end if;
  update public.events
  set purchase_status='paid', status=case when status='DRAFT' then 'READY' else status end,
      payment_reference=stripe_session_id, paid_at=coalesce(paid_at,now())
  where id=target_event and purchase_status <> 'refunded'
    and (payment_reference is null or payment_reference=stripe_session_id);
  return found;
end $$;

revoke all on function public.activate_paid_event(uuid,text) from public, anon, authenticated;
grant execute on function public.activate_paid_event(uuid,text) to service_role;
