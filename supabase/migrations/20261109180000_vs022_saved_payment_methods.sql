-- VS-022: saved payment method for automatic renewals (RF-012, ADR-001).
-- Only provider ids and masked data are stored, never card numbers or IBANs.

alter table public.club_memberships
  add column auto_renew boolean not null default false,
  add column stripe_customer_id text;

create table public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  club_membership_id uuid not null references public.club_memberships (id) on delete cascade,
  provider text not null default 'stripe' check (provider in ('stripe')),
  provider_customer_id text not null,
  provider_method_id text not null,
  kind text not null check (kind in ('card', 'sepa_debit')),
  brand text,
  last4 text check (last4 ~ '^[0-9]{4}$'),
  country text,
  mandate_id text,
  created_at timestamptz not null default now(),
  removed_at timestamptz
);
-- One active method per member and club (the one used to renew).
create unique index payment_methods_one_active_idx
  on public.payment_methods (club_membership_id) where removed_at is null;

alter table public.payment_methods enable row level security;
create policy "members read their own payment methods"
  on public.payment_methods for select to authenticated
  using (exists (
    select 1 from public.club_memberships cm
    where cm.id = club_membership_id and cm.user_id = (select auth.uid())
  ));

create function public.my_active_membership(p_club_id uuid)
returns public.club_memberships
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_membership public.club_memberships;
begin
  select * into v_membership from public.club_memberships
  where club_id = p_club_id and user_id = (select auth.uid()) and status = 'active';
  if not found then
    raise exception 'not a member' using errcode = '42501';
  end if;
  return v_membership;
end;
$$;

