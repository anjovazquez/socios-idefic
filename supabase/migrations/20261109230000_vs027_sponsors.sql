-- VS-027: sponsors per season (RF-026…RF-028, RN-016). A sponsor of
-- 2026/2027 does not appear in 2027/2028 until the club renews it.

create table public.sponsors (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 80),
  logo_path text,
  website_url text check (website_url is null or website_url ~ '^https://[^\s/?#]+\.[^\s]+$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (club_id, name)
);

create table public.sponsor_seasons (
  sponsor_id uuid not null references public.sponsors (id) on delete cascade,
  season_id uuid not null references public.seasons (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (sponsor_id, season_id)
);

alter table public.sponsors enable row level security;
alter table public.sponsor_seasons enable row level security;
-- The admin reads everything of the club; members get their view in VS-028.
create policy sponsors_admin_select on public.sponsors for select to authenticated
using (public.can_admin_club(club_id));
create policy sponsor_seasons_admin_select on public.sponsor_seasons for select to authenticated
using (exists (
  select 1 from public.sponsors s where s.id = sponsor_id and public.can_admin_club(s.club_id)
));
revoke all on public.sponsors, public.sponsor_seasons from anon;

-- Admin: creates (p_sponsor_id null) or edits a sponsor.
create function public.save_sponsor(
  p_sponsor_id uuid,
  p_club_id uuid,
  p_name text,
  p_logo_path text,
  p_website_url text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_sponsor_id;
  v_url text := nullif(trim(coalesce(p_website_url, '')), '');
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if char_length(trim(coalesce(p_name, ''))) not between 2 and 80 then
    raise exception 'invalid name' using errcode = '22023';
  end if;
  if v_url is not null and v_url !~ '^https://[^\s/?#]+\.[^\s]+$' then
    raise exception 'invalid website' using errcode = '22023';
  end if;
  if p_logo_path is not null and left(p_logo_path, 37) <> p_club_id::text || '/' then
    raise exception 'invalid logo' using errcode = '22023';
  end if;

  begin
    if v_id is null then
      insert into public.sponsors (club_id, name, logo_path, website_url)
      values (p_club_id, trim(p_name), p_logo_path, v_url)
      returning id into v_id;
    else
      update public.sponsors
      set name = trim(p_name), logo_path = p_logo_path, website_url = v_url, updated_at = now()
      where id = v_id and club_id = p_club_id;
      if not found then
        raise exception 'sponsor not found' using errcode = 'P0002';
      end if;
    end if;
  exception when unique_violation then
    raise exception 'sponsor already exists' using errcode = '23505';
  end;
  perform public.audit(p_club_id, 'sponsor_saved', jsonb_build_object('sponsor', v_id, 'name', trim(p_name)));
  return v_id;
end;
$$;

create function public.sponsor_club(p_sponsor_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_club_id uuid;
begin
  select club_id into v_club_id from public.sponsors where id = p_sponsor_id;
  if v_club_id is null then
    raise exception 'sponsor not found' using errcode = 'P0002';
  end if;
  if not public.can_admin_club(v_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  return v_club_id;
end;
$$;

-- Admin: shows or hides a sponsor everywhere (keeps its seasons).
create function public.set_sponsor_active(p_sponsor_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id uuid := public.sponsor_club(p_sponsor_id);
begin
  update public.sponsors set is_active = p_active, updated_at = now() where id = p_sponsor_id;
  perform public.audit(v_club_id, case when p_active then 'sponsor_activated' else 'sponsor_deactivated' end,
    jsonb_build_object('sponsor', p_sponsor_id));
end;
$$;

-- Admin: the seasons of a sponsor (replaces them; only seasons of the club).
create function public.set_sponsor_seasons(p_sponsor_id uuid, p_season_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id uuid := public.sponsor_club(p_sponsor_id);
begin
  if exists (
    select 1 from unnest(coalesce(p_season_ids, '{}')) as sid
    where not exists (select 1 from public.seasons s where s.id = sid and s.club_id = v_club_id)
  ) then
    raise exception 'season of another club' using errcode = '22023';
  end if;
  delete from public.sponsor_seasons
  where sponsor_id = p_sponsor_id and season_id <> all (coalesce(p_season_ids, '{}'));
  insert into public.sponsor_seasons (sponsor_id, season_id)
  select p_sponsor_id, sid from unnest(coalesce(p_season_ids, '{}')) as sid
  on conflict do nothing;
  perform public.audit(v_club_id, 'sponsor_seasons_set',
    jsonb_build_object('sponsor', p_sponsor_id, 'seasons', to_jsonb(p_season_ids)));
end;
$$;

-- Admin: renews sponsors for a season in bulk (RF-028: never automatic).
-- Returns how many were added.
create function public.renew_sponsors(p_season_id uuid, p_sponsor_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id uuid;
  v_count integer;
begin
  select club_id into v_club_id from public.seasons where id = p_season_id;
  if v_club_id is null then
    raise exception 'season not found' using errcode = 'P0002';
  end if;
  if not public.can_admin_club(v_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if exists (
    select 1 from unnest(coalesce(p_sponsor_ids, '{}')) as sid
    where not exists (select 1 from public.sponsors s where s.id = sid and s.club_id = v_club_id)
  ) then
    raise exception 'sponsor of another club' using errcode = '22023';
  end if;
  insert into public.sponsor_seasons (sponsor_id, season_id)
  select sid, p_season_id from unnest(coalesce(p_sponsor_ids, '{}')) as sid
  on conflict do nothing;
  get diagnostics v_count = row_count;
  perform public.audit(v_club_id, 'sponsors_renewed',
    jsonb_build_object('season', p_season_id, 'added', v_count));
  return v_count;
end;
$$;

-- Admin: sponsors of the club with their seasons (names, newest first).
create function public.get_club_sponsors(p_club_id uuid)
returns table (
  id uuid,
  name text,
  logo_path text,
  website_url text,
  is_active boolean,
  season_ids uuid[],
  season_names text[]
)
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
  select sp.id, sp.name, sp.logo_path, sp.website_url, sp.is_active,
         coalesce(array_agg(se.id order by se.name desc) filter (where se.id is not null), '{}'),
         coalesce(array_agg(se.name order by se.name desc) filter (where se.id is not null), '{}')
  from public.sponsors sp
  left join public.sponsor_seasons ss on ss.sponsor_id = sp.id
  left join public.seasons se on se.id = ss.season_id
  where sp.club_id = p_club_id
  group by sp.id
  order by sp.is_active desc, sp.name;
end;
$$;

revoke execute on function public.save_sponsor(uuid, uuid, text, text, text) from public, anon;
revoke execute on function public.sponsor_club(uuid) from public, anon, authenticated;
revoke execute on function public.set_sponsor_active(uuid, boolean) from public, anon;
revoke execute on function public.set_sponsor_seasons(uuid, uuid[]) from public, anon;
revoke execute on function public.renew_sponsors(uuid, uuid[]) from public, anon;
revoke execute on function public.get_club_sponsors(uuid) from public, anon;
grant execute on function public.save_sponsor(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.set_sponsor_active(uuid, boolean) to authenticated;
grant execute on function public.set_sponsor_seasons(uuid, uuid[]) to authenticated;
grant execute on function public.renew_sponsors(uuid, uuid[]) to authenticated;
grant execute on function public.get_club_sponsors(uuid) to authenticated;
