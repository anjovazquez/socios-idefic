-- VS-031: dashboard of the club for its admin (§16 Dashboard).
create function public.get_club_dashboard(p_club_id uuid)
returns table (
  season_name text,
  active_members integer,
  pending_members integer,
  not_renewed_members integer,
  invited_members integer,
  auto_renew_members integer,
  paid_cents bigint,
  pending_cents bigint,
  valid_perks integer,
  season_sponsors integer,
  latest_posts jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_season public.seasons;
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  select * into v_season from public.seasons where club_id = p_club_id and status = 'active';

  return query
  with members as (
    select cm.id, cm.status, cm.auto_renew, sm.id as sm_id, sm.status as sm_status, sm.fee_cents
    from public.club_memberships cm
    left join public.season_memberships sm
      on sm.club_membership_id = cm.id and sm.season_id = v_season.id
    where cm.club_id = p_club_id
  )
  select
    v_season.name,
    (select count(*)::int from members where status = 'active' and sm_status = 'active'),
    (select count(*)::int from members where status = 'active' and sm_status = 'pending_payment'),
    (select count(*)::int from members
      where status = 'active' and v_season.id is not null
        and (sm_id is null or sm_status in ('not_renewed', 'cancelled'))),
    (select count(*)::int from members where status = 'invited'),
    (select count(*)::int from members where status = 'active' and auto_renew),
    (select coalesce(sum(p.amount_cents), 0)::bigint
       from public.payments p join members m on m.sm_id = p.season_membership_id
       where p.status = 'paid'),
    (select coalesce(sum(m.fee_cents), 0)::bigint
       from members m
       where m.status = 'active' and m.sm_status = 'pending_payment' and coalesce(m.fee_cents, 0) > 0),
    (select count(*)::int from public.perks pk
       where pk.club_id = p_club_id and pk.status = 'published'
         and (pk.valid_from is null or pk.valid_from <= public.madrid_today())
         and (pk.valid_until is null or pk.valid_until >= public.madrid_today())),
    (select count(*)::int from public.sponsors sp
       join public.sponsor_seasons ss on ss.sponsor_id = sp.id and ss.season_id = v_season.id
       where sp.club_id = p_club_id and sp.is_active),
    coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'published_at', x.published_at)
                       order by x.published_at desc)
      from (
        select po.id, po.title, po.published_at from public.posts po
        where po.club_id = p_club_id and po.status = 'published' and po.published_at <= now()
        order by po.published_at desc limit 3
      ) x
    ), '[]'::jsonb);
end;
$$;

revoke execute on function public.get_club_dashboard(uuid) from public, anon;
grant execute on function public.get_club_dashboard(uuid) to authenticated;
