-- VS-023: notice before any automatic renewal charge (RF-013, RN-012).

alter table public.seasons
  add column renewal_charge_on date,
  add column renewal_notice_days integer not null default 15
    check (renewal_notice_days between 1 and 60);

comment on column public.seasons.renewal_charge_on is
  'Automatic renewal charge date; null = the season start date.';

create table public.renewal_notices (
  season_membership_id uuid primary key references public.season_memberships (id) on delete cascade,
  charge_on date not null,
  amount_cents integer not null check (amount_cents > 0),
  sent_to text not null,
  sent_at timestamptz not null default now()
);
alter table public.renewal_notices enable row level security;
create policy "members read their own renewal notices"
  on public.renewal_notices for select to authenticated
  using (public.can_see_season_membership(season_membership_id));

-- Today in Spain: notices and charges follow the club calendar.
create function public.madrid_today()
returns date
language sql
stable
set search_path = ''
as $$ select (now() at time zone 'Europe/Madrid')::date $$;

-- Renewals that will be charged automatically: pending fee, member with
-- automatic renewal and an active saved method, club taking online payments.
create view public.automatic_renewals
with (security_invoker = true) as
select sm.id as season_membership_id, cm.id as club_membership_id, cm.user_id,
       c.id as club_id, s.id as season_id, s.name as season_name,
       sm.fee_cents as amount_cents,
       coalesce(s.renewal_charge_on, s.starts_on) as charge_on,
       coalesce(s.renewal_charge_on, s.starts_on) - s.renewal_notice_days as notice_on,
       pm.kind as method_kind, pm.brand as method_brand, pm.last4 as method_last4
from public.season_memberships sm
join public.seasons s on s.id = sm.season_id and s.status <> 'closed'
join public.club_memberships cm on cm.id = sm.club_membership_id
  and cm.status = 'active' and cm.auto_renew
join public.clubs c on c.id = cm.club_id
  and c.is_active and c.stripe_account_id is not null and c.stripe_charges_enabled
join public.payment_methods pm on pm.club_membership_id = cm.id and pm.removed_at is null
where sm.status = 'pending_payment'
  and coalesce(sm.fee_cents, 0) > 0
  and not exists (
    select 1 from public.payments p
    where p.season_membership_id = sm.id and p.status = 'paid'
  );
revoke all on public.automatic_renewals from public, anon, authenticated;
grant select on public.automatic_renewals to service_role;

