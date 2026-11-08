-- VS-013: membership per season with its fee (RF-010, RN-007, RN-008, RN-010).

create table public.season_memberships (
  id uuid primary key default gen_random_uuid(),
  club_membership_id uuid not null references public.club_memberships (id) on delete cascade,
  season_id uuid not null references public.seasons (id) on delete cascade,
  fee_cents integer not null check (fee_cents >= 0),
  status text not null default 'pending_payment'
    check (status in ('pending_payment', 'active', 'not_renewed', 'cancelled')),
  -- Opaque token of the digital card QR (VS-016): 128 random bits.
  card_token text not null unique
    default translate(encode(extensions.gen_random_bytes(16), 'base64'), '+/=', '-_'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (club_membership_id, season_id)
);

create index season_memberships_season_idx on public.season_memberships (season_id);

-- Both sides must belong to the same club.
create function public.check_season_membership_club()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select club_id from public.club_memberships where id = new.club_membership_id)
     is distinct from (select club_id from public.seasons where id = new.season_id) then
    raise exception 'season and membership belong to different clubs' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger season_memberships_same_club
  before insert or update of club_membership_id, season_id on public.season_memberships
  for each row execute function public.check_season_membership_club();

alter table public.season_memberships enable row level security;
revoke all on public.season_memberships from anon;
revoke insert, update, delete, truncate on public.season_memberships from authenticated;

-- club_memberships has its own RLS (own rows only), so the check runs as
-- definer: the owner of the membership or an admin of its club.
create function public.can_see_club_membership(p_club_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.club_memberships m
    where m.id = p_club_membership_id
      and (m.user_id = (select auth.uid()) or public.can_admin_club(m.club_id))
  );
$$;

revoke execute on function public.can_see_club_membership(uuid) from public, anon;
grant execute on function public.can_see_club_membership(uuid) to authenticated;

create policy season_memberships_select on public.season_memberships
  for select to authenticated
  using (public.can_see_club_membership(club_membership_id));

