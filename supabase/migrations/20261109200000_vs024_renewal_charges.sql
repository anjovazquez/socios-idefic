-- VS-024: cancel the renewal before the charge (RF-014, RN-013) or get
-- charged automatically on the charge date (RF-012) with the saved method.

-- One automatic charge attempt per renewal (idempotency of the daily job).
create table public.renewal_charges (
  season_membership_id uuid primary key references public.season_memberships (id) on delete cascade,
  payment_id uuid not null references public.payments (id) on delete cascade,
  created_at timestamptz not null default now(),
  failure_notified_at timestamptz
);
alter table public.renewal_charges enable row level security;
-- No policies: only the service role.

-- Member: cancels a renewal before its charge date.
create function public.cancel_renewal(p_season_membership_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sm public.season_memberships;
  v_owner uuid;
  v_club_id uuid;
  v_season public.seasons;
begin
  select * into v_sm from public.season_memberships where id = p_season_membership_id for update;
  if not found then
    raise exception 'renewal not found' using errcode = 'P0002';
  end if;
  select cm.user_id, cm.club_id into v_owner, v_club_id
  from public.club_memberships cm where cm.id = v_sm.club_membership_id;
  if v_owner is distinct from (select auth.uid()) then
    raise exception 'not your renewal' using errcode = '42501';
  end if;
  select * into v_season from public.seasons where id = v_sm.season_id;

  -- Too late: already paid, being charged, or the charge date arrived.
  if v_sm.status <> 'pending_payment'
     or exists (select 1 from public.renewal_charges where season_membership_id = v_sm.id)
     or exists (
       select 1 from public.payments
       where season_membership_id = v_sm.id and status in ('pending', 'paid')
     )
     or public.madrid_today() >= coalesce(v_season.renewal_charge_on, v_season.starts_on) then
    raise exception 'renewal can no longer be cancelled'
      using errcode = 'P0001', hint = 'renewal_too_late';
  end if;

  update public.season_memberships set status = 'cancelled', updated_at = now()
  where id = v_sm.id;
  perform public.audit(v_club_id, 'renewal_cancelled', jsonb_build_object('season', v_season.name));
end;
$$;

-- Service role (cron): renewals to charge on [p_today].
create function public.get_due_renewal_charges(p_today date default null)
returns table (season_membership_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select r.season_membership_id
  from public.automatic_renewals r
  where public.can_charge_renewal(r.season_membership_id, coalesce(p_today, public.madrid_today()))
    and not exists (
      select 1 from public.renewal_charges c where c.season_membership_id = r.season_membership_id
    );
$$;

-- Service role: claims the single charge attempt of a renewal and opens its
-- payment. Returns nothing when it cannot be charged or was already tried.
create function public.claim_renewal_charge(p_season_membership_id uuid, p_today date default null)
returns table (
  payment_id uuid,
  amount_cents integer,
  stripe_account_id text,
  customer_id text,
  method_id text,
  method_kind text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_renewal public.automatic_renewals;
  v_payment_id uuid;
begin
  if not public.can_charge_renewal(p_season_membership_id, p_today) then
    return;
  end if;
  select * into v_renewal from public.automatic_renewals
  where season_membership_id = p_season_membership_id;

  insert into public.payments (season_membership_id, amount_cents, concept, status, provider)
  values (p_season_membership_id, v_renewal.amount_cents,
          'Cuota de socio ' || v_renewal.season_name, 'pending', 'stripe')
  returning id into v_payment_id;
  insert into public.renewal_charges (season_membership_id, payment_id)
  values (p_season_membership_id, v_payment_id)
  on conflict (season_membership_id) do nothing;
  if not found then
    delete from public.payments where id = v_payment_id;
    return;
  end if;

  return query
  select v_payment_id, v_renewal.amount_cents, c.stripe_account_id,
         pm.provider_customer_id, pm.provider_method_id, pm.kind
  from public.clubs c
  join public.payment_methods pm
    on pm.club_membership_id = v_renewal.club_membership_id and pm.removed_at is null
  where c.id = v_renewal.club_id;
end;
$$;

-- Service role: failed automatic charges whose member was not told yet.
create function public.get_failed_renewal_charges()
returns table (
  season_membership_id uuid,
  email text,
  first_name text,
  club_name text,
  club_primary_color text,
  club_logo_path text,
  season_name text,
  amount_cents integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select rc.season_membership_id, pr.email, pr.first_name, c.name, c.primary_color, c.logo_path,
         s.name, p.amount_cents
  from public.renewal_charges rc
  join public.payments p on p.id = rc.payment_id and p.status = 'failed'
  join public.season_memberships sm on sm.id = rc.season_membership_id
  join public.seasons s on s.id = sm.season_id
  join public.club_memberships cm on cm.id = sm.club_membership_id
  join public.profiles pr on pr.id = cm.user_id
  join public.clubs c on c.id = cm.club_id
  where rc.failure_notified_at is null;
$$;

create function public.mark_renewal_failure_notified(p_season_membership_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.renewal_charges set failure_notified_at = now()
  where season_membership_id = p_season_membership_id;
$$;

-- «Mi suscripción»: which renewal the next charge is (to cancel it).
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
  online_payments boolean,
  next_charge_season text,
  next_charge_season_membership_id uuid,
  next_charge_cancellable boolean
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
         next.amount_cents, next.charge_on,
         (c.stripe_account_id is not null and c.stripe_charges_enabled),
         next.season_name, next.season_membership_id,
         (next.season_membership_id is not null
           and public.madrid_today() < next.charge_on
           and not exists (
             select 1 from public.renewal_charges rc where rc.season_membership_id = next.season_membership_id
           ))
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
  left join lateral (
    select r.amount_cents, r.charge_on, r.season_name, r.season_membership_id
    from public.automatic_renewals r
    where r.club_membership_id = v_membership.id
      and r.charge_on >= public.madrid_today()
    order by r.charge_on
    limit 1
  ) next on true
  where c.id = p_club_id;
end;
$$;

-- «Pagos» (admin) also lists renewals cancelled by the member.
create or replace function public.get_club_payments(
  p_club_id uuid,
  p_season_id uuid default null,
  p_query text default null,
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  payment_id uuid,
  season_membership_id uuid,
  season_id uuid,
  season_name text,
  member_first_name text,
  member_last_name text,
  member_email text,
  member_number integer,
  concept text,
  amount_cents integer,
  payment_date timestamptz,
  status text,
  provider text,
  method text,
  receipt_number integer,
  total_count bigint,
  paid_cents bigint,
  pending_cents bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_query text := nullif(lower(trim(coalesce(p_query, ''))), '');
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if p_status is not null and p_status not in ('pending', 'paid', 'failed', 'cancelled') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  if p_season_id is not null and not exists (
    select 1 from public.seasons where id = p_season_id and club_id = p_club_id
  ) then
    raise exception 'season not found' using errcode = 'P0002';
  end if;

  return query
  with members as (
    select sm.id as season_membership_id, s.id as season_id, s.name as season_name,
           coalesce(pr.first_name, inv.first_name) as first_name, pr.last_name,
           pr.email, cm.member_number, sm.fee_cents, sm.status as sm_status
    from public.season_memberships sm
    join public.seasons s on s.id = sm.season_id
    join public.club_memberships cm on cm.id = sm.club_membership_id
    join public.profiles pr on pr.id = cm.user_id
    left join lateral (
      select ci.first_name from public.club_invitations ci
      where ci.club_id = cm.club_id and ci.email = pr.email
      order by ci.created_at desc limit 1
    ) inv on true
    where s.club_id = p_club_id
      and cm.club_id = p_club_id
      and (p_season_id is null or s.id = p_season_id)
      and (v_query is null
           or lower(coalesce(coalesce(pr.first_name, inv.first_name), '') || ' ' || coalesce(pr.last_name, '')) like '%' || v_query || '%'
           or pr.email like '%' || v_query || '%'
           or cm.member_number::text = v_query)
  ),
  lines as (
    select p.id as payment_id, m.season_membership_id, m.season_id, m.season_name,
           m.first_name, m.last_name, m.email, m.member_number,
           p.concept, p.amount_cents, coalesce(p.paid_at, p.created_at) as payment_date,
           p.status, p.provider, p.method,
           case when p.status = 'paid' then p.receipt_number end as receipt_number
    from members m
    join public.payments p on p.season_membership_id = m.season_membership_id
    union all
    select null, m.season_membership_id, m.season_id, m.season_name,
           m.first_name, m.last_name, m.email, m.member_number,
           'Cuota de socio ' || m.season_name, m.fee_cents, null,
           'pending', null, null, null
    from members m
    where m.sm_status = 'pending_payment'
      and coalesce(m.fee_cents, 0) > 0
      and not exists (
        select 1 from public.payments p
        where p.season_membership_id = m.season_membership_id
          and p.status in ('pending', 'paid')
      )
    union all
    -- Renewals cancelled by the member (VS-024), without any payment.
    select null, m.season_membership_id, m.season_id, m.season_name,
           m.first_name, m.last_name, m.email, m.member_number,
           'Renovación cancelada por el socio', coalesce(m.fee_cents, 0), null,
           'cancelled', null, null, null
    from members m
    where m.sm_status = 'cancelled'
      and not exists (
        select 1 from public.payments p where p.season_membership_id = m.season_membership_id
      )
  )
  select lines.*,
         count(*) over (),
         coalesce(sum(lines.amount_cents) filter (where lines.status = 'paid') over (), 0),
         coalesce(sum(lines.amount_cents) filter (where lines.status = 'pending') over (), 0)
  from lines
  where p_status is null or lines.status = p_status
  order by lines.payment_date desc nulls first, lines.member_number nulls last, lines.email
  limit greatest(least(coalesce(p_limit, 50), 200), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- Daily charge job (08:05 UTC, after the notices).
create function public.invoke_charge_renewals()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_key text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'service_role_key';
  if v_url is null or v_key is null then
    raise notice 'renewal charges: project_url / service_role_key not in Vault';
    return;
  end if;
  perform net.http_post(
    url := v_url || '/functions/v1/charge-renewals',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := '{}'::jsonb
  );
end;
$$;

select cron.schedule('charge-renewals', '5 8 * * *', $cron$select public.invoke_charge_renewals()$cron$);

revoke execute on function public.cancel_renewal(uuid) from public, anon;
revoke execute on function public.get_due_renewal_charges(date) from public, anon, authenticated;
revoke execute on function public.claim_renewal_charge(uuid, date) from public, anon, authenticated;
revoke execute on function public.get_failed_renewal_charges() from public, anon, authenticated;
revoke execute on function public.mark_renewal_failure_notified(uuid) from public, anon, authenticated;
revoke execute on function public.invoke_charge_renewals() from public, anon, authenticated;
revoke execute on function public.get_my_subscription(uuid) from public, anon;
grant execute on function public.cancel_renewal(uuid) to authenticated;
grant execute on function public.get_my_subscription(uuid) to authenticated;
grant execute on function public.get_due_renewal_charges(date) to service_role;
grant execute on function public.claim_renewal_charge(uuid, date) to service_role;
grant execute on function public.get_failed_renewal_charges() to service_role;
grant execute on function public.mark_renewal_failure_notified(uuid) to service_role;
