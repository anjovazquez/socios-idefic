-- VS-021: online payments with Stripe Connect (ADR-001). The money goes to
-- the club's connected account; the webhook is the only source of truth.

alter table public.clubs
  add column stripe_account_id text unique,
  add column stripe_charges_enabled boolean not null default false;

-- Provider events already applied (idempotency of the webhook).
create table public.payment_provider_events (
  id text primary key,
  provider text not null check (provider in ('stripe')),
  type text not null,
  payment_id uuid references public.payments (id) on delete set null,
  received_at timestamptz not null default now()
);
alter table public.payment_provider_events enable row level security;
-- No policies: only the service role writes and reads it.

create index payments_provider_reference_idx on public.payments (provider, provider_reference);

-- Admin: status of the online payments of the club.
create function public.get_club_online_payments(p_club_id uuid)
returns table (stripe_account_id text, charges_enabled boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  return query
  select c.stripe_account_id, c.stripe_charges_enabled
  from public.clubs c where c.id = p_club_id;
end;
$$;

-- Service role (onboarding function and `account.updated` webhook).
create function public.set_club_stripe_account(
  p_club_id uuid,
  p_account_id text,
  p_charges_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_club_id is null then
    update public.clubs set stripe_charges_enabled = coalesce(p_charges_enabled, false)
    where stripe_account_id = p_account_id;
    return;
  end if;
  update public.clubs
  set stripe_account_id = p_account_id,
      stripe_charges_enabled = coalesce(p_charges_enabled, false)
  where id = p_club_id;
  if not found then
    raise exception 'club not found' using errcode = 'P0002';
  end if;
  perform public.audit(p_club_id, 'stripe_account_linked',
    jsonb_build_object('account', p_account_id, 'charges_enabled', p_charges_enabled));
end;
$$;

-- Member: opens (or reuses) the pending online payment of their fee.
create function public.prepare_online_payment(p_season_membership_id uuid)
returns table (
  payment_id uuid,
  amount_cents integer,
  concept text,
  stripe_account_id text,
  club_name text,
  member_email text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_sm public.season_memberships;
  v_owner uuid;
  v_club public.clubs;
  v_season_name text;
  v_email text;
  v_payment_id uuid;
  v_concept text;
begin
  select * into v_sm from public.season_memberships where id = p_season_membership_id;
  if not found then
    raise exception 'season membership not found' using errcode = 'P0002';
  end if;
  select cm.user_id, s.name into v_owner, v_season_name
  from public.club_memberships cm
  join public.seasons s on s.id = v_sm.season_id
  where cm.id = v_sm.club_membership_id and cm.status = 'active';
  if v_owner is distinct from (select auth.uid()) then
    raise exception 'not your fee' using errcode = '42501';
  end if;
  select c.* into v_club
  from public.club_memberships cm join public.clubs c on c.id = cm.club_id
  where cm.id = v_sm.club_membership_id;
  if v_club.stripe_account_id is null or not v_club.stripe_charges_enabled then
    raise exception 'online payments not enabled' using errcode = 'P0001', hint = 'online_payments_disabled';
  end if;
  if v_sm.status <> 'pending_payment' or coalesce(v_sm.fee_cents, 0) <= 0 then
    raise exception 'nothing to pay' using errcode = 'P0001', hint = 'not_payable';
  end if;
  if exists (select 1 from public.payments where season_membership_id = v_sm.id and status = 'paid') then
    raise exception 'already paid' using errcode = 'P0001', hint = 'already_paid';
  end if;

  select email into v_email from public.profiles where id = v_owner;
  v_concept := 'Cuota de socio ' || v_season_name;

  -- Reuse the pending Stripe payment (e.g. Checkout reopened); failed ones
  -- stay as they are and a retry opens a new payment.
  select id into v_payment_id from public.payments
  where season_membership_id = v_sm.id and provider = 'stripe' and status = 'pending'
  order by created_at desc limit 1;
  if v_payment_id is null then
    insert into public.payments (season_membership_id, amount_cents, concept, status, provider, created_by)
    values (v_sm.id, v_sm.fee_cents, v_concept, 'pending', 'stripe', v_owner)
    returning id into v_payment_id;
  else
    update public.payments set amount_cents = v_sm.fee_cents, updated_at = now()
    where id = v_payment_id;
  end if;

  return query select v_payment_id, v_sm.fee_cents, v_concept,
                      v_club.stripe_account_id, v_club.name, v_email;
end;
$$;

-- Service role: remembers the Checkout Session of a payment.
create function public.attach_checkout_session(p_payment_id uuid, p_session_id text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.payments set provider_reference = p_session_id, updated_at = now()
  where id = p_payment_id and provider = 'stripe' and status = 'pending';
$$;

-- Service role: applies a verified provider event once.
-- Statuses: paid, failed (declined) or cancelled (Checkout expired).
-- Returns 'applied', 'duplicate' or 'ignored'.
create function public.apply_payment_event(
  p_event_id text,
  p_type text,
  p_payment_id uuid,
  p_status text,
  p_method text default null,
  p_reference text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.payments;
begin
  insert into public.payment_provider_events (id, provider, type, payment_id)
  values (p_event_id, 'stripe', p_type, p_payment_id)
  on conflict (id) do nothing;
  if not found then
    return 'duplicate';
  end if;

  select * into v_payment from public.payments where id = p_payment_id for update;
  if not found or v_payment.provider <> 'stripe' then
    return 'ignored';
  end if;
  if p_status not in ('paid', 'failed', 'cancelled') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  -- Final states are never undone by late or out-of-order events. A failed
  -- attempt can still succeed in the same Checkout (the card is retried).
  if v_payment.status in ('paid', 'cancelled')
     or (v_payment.status = 'failed' and p_status <> 'paid') then
    return 'ignored';
  end if;
  if v_payment.status = 'failed' then
    update public.payments set status = 'pending', updated_at = now() where id = p_payment_id;
  end if;

  update public.payments
  set status = p_status,
      method = coalesce(p_method, method),
      provider_reference = coalesce(p_reference, provider_reference),
      paid_at = case when p_status = 'paid' then now() else paid_at end,
      updated_at = now()
  where id = p_payment_id;
  return 'applied';
end;
$$;

-- «Mi suscripción» says whether the club accepts online payments.
drop function public.get_my_subscription(uuid);
create function public.get_my_subscription(p_club_id uuid)
returns table (
  season_name text,
  season_membership_id uuid,
  fee_cents integer,
  status text,
  payment_provider text,
  payment_method text,
  next_charge_cents integer,
  next_charge_on date,
  online_payments boolean
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
         null::integer, null::date,
         (c.stripe_account_id is not null and c.stripe_charges_enabled)
  from public.clubs c
  left join public.seasons s on s.club_id = c.id and s.status = 'active'
  left join public.season_memberships sm
    on sm.season_id = s.id and sm.club_membership_id = v_membership.id
  left join lateral (
    select p.provider, p.method
    from public.payments p
    join public.season_memberships any_sm on any_sm.id = p.season_membership_id
    where any_sm.club_membership_id = v_membership.id and p.status = 'paid'
    order by p.paid_at desc nulls last
    limit 1
  ) last_paid on true
  where c.id = p_club_id;
end;
$$;

revoke execute on function public.get_club_online_payments(uuid) from public, anon;
revoke execute on function public.set_club_stripe_account(uuid, text, boolean) from public, anon, authenticated;
revoke execute on function public.prepare_online_payment(uuid) from public, anon;
revoke execute on function public.attach_checkout_session(uuid, text) from public, anon, authenticated;
revoke execute on function public.apply_payment_event(text, text, uuid, text, text, text) from public, anon, authenticated;
revoke execute on function public.get_my_subscription(uuid) from public, anon;
grant execute on function public.get_club_online_payments(uuid) to authenticated;
grant execute on function public.prepare_online_payment(uuid) to authenticated;
grant execute on function public.get_my_subscription(uuid) to authenticated;
grant execute on function public.set_club_stripe_account(uuid, text, boolean) to service_role;
grant execute on function public.attach_checkout_session(uuid, text) to service_role;
grant execute on function public.apply_payment_event(text, text, uuid, text, text, text) to service_role;