-- New members join the active season with the ordinary fee (RF-008).
create function public.join_active_season()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_season public.seasons;
begin
  select * into v_season from public.seasons
  where club_id = new.club_id and status = 'active';
  if found then
    insert into public.season_memberships (club_membership_id, season_id, fee_cents, status)
    values (
      new.id, v_season.id, v_season.default_fee_cents,
      case when v_season.default_fee_cents = 0 then 'active' else 'pending_payment' end
    )
    on conflict (club_membership_id, season_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger club_memberships_join_active_season
  after insert on public.club_memberships
  for each row execute function public.join_active_season();

-- Custom fee for one member and season (discounts, honorary members...).
-- A 0 € fee makes the member active without paying.
create function public.set_member_fee(p_season_membership_id uuid, p_fee_cents integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.season_memberships;
  v_club_id uuid;
begin
  select sm.* into v_row from public.season_memberships sm where sm.id = p_season_membership_id;
  select m.club_id into v_club_id from public.club_memberships m where m.id = v_row.club_membership_id;
  if v_row.id is null or not public.can_admin_club(v_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if p_fee_cents is null or p_fee_cents < 0 then
    raise exception 'invalid fee' using errcode = '22023';
  end if;

  update public.season_memberships
  set fee_cents = p_fee_cents,
      status = case
        when p_fee_cents = 0 and status = 'pending_payment' then 'active'
        else status
      end,
      updated_at = now()
  where id = p_season_membership_id;

  perform public.audit(v_club_id, 'member_fee_changed',
    jsonb_build_object('season_membership_id', p_season_membership_id,
                       'from', v_row.fee_cents, 'to', p_fee_cents));
end;
$$;

-- Provisional until payments exist (VS-017): the admin records that the fee
-- was paid (active) or undoes it (pending_payment).
create function public.set_season_membership_status(p_season_membership_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.season_memberships;
  v_club_id uuid;
begin
  select sm.* into v_row from public.season_memberships sm where sm.id = p_season_membership_id;
  select m.club_id into v_club_id from public.club_memberships m where m.id = v_row.club_membership_id;
  if v_row.id is null or not public.can_admin_club(v_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if p_status not in ('pending_payment', 'active') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  update public.season_memberships
  set status = p_status, updated_at = now()
  where id = p_season_membership_id;

  perform public.audit(v_club_id, 'member_season_status_changed',
    jsonb_build_object('season_membership_id', p_season_membership_id,
                       'from', v_row.status, 'to', p_status));
end;
$$;

-- History per season since the first season of the member: seasons of the
-- club without a row are "not renewed" (§7).
create function public.get_member_seasons(p_membership_id uuid)
returns table (
  season_membership_id uuid,
  season_id uuid,
  season_name text,
  season_status text,
  fee_cents integer,
  status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_membership public.club_memberships;
  v_first text;
begin
  select * into v_membership from public.club_memberships where id = p_membership_id;
  if not found or not (
    public.can_admin_club(v_membership.club_id) or v_membership.user_id = (select auth.uid())
  ) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  select min(s.name) into v_first
  from public.season_memberships sm join public.seasons s on s.id = sm.season_id
  where sm.club_membership_id = p_membership_id;

  return query
  select sm.id, s.id, s.name, s.status, sm.fee_cents, coalesce(sm.status, 'not_renewed')
  from public.seasons s
  left join public.season_memberships sm
    on sm.season_id = s.id and sm.club_membership_id = p_membership_id
  where s.club_id = v_membership.club_id
    and s.status <> 'draft'
    and v_first is not null
    and s.name >= v_first
  order by s.name desc;
end;
$$;

revoke execute on function public.set_member_fee(uuid, integer) from public, anon;
revoke execute on function public.set_season_membership_status(uuid, text) from public, anon;
revoke execute on function public.get_member_seasons(uuid) from public, anon;
grant execute on function public.set_member_fee(uuid, integer) to authenticated;
grant execute on function public.set_season_membership_status(uuid, text) to authenticated;
grant execute on function public.get_member_seasons(uuid) to authenticated;
revoke execute on function public.join_active_season() from public, anon, authenticated;

-- Members list with the current season of each member.
drop function public.get_club_members(uuid, text, text, integer, integer);

create function public.get_club_members(
  p_club_id uuid,
  p_query text default null,
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  membership_id uuid,
  user_id uuid,
  email text,
  first_name text,
  last_name text,
  phone text,
  birth_date date,
  photo_path text,
  member_number integer,
  role text,
  status text,
  invited_at timestamptz,
  season_membership_id uuid,
  season_fee_cents integer,
  season_status text,
  total_count bigint
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
  if p_status is not null and p_status not in ('invited', 'active', 'inactive') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  return query
  with members as (
    select m.id as membership_id, m.user_id, p.email,
           coalesce(p.first_name, i.first_name) as first_name, p.last_name,
           p.phone, p.birth_date, p.photo_path,
           m.member_number, m.role, m.status, i.last_sent_at as invited_at,
           sm.id as season_membership_id, sm.fee_cents as season_fee_cents,
           sm.status as season_status
    from public.club_memberships m
    join public.profiles p on p.id = m.user_id
    left join lateral (
      select ci.first_name, ci.last_sent_at
      from public.club_invitations ci
      where ci.club_id = m.club_id and ci.email = p.email
      order by ci.created_at desc
      limit 1
    ) i on true
    left join public.seasons s on s.club_id = m.club_id and s.status = 'active'
    left join public.season_memberships sm
      on sm.club_membership_id = m.id and sm.season_id = s.id
    where m.club_id = p_club_id
      and (p_status is null or m.status = p_status)
  )
  select members.*, count(*) over ()
  from members
  where v_query is null
     or lower(coalesce(members.first_name, '') || ' ' || coalesce(members.last_name, '')) like '%' || v_query || '%'
     or members.email like '%' || v_query || '%'
     or members.member_number::text = v_query
  order by members.member_number nulls last, members.email
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke execute on function public.get_club_members(uuid, text, text, integer, integer) from public, anon;
grant execute on function public.get_club_members(uuid, text, text, integer, integer) to authenticated;
