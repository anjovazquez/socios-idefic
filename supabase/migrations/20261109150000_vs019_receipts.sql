-- VS-019: downloadable receipts (RF-017, D-015).
-- A payment gets a correlative receipt number per club and an immutable
-- snapshot of the club and member data when it becomes `paid`.

alter table public.payments
  add column receipt_number integer,
  add column receipt_snapshot jsonb;

create table public.club_receipt_counters (
  club_id uuid primary key references public.clubs (id) on delete cascade,
  last_number integer not null default 0
);
alter table public.club_receipt_counters enable row level security;
-- No policies: only definer functions touch the counters.

create function public.receipt_snapshot_of(p_season_membership_id uuid)
returns table (club_id uuid, snapshot jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id,
         jsonb_build_object(
           'club_name', c.name,
           'club_code', c.code,
           'club_primary_color', c.primary_color,
           'club_logo_path', c.logo_path,
           'member_first_name', pr.first_name,
           'member_last_name', pr.last_name,
           'member_email', pr.email,
           'member_number', cm.member_number,
           'season_name', s.name
         )
  from public.season_memberships sm
  join public.club_memberships cm on cm.id = sm.club_membership_id
  join public.clubs c on c.id = cm.club_id
  join public.profiles pr on pr.id = cm.user_id
  join public.seasons s on s.id = sm.season_id
  where sm.id = p_season_membership_id;
$$;

create function public.assign_payment_receipt()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_club_id uuid;
  v_snapshot jsonb;
  v_number integer;
begin
  if tg_op = 'UPDATE' and old.receipt_number is not null then
    -- Receipts are stable: once issued they never change.
    new.receipt_number := old.receipt_number;
    new.receipt_snapshot := old.receipt_snapshot;
    return new;
  end if;
  if new.status <> 'paid' then
    new.receipt_number := null;
    new.receipt_snapshot := null;
    return new;
  end if;

  select r.club_id, r.snapshot into v_club_id, v_snapshot
  from public.receipt_snapshot_of(new.season_membership_id) r;

  insert into public.club_receipt_counters as counters (club_id, last_number)
  values (v_club_id, 1)
  on conflict (club_id) do update set last_number = counters.last_number + 1
  returning last_number into v_number;

  new.receipt_number := v_number;
  new.receipt_snapshot := v_snapshot;
  return new;
end;
$$;

create trigger payments_assign_receipt
  before insert or update on public.payments
  for each row execute function public.assign_payment_receipt();

-- Payments already paid get their receipt in payment order.
do $$
declare
  v_payment record;
begin
  for v_payment in
    select p.id from public.payments p
    where p.status = 'paid' and p.receipt_number is null
    order by p.paid_at, p.created_at
  loop
    update public.payments set updated_at = updated_at where id = v_payment.id;
  end loop;
end;
$$;

create function public.get_receipt(p_payment_id uuid)
returns table (
  payment_id uuid,
  receipt_number integer,
  club_name text,
  club_code text,
  club_primary_color text,
  club_logo_path text,
  member_first_name text,
  member_last_name text,
  member_email text,
  member_number integer,
  season_name text,
  concept text,
  amount_cents integer,
  currency text,
  method text,
  paid_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_payment public.payments;
  v_owner uuid;
  v_club_id uuid;
begin
  select * into v_payment from public.payments where id = p_payment_id;
  if not found then
    raise exception 'payment not found' using errcode = 'P0002';
  end if;

  select cm.user_id, cm.club_id into v_owner, v_club_id
  from public.season_memberships sm
  join public.club_memberships cm on cm.id = sm.club_membership_id
  where sm.id = v_payment.season_membership_id;

  if v_owner is distinct from (select auth.uid())
     and not public.can_admin_club(v_club_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_payment.status <> 'paid' or v_payment.receipt_number is null then
    raise exception 'no receipt for this payment'
      using errcode = 'P0001', hint = 'no_receipt';
  end if;

  return query
  select v_payment.id, v_payment.receipt_number,
         v_payment.receipt_snapshot ->> 'club_name',
         v_payment.receipt_snapshot ->> 'club_code',
         v_payment.receipt_snapshot ->> 'club_primary_color',
         v_payment.receipt_snapshot ->> 'club_logo_path',
         v_payment.receipt_snapshot ->> 'member_first_name',
         v_payment.receipt_snapshot ->> 'member_last_name',
         v_payment.receipt_snapshot ->> 'member_email',
         (v_payment.receipt_snapshot ->> 'member_number')::integer,
         v_payment.receipt_snapshot ->> 'season_name',
         v_payment.concept, v_payment.amount_cents, v_payment.currency,
         v_payment.method, v_payment.paid_at;
end;
$$;

-- get_my_payments exposes whether a receipt exists.
drop function public.get_my_payments(uuid);
create function public.get_my_payments(p_club_id uuid)
returns table (
  payment_id uuid,
  season_name text,
  concept text,
  amount_cents integer,
  payment_date timestamptz,
  status text,
  provider text,
  method text,
  receipt_number integer
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
         p.status, p.provider, p.method,
         case when p.status = 'paid' then p.receipt_number end
  from public.payments p
  join public.season_memberships sm on sm.id = p.season_membership_id
  join public.seasons s on s.id = sm.season_id
  where sm.club_membership_id = v_membership_id
  order by coalesce(p.paid_at, p.created_at) desc;
end;
$$;

revoke execute on function public.receipt_snapshot_of(uuid) from public, anon, authenticated;
revoke execute on function public.assign_payment_receipt() from public, anon, authenticated;
revoke execute on function public.get_receipt(uuid) from public, anon;
revoke execute on function public.get_my_payments(uuid) from public, anon;
grant execute on function public.get_receipt(uuid) to authenticated;
grant execute on function public.get_my_payments(uuid) to authenticated;
