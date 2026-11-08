-- VS-018: «Mi suscripción» and payment history of the member (RF-011, RF-016).

create function public.get_my_subscription(p_club_id uuid)
returns table (
  season_name text,
  season_membership_id uuid,
  fee_cents integer,
  status text,
  payment_provider text,
  payment_method text,
  next_charge_cents integer,
  next_charge_on date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_membership public.club_memberships;
begin
  select * into v_membership from public.club_memberships
  where club_id = p_club_id and user_id = (select auth.uid()) and status = 'active';
  if not found then
    raise exception 'not a member' using errcode = '42501';
  end if;

  return query
  select s.name, sm.id, sm.fee_cents,
         case when s.id is null then null else coalesce(sm.status, 'not_renewed') end,
         last_paid.provider, last_paid.method,
         -- Automatic renewals (phase 6) will fill the next charge.
         null::integer, null::date
  from (select 1) one
  left join public.seasons s on s.club_id = p_club_id and s.status = 'active'
  left join public.season_memberships sm
    on sm.season_id = s.id and sm.club_membership_id = v_membership.id
  left join lateral (
    select p.provider, p.method
    from public.payments p
    join public.season_memberships any_sm on any_sm.id = p.season_membership_id
    where any_sm.club_membership_id = v_membership.id and p.status = 'paid'
    order by p.paid_at desc nulls last
    limit 1
  ) last_paid on true;
end;
$$;

create function public.get_my_payments(p_club_id uuid)
returns table (
  payment_id uuid,
  season_name text,
  concept text,
  amount_cents integer,
  payment_date timestamptz,
  status text,
  provider text,
  method text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_membership_id uuid;
begin
  select id into v_membership_id from public.club_memberships
  where club_id = p_club_id and user_id = (select auth.uid()) and status = 'active';
  if v_membership_id is null then
    raise exception 'not a member' using errcode = '42501';
  end if;

  return query
  select p.id, s.name, p.concept, p.amount_cents, coalesce(p.paid_at, p.created_at),
         p.status, p.provider, p.method
  from public.payments p
  join public.season_memberships sm on sm.id = p.season_membership_id
  join public.seasons s on s.id = sm.season_id
  where sm.club_membership_id = v_membership_id
  order by coalesce(p.paid_at, p.created_at) desc;
end;
$$;

revoke execute on function public.get_my_subscription(uuid) from public, anon;
revoke execute on function public.get_my_payments(uuid) from public, anon;
grant execute on function public.get_my_subscription(uuid) to authenticated;
grant execute on function public.get_my_payments(uuid) to authenticated;
