-- VS-028: members see the active sponsors of the active season (RF-029).
create function public.get_club_active_sponsors(p_club_id uuid)
returns table (id uuid, name text, logo_path text, website_url text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_club_member(p_club_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  return query
  select sp.id, sp.name, sp.logo_path, sp.website_url
  from public.sponsors sp
  join public.sponsor_seasons ss on ss.sponsor_id = sp.id
  join public.seasons se on se.id = ss.season_id and se.status = 'active'
  where sp.club_id = p_club_id and sp.is_active
  order by sp.name;
end;
$$;

revoke execute on function public.get_club_active_sponsors(uuid) from public, anon;
grant execute on function public.get_club_active_sponsors(uuid) to authenticated;
