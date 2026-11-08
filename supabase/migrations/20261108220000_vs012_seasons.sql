-- VS-012: seasons with their ordinary fee (RF-007, RF-008, RN-008, RN-009).

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  name text not null check (
    name ~ '^[0-9]{4}/[0-9]{4}$'
    and split_part(name, '/', 2)::int = split_part(name, '/', 1)::int + 1
  ),
  starts_on date not null,
  ends_on date not null,
  default_fee_cents integer check (default_fee_cents >= 0),
  status text not null default 'draft' check (status in ('draft', 'active', 'closed')),
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  closed_at timestamptz,
  unique (club_id, name),
  check (ends_on > starts_on),
  check (status = 'draft' or default_fee_cents is not null)
);

-- Exactly one active season per club, even under concurrent activations.
create unique index seasons_one_active_idx on public.seasons (club_id) where status = 'active';

alter table public.seasons enable row level security;
revoke all on public.seasons from anon;
revoke insert, update, delete, truncate on public.seasons from authenticated;

create policy seasons_select_members on public.seasons
  for select to authenticated
  using (
    (select public.can_admin_club(club_id))
    or exists (
      select 1 from public.club_memberships m
      where m.club_id = seasons.club_id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
    )
  );

create function public.create_season(
  p_club_id uuid,
  p_name text,
  p_starts_on date default null,
  p_ends_on date default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := trim(coalesce(p_name, ''));
  v_first_year integer;
  v_starts date;
  v_ends date;
  v_id uuid;
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if v_name !~ '^[0-9]{4}/[0-9]{4}$'
     or split_part(v_name, '/', 2)::int <> split_part(v_name, '/', 1)::int + 1 then
    raise exception 'invalid season name' using errcode = '22023';
  end if;
  v_first_year := split_part(v_name, '/', 1)::int;
  v_starts := coalesce(p_starts_on, make_date(v_first_year, 9, 1));
  v_ends := coalesce(p_ends_on, make_date(v_first_year + 1, 8, 31));
  if v_ends <= v_starts then
    raise exception 'invalid season dates' using errcode = '22023';
  end if;

  insert into public.seasons (club_id, name, starts_on, ends_on)
  values (p_club_id, v_name, v_starts, v_ends)
  returning id into v_id;

  perform public.audit(p_club_id, 'season_created', jsonb_build_object('name', v_name));
  return v_id;
end;
$$;

-- Activating closes the previous active season in the same transaction.
-- Activating the active season again only updates its fee.
create function public.activate_season(p_season_id uuid, p_default_fee_cents integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_season public.seasons;
  v_previous text;
begin
  select * into v_season from public.seasons where id = p_season_id;
  if not found or not public.can_admin_club(v_season.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if p_default_fee_cents is null or p_default_fee_cents < 0 then
    raise exception 'season fee required' using errcode = '22023';
  end if;
  if v_season.status = 'closed' then
    raise exception 'closed seasons cannot be activated' using errcode = 'P0001',
      hint = 'season_closed';
  end if;

  -- Serialize activations of the same club.
  perform 1 from public.clubs where id = v_season.club_id for update;

  update public.seasons
  set status = 'closed', closed_at = now()
  where club_id = v_season.club_id and status = 'active' and id <> p_season_id
  returning name into v_previous;

  update public.seasons
  set status = 'active',
      default_fee_cents = p_default_fee_cents,
      activated_at = coalesce(activated_at, now())
  where id = p_season_id;

  perform public.audit(v_season.club_id, 'season_activated',
    jsonb_build_object('name', v_season.name, 'fee_cents', p_default_fee_cents, 'previous', v_previous));
end;
$$;

revoke execute on function public.create_season(uuid, text, date, date) from public, anon;
revoke execute on function public.activate_season(uuid, integer) from public, anon;
grant execute on function public.create_season(uuid, text, date, date) to authenticated;
grant execute on function public.activate_season(uuid, integer) to authenticated;

-- Selector/home data with the active season.
drop function public.get_my_clubs();
create function public.get_my_clubs()
returns table (
  club_id uuid,
  name text,
  code text,
  logo_path text,
  image_path text,
  primary_color text,
  secondary_color text,
  role text,
  member_number integer,
  active_season_name text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select c.id, c.name, c.code, c.logo_path, c.image_path, c.primary_color,
         c.secondary_color, coalesce(m.role, 'platform_admin'), m.member_number,
         s.name
  from public.clubs c
  left join public.club_memberships m
    on m.club_id = c.id
   and m.user_id = (select auth.uid())
   and m.status = 'active'
  left join public.seasons s on s.club_id = c.id and s.status = 'active'
  where c.is_active
    and (m.id is not null or (select public.is_platform_admin()))
  order by c.name;
$$;

revoke execute on function public.get_my_clubs() from public, anon;
grant execute on function public.get_my_clubs() to authenticated;