-- Member: saved method and whether renewals are automatic.
create function public.get_my_payment_method(p_club_id uuid)
returns table (kind text, brand text, last4 text, country text, auto_renew boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_membership public.club_memberships := public.my_active_membership(p_club_id);
begin
  return query
  select pm.kind, pm.brand, pm.last4, pm.country, v_membership.auto_renew
  from (select 1) one
  left join public.payment_methods pm
    on pm.club_membership_id = v_membership.id and pm.removed_at is null;
end;
$$;

-- Member: data to open a Checkout in setup mode (save a method, no payment).
create function public.prepare_payment_method_setup(p_club_id uuid)
returns table (club_membership_id uuid, stripe_account_id text, stripe_customer_id text, member_email text, club_name text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_membership public.club_memberships := public.my_active_membership(p_club_id);
  v_club public.clubs;
begin
  select * into v_club from public.clubs where id = p_club_id;
  if v_club.stripe_account_id is null or not v_club.stripe_charges_enabled then
    raise exception 'online payments not enabled' using errcode = 'P0001', hint = 'online_payments_disabled';
  end if;
  return query
  select v_membership.id, v_club.stripe_account_id, v_membership.stripe_customer_id,
         (select email from public.profiles where id = v_membership.user_id), v_club.name;
end;
$$;

-- Member: removes the saved method; renewals stop being automatic.
-- Returns the provider ids so the server detaches it in Stripe.
create function public.remove_my_payment_method(p_club_id uuid)
returns table (stripe_account_id text, provider_method_id text)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_membership public.club_memberships := public.my_active_membership(p_club_id);
begin
  update public.club_memberships set auto_renew = false where id = v_membership.id;
  perform public.audit(p_club_id, 'payment_method_removed', '{}'::jsonb);
  return query
  update public.payment_methods pm set removed_at = now()
  from public.clubs c
  where pm.club_membership_id = v_membership.id and pm.removed_at is null and c.id = p_club_id
  returning c.stripe_account_id, pm.provider_method_id;
end;
$$;

-- Service role (webhook): saves the method of a completed Checkout once.
create function public.save_payment_method(
  p_event_id text,
  p_club_membership_id uuid,
  p_customer_id text,
  p_method_id text,
  p_kind text,
  p_brand text default null,
  p_last4 text default null,
  p_country text default null,
  p_mandate_id text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.payment_provider_events (id, provider, type)
  values (p_event_id || ':payment_method', 'stripe', 'payment_method_saved')
  on conflict (id) do nothing;
  if not found then
    return 'duplicate';
  end if;
  if not exists (select 1 from public.club_memberships where id = p_club_membership_id) then
    return 'ignored';
  end if;

  update public.payment_methods set removed_at = now()
  where club_membership_id = p_club_membership_id and removed_at is null;
  insert into public.payment_methods
    (club_membership_id, provider_customer_id, provider_method_id, kind, brand, last4, country, mandate_id)
  values
    (p_club_membership_id, p_customer_id, p_method_id, p_kind, p_brand, p_last4, p_country, p_mandate_id);
  update public.club_memberships
  set auto_renew = true, stripe_customer_id = p_customer_id
  where id = p_club_membership_id;
  return 'applied';
end;
$$;

-- The online payment now also returns who pays (to save the method).
drop function public.prepare_online_payment(uuid);
create function public.prepare_online_payment(p_season_membership_id uuid)
returns table (
  payment_id uuid,
  amount_cents integer,
  concept text,
  stripe_account_id text,
  club_name text,
  member_email text,
  club_membership_id uuid,
  stripe_customer_id text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_sm public.season_memberships;
  v_membership public.club_memberships;
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
  select * into v_membership from public.club_memberships
  where id = v_sm.club_membership_id and status = 'active';
  if v_membership.user_id is distinct from (select auth.uid()) then
    raise exception 'not your fee' using errcode = '42501';
  end if;
  select name into v_season_name from public.seasons where id = v_sm.season_id;
  select * into v_club from public.clubs where id = v_membership.club_id;
  if v_club.stripe_account_id is null or not v_club.stripe_charges_enabled then
    raise exception 'online payments not enabled' using errcode = 'P0001', hint = 'online_payments_disabled';
  end if;
  if v_sm.status <> 'pending_payment' or coalesce(v_sm.fee_cents, 0) <= 0 then
    raise exception 'nothing to pay' using errcode = 'P0001', hint = 'not_payable';
  end if;
  if exists (select 1 from public.payments where season_membership_id = v_sm.id and status = 'paid') then
    raise exception 'already paid' using errcode = 'P0001', hint = 'already_paid';
  end if;

  select email into v_email from public.profiles where id = v_membership.user_id;
  v_concept := 'Cuota de socio ' || v_season_name;

  select id into v_payment_id from public.payments
  where season_membership_id = v_sm.id and provider = 'stripe' and status = 'pending'
  order by created_at desc limit 1;
  if v_payment_id is null then
    insert into public.payments (season_membership_id, amount_cents, concept, status, provider, created_by)
    values (v_sm.id, v_sm.fee_cents, v_concept, 'pending', 'stripe', v_membership.user_id)
    returning id into v_payment_id;
  else
    update public.payments set amount_cents = v_sm.fee_cents, updated_at = now()
    where id = v_payment_id;
  end if;

  return query select v_payment_id, v_sm.fee_cents, v_concept, v_club.stripe_account_id,
                      v_club.name, v_email, v_membership.id, v_membership.stripe_customer_id;
end;
$$;

revoke execute on function public.my_active_membership(uuid) from public, anon, authenticated;
revoke execute on function public.get_my_payment_method(uuid) from public, anon;
revoke execute on function public.prepare_payment_method_setup(uuid) from public, anon;
revoke execute on function public.remove_my_payment_method(uuid) from public, anon;
revoke execute on function public.save_payment_method(text, uuid, text, text, text, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.prepare_online_payment(uuid) from public, anon;
grant execute on function public.get_my_payment_method(uuid) to authenticated;
grant execute on function public.prepare_payment_method_setup(uuid) to authenticated;
grant execute on function public.remove_my_payment_method(uuid) to authenticated;
grant execute on function public.prepare_online_payment(uuid) to authenticated;
grant execute on function public.save_payment_method(text, uuid, text, text, text, text, text, text, text) to service_role;
