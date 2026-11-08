-- VS-017: payments decoupled from the provider; first provider: manual
-- (cash, transfer, Bizum) recorded by the club admin (§9, RF-015).

alter table public.clubs add column payment_instructions text;

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  season_membership_id uuid not null references public.season_memberships (id) on delete cascade,
  amount_cents integer not null check (amount_cents > 0),
  currency text not null default 'EUR' check (currency = 'EUR'),
  concept text not null,
  status text not null default 'pending' check (status in ('pending', 'paid', 'failed', 'cancelled')),
  provider text not null check (provider in ('manual', 'stripe')),
  method text check (method in ('cash', 'transfer', 'bizum', 'card', 'sepa', 'other')),
  provider_reference text,
  paid_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status <> 'paid' or paid_at is not null)
);

create index payments_season_membership_idx on public.payments (season_membership_id, created_at desc);

-- Valid transitions (RF-015). A manual payment recorded by mistake can be
-- cancelled; provider payments (Stripe) are corrected by refunds later.
create function public.check_payment_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = old.status then
    return new;
  end if;
  if not (
    (old.status = 'pending' and new.status in ('paid', 'failed', 'cancelled'))
    or (old.status = 'failed' and new.status in ('pending', 'cancelled'))
    or (old.status = 'paid' and new.status = 'cancelled' and old.provider = 'manual')
  ) then
    raise exception 'invalid payment transition % -> %', old.status, new.status
      using errcode = 'P0001', hint = 'invalid_transition';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger payments_transition
  before update of status on public.payments
  for each row execute function public.check_payment_transition();

-- The season membership follows its payments: paid → active member;
-- cancelling the only paid payment → pending again.
create function public.sync_season_membership_with_payments()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'paid' then
    update public.season_memberships
    set status = 'active', updated_at = now()
    where id = new.season_membership_id and status = 'pending_payment';
  elsif tg_op = 'UPDATE' and old.status = 'paid' and new.status = 'cancelled' then
    update public.season_memberships sm
    set status = 'pending_payment', updated_at = now()
    where sm.id = new.season_membership_id
      and sm.status = 'active'
      and sm.fee_cents > 0
      and not exists (
        select 1 from public.payments p
        where p.season_membership_id = sm.id and p.status = 'paid' and p.id <> new.id
      );
  end if;
  return new;
end;
$$;

create trigger payments_sync_season_membership
  after insert or update of status on public.payments
  for each row execute function public.sync_season_membership_with_payments();

revoke execute on function public.sync_season_membership_with_payments() from public, anon, authenticated;

-- Definer check: the owner of the season membership or an admin of its club.
create function public.can_see_season_membership(p_season_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.season_memberships sm
    where sm.id = p_season_membership_id
      and public.can_see_club_membership(sm.club_membership_id)
  );
$$;

revoke execute on function public.can_see_season_membership(uuid) from public, anon;
grant execute on function public.can_see_season_membership(uuid) to authenticated;

alter table public.payments enable row level security;
revoke all on public.payments from anon;
revoke insert, update, delete, truncate on public.payments from authenticated;

create policy payments_select on public.payments
  for select to authenticated
  using (public.can_see_season_membership(season_membership_id));

