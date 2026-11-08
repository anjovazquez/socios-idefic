-- VS-030: «Mis ventajas» (RF-025): valid perks of the club for its members,
-- with their sponsor when it is active.
create function public.get_my_perks(p_club_id uuid)
returns table (
  id uuid,
  title text,
  body text,
  image_path text,
  valid_from date,
  valid_until date,
  sponsor_name text,
  sponsor_logo_path text,
  sponsor_website_url text
)
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
  select p.id, p.title, p.body, p.image_path, p.valid_from, p.valid_until,
         s.name, s.logo_path, s.website_url
  from public.perks p
  left join public.sponsors s on s.id = p.sponsor_id and s.is_active
  where p.club_id = p_club_id
    and p.status = 'published'
    and (p.valid_from is null or p.valid_from <= public.madrid_today())
    and (p.valid_until is null or p.valid_until >= public.madrid_today())
  order by p.valid_until nulls last, p.title;
end;
$$;

revoke execute on function public.get_my_perks(uuid) from public, anon;
grant execute on function public.get_my_perks(uuid) to authenticated;
