-- VS-020: payments of the club for the admin (RF-018, §16 Pagos).
-- Besides payment rows, fees still pending without any payment are listed as
-- «Pendiente» (payment_id null): with the manual provider that is how a fee
-- waits for its payment.

create function public.get_club_payments(
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

revoke execute on function public.get_club_payments(uuid, uuid, text, text, integer, integer) from public, anon;
grant execute on function public.get_club_payments(uuid, uuid, text, text, integer, integer) to authenticated;