create function public.club_of_season_membership(p_season_membership_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.club_id
  from public.season_memberships sm
  join public.club_memberships m on m.id = sm.club_membership_id
  where sm.id = p_season_membership_id;
$$;

revoke execute on function public.club_of_season_membership(uuid) from public, anon, authenticated;

-- The admin records a fee paid outside the app (cash, transfer, Bizum).
create function public.record_manual_payment(
  p_season_membership_id uuid,
  p_method text,
  p_amount_cents integer default null,
  p_paid_on date default null,
  p_reference text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id uuid := public.club_of_season_membership(p_season_membership_id);
  v_row public.season_memberships;
  v_season_name text;
  v_amount integer;
  v_id uuid;
begin
  if v_club_id is null or not public.can_admin_club(v_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if p_method not in ('cash', 'transfer', 'bizum', 'other') then
    raise exception 'invalid method' using errcode = '22023';
  end if;

  select * into v_row from public.season_memberships where id = p_season_membership_id for update;
  if v_row.status in ('cancelled', 'not_renewed') then
    raise exception 'season membership not payable' using errcode = 'P0001', hint = 'not_payable';
  end if;
  if exists (
    select 1 from public.payments
    where season_membership_id = p_season_membership_id and status = 'paid'
  ) then
    raise exception 'already paid' using errcode = 'P0001', hint = 'already_paid';
  end if;

  v_amount := coalesce(p_amount_cents, v_row.fee_cents);
  if v_amount is null or v_amount <= 0 then
    raise exception 'invalid amount' using errcode = '22023';
  end if;
  if p_paid_on is not null and p_paid_on > current_date then
    raise exception 'invalid payment date' using errcode = '22023';
  end if;

  select name into v_season_name from public.seasons where id = v_row.season_id;

  insert into public.payments (
    season_membership_id, amount_cents, concept, status, provider, method,
    provider_reference, paid_at, created_by
  ) values (
    p_season_membership_id, v_amount, 'Cuota de socio ' || v_season_name, 'paid', 'manual',
    p_method, nullif(trim(coalesce(p_reference, '')), ''),
    coalesce(p_paid_on::timestamptz, now()), (select auth.uid())
  )
  returning id into v_id;

  perform public.audit(v_club_id, 'payment_recorded',
    jsonb_build_object('payment_id', v_id, 'amount_cents', v_amount, 'method', p_method));
  return v_id;
end;
$$;

create function public.set_payment_status(p_payment_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.payments;
  v_club_id uuid;
begin
  select * into v_payment from public.payments where id = p_payment_id;
  v_club_id := public.club_of_season_membership(v_payment.season_membership_id);
  if v_payment.id is null or not public.can_admin_club(v_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if p_status not in ('failed', 'cancelled') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  update public.payments set status = p_status where id = p_payment_id;

  perform public.audit(v_club_id, 'payment_status_changed',
    jsonb_build_object('payment_id', p_payment_id, 'from', v_payment.status, 'to', p_status));
end;
$$;

create function public.set_payment_instructions(p_club_id uuid, p_instructions text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  update public.clubs
  set payment_instructions = nullif(trim(coalesce(p_instructions, '')), ''), updated_at = now()
  where id = p_club_id;
  perform public.audit(p_club_id, 'payment_instructions_updated', '{}'::jsonb);
end;
$$;

-- Members and admins of the club read how to pay (manual provider).
create function public.get_payment_instructions(p_club_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select c.payment_instructions
  from public.clubs c
  where c.id = p_club_id
    and (
      public.can_admin_club(c.id)
      or exists (
        select 1 from public.club_memberships m
        where m.club_id = c.id and m.user_id = (select auth.uid()) and m.status = 'active'
      )
    );
$$;

revoke execute on function public.record_manual_payment(uuid, text, integer, date, text) from public, anon;
revoke execute on function public.set_payment_status(uuid, text) from public, anon;
revoke execute on function public.set_payment_instructions(uuid, text) from public, anon;
revoke execute on function public.get_payment_instructions(uuid) from public, anon;
grant execute on function public.record_manual_payment(uuid, text, integer, date, text) to authenticated;
grant execute on function public.set_payment_status(uuid, text) to authenticated;
grant execute on function public.set_payment_instructions(uuid, text) to authenticated;
grant execute on function public.get_payment_instructions(uuid) to authenticated;

-- Payments decide who paid: the provisional switch of VS-013 is retired.
drop function public.set_season_membership_status(uuid, text);

-- The card also returns its season membership, to start a payment from it.
drop function public.get_my_card(uuid);

create function public.get_my_card(p_club_id uuid)
returns table (
  club_name text,
  club_logo_path text,
  club_primary_color text,
  club_secondary_color text,
  first_name text,
  last_name text,
  photo_path text,
  member_number integer,
  season_name text,
  state text,
  card_token text,
  season_membership_id uuid,
  fee_cents integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_membership public.club_memberships;
  v_season public.seasons;
  v_season_membership public.season_memberships;
  v_state text;
begin
  select * into v_membership from public.club_memberships
  where club_id = p_club_id and user_id = (select auth.uid()) and status = 'active';
  if not found then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select * into v_season from public.seasons where club_id = p_club_id and status = 'active';
  if v_season.id is not null then
    select * into v_season_membership from public.season_memberships
    where club_membership_id = v_membership.id and season_id = v_season.id;
  end if;

  v_state := case
    when v_season.id is null then 'no_season'
    when v_season_membership.id is null then 'not_renewed'
    when v_season_membership.status = 'active' then 'active'
    when v_season_membership.status = 'pending_payment' then 'pending_payment'
    else 'not_renewed'
  end;

  return query
  select c.name, c.logo_path, c.primary_color, c.secondary_color,
         p.first_name, p.last_name, p.photo_path, v_membership.member_number,
         v_season.name, v_state,
         case when v_state = 'active' then v_season_membership.card_token end,
         v_season_membership.id, v_season_membership.fee_cents
  from public.clubs c
  join public.profiles p on p.id = v_membership.user_id
  where c.id = p_club_id;
end;
$$;

revoke execute on function public.get_my_card(uuid) from public, anon;
grant execute on function public.get_my_card(uuid) to authenticated;