-- Service role (cron): notices due on [p_today] not sent yet.
create function public.get_due_renewal_notices(p_today date default null)
returns table (
  season_membership_id uuid,
  email text,
  first_name text,
  club_name text,
  club_primary_color text,
  club_logo_path text,
  season_name text,
  amount_cents integer,
  charge_on date,
  method_kind text,
  method_brand text,
  method_last4 text
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.season_membership_id, p.email, p.first_name, c.name, c.primary_color, c.logo_path,
         r.season_name, r.amount_cents, r.charge_on,
         r.method_kind, r.method_brand, r.method_last4
  from public.automatic_renewals r
  join public.profiles p on p.id = r.user_id
  join public.clubs c on c.id = r.club_id
  where coalesce(p_today, public.madrid_today()) >= r.notice_on
    and coalesce(p_today, public.madrid_today()) < r.charge_on
    and not exists (
      select 1 from public.renewal_notices n where n.season_membership_id = r.season_membership_id
    )
  order by r.charge_on, p.email;
$$;

-- Service role: claims the notice before sending it (true = send it).
create function public.claim_renewal_notice(
  p_season_membership_id uuid,
  p_charge_on date,
  p_amount_cents integer,
  p_email text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.renewal_notices (season_membership_id, charge_on, amount_cents, sent_to)
  values (p_season_membership_id, p_charge_on, p_amount_cents, p_email)
  on conflict (season_membership_id) do nothing;
  return found;
end;
$$;

-- Service role: the email could not be sent; it will be retried.
create function public.release_renewal_notice(p_season_membership_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.renewal_notices where season_membership_id = p_season_membership_id;
$$;

-- RN-012: an automatic charge needs a notice sent for that charge date and
-- amount, and the charge date reached. Used by the charge (VS-024).
create function public.can_charge_renewal(p_season_membership_id uuid, p_today date default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.automatic_renewals r
    join public.renewal_notices n on n.season_membership_id = r.season_membership_id
    where r.season_membership_id = p_season_membership_id
      and n.charge_on = r.charge_on
      and n.amount_cents = r.amount_cents
      and coalesce(p_today, public.madrid_today()) >= r.charge_on
  );
$$;

-- Admin: charge date and notice days of a season.
create function public.set_season_renewal(
  p_season_id uuid,
  p_charge_on date,
  p_notice_days integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_season public.seasons;
begin
  select * into v_season from public.seasons where id = p_season_id;
  if not found then
    raise exception 'season not found' using errcode = 'P0002';
  end if;
  if not public.can_admin_club(v_season.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if v_season.status = 'closed' then
    raise exception 'season closed' using errcode = 'P0001', hint = 'season_closed';
  end if;
  if p_notice_days is null or p_notice_days not between 1 and 60 then
    raise exception 'invalid notice days' using errcode = '22023';
  end if;
  if p_charge_on is not null and p_charge_on > v_season.ends_on then
    raise exception 'invalid charge date' using errcode = '22023';
  end if;
  update public.seasons
  set renewal_charge_on = p_charge_on, renewal_notice_days = p_notice_days
  where id = p_season_id;
  perform public.audit(v_season.club_id, 'season_renewal_updated',
    jsonb_build_object('season', v_season.name, 'charge_on', p_charge_on, 'notice_days', p_notice_days));
end;
$$;

-- «Mi suscripción»: next automatic charge (any upcoming season of the club).
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
  next_charge_season text
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
         next.season_name
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
    select r.amount_cents, r.charge_on, r.season_name
    from public.automatic_renewals r
    where r.club_membership_id = v_membership.id
      and r.charge_on >= public.madrid_today()
    order by r.charge_on
    limit 1
  ) next on true
  where c.id = p_club_id;
end;
$$;

revoke execute on function public.get_due_renewal_notices(date) from public, anon, authenticated;
revoke execute on function public.claim_renewal_notice(uuid, date, integer, text) from public, anon, authenticated;
revoke execute on function public.release_renewal_notice(uuid) from public, anon, authenticated;
revoke execute on function public.can_charge_renewal(uuid, date) from public, anon, authenticated;
revoke execute on function public.set_season_renewal(uuid, date, integer) from public, anon;
revoke execute on function public.get_my_subscription(uuid) from public, anon;
grant execute on function public.get_due_renewal_notices(date) to service_role;
grant execute on function public.claim_renewal_notice(uuid, date, integer, text) to service_role;
grant execute on function public.release_renewal_notice(uuid) to service_role;
grant execute on function public.can_charge_renewal(uuid, date) to service_role;
grant execute on function public.set_season_renewal(uuid, date, integer) to authenticated;
grant execute on function public.get_my_subscription(uuid) to authenticated;

-- Daily job (09:05 Madrid ≈ 07:05/08:05 UTC → 07:05 UTC) calling the Edge
-- Function. URL and service key live in Vault: `project_url` and
-- `service_role_key` (see DEPLOYMENT.md). Without them the job does nothing.
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

create function public.invoke_renewal_notices()
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
    raise notice 'renewal notices: project_url / service_role_key not in Vault';
    return;
  end if;
  perform net.http_post(
    url := v_url || '/functions/v1/send-renewal-notices',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := '{}'::jsonb
  );
end;
$$;
revoke execute on function public.invoke_renewal_notices() from public, anon, authenticated;

select cron.schedule('send-renewal-notices', '5 7 * * *', $$select public.invoke_renewal_notices()$$);
