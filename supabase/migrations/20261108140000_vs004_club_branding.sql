-- VS-004: club visual identity (§20, §16 Configuración).

alter table public.clubs add column image_path text;

-- Admin of a club = its club_admin or a platform admin (§17). VS-005 builds
-- the impersonation UI on top of this.
create function public.can_admin_club(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin()
    or exists (
      select 1 from public.club_memberships
      where club_id = p_club_id
        and user_id = (select auth.uid())
        and role = 'club_admin'
        and status = 'active'
    );
$$;

revoke execute on function public.can_admin_club(uuid) from public, anon;
grant execute on function public.can_admin_club(uuid) to authenticated;

create function public.update_club_branding(
  p_club_id uuid,
  p_name text,
  p_primary_color text,
  p_secondary_color text,
  p_logo_path text,
  p_image_path text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prefix text := p_club_id::text || '/';
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'club name required' using errcode = '22023';
  end if;
  if p_primary_color !~ '^#[0-9A-Fa-f]{6}$'
     or (p_secondary_color is not null and p_secondary_color !~ '^#[0-9A-Fa-f]{6}$') then
    raise exception 'invalid color' using errcode = '22023';
  end if;
  if (p_logo_path is not null and left(p_logo_path, length(v_prefix)) <> v_prefix)
     or (p_image_path is not null and left(p_image_path, length(v_prefix)) <> v_prefix) then
    raise exception 'asset outside club folder' using errcode = '22023';
  end if;

  update public.clubs
  set name = trim(p_name),
      primary_color = upper(p_primary_color),
      secondary_color = upper(p_secondary_color),
      logo_path = p_logo_path,
      image_path = p_image_path,
      updated_at = now()
  where id = p_club_id;
  if not found then
    raise exception 'club not found' using errcode = 'P0002';
  end if;

  perform public.audit(
    p_club_id,
    'club_branding_updated',
    jsonb_build_object(
      'name', trim(p_name),
      'primary_color', upper(p_primary_color),
      'secondary_color', upper(p_secondary_color),
      'logo_path', p_logo_path,
      'image_path', p_image_path
    )
  );
end;
$$;

revoke execute on function public.update_club_branding(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.update_club_branding(uuid, text, text, text, text, text) to authenticated;

-- Branding of the clubs the user can enter, for the settings screen.
create function public.get_club_branding(p_club_id uuid)
returns table (
  club_id uuid,
  name text,
  code text,
  primary_color text,
  secondary_color text,
  logo_path text,
  image_path text
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
  select c.id, c.name, c.code, c.primary_color, c.secondary_color, c.logo_path, c.image_path
  from public.clubs c where c.id = p_club_id;
end;
$$;

revoke execute on function public.get_club_branding(uuid) from public, anon;
grant execute on function public.get_club_branding(uuid) to authenticated;

-- Selector/theme data now includes the club image.
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
  member_number integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select c.id, c.name, c.code, c.logo_path, c.image_path, c.primary_color,
         c.secondary_color, coalesce(m.role, 'platform_admin'), m.member_number
  from public.clubs c
  left join public.club_memberships m
    on m.club_id = c.id
   and m.user_id = (select auth.uid())
   and m.status = 'active'
  where c.is_active
    and (m.id is not null or (select public.is_platform_admin()))
  order by c.name;
$$;

revoke execute on function public.get_my_clubs() from public, anon;
grant execute on function public.get_my_clubs() to authenticated;

-- Brand assets (logos, images): public read because they also appear on the
-- public QR validation page and in emails (D-017). Writes only by the club
-- admin or a platform admin, inside "<club_id>/".
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'club-assets', 'club-assets', true, 2097152,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

-- Uploads use upsert, which also needs SELECT on the rows. The bucket is
-- public anyway, so signed-in users may list its objects.
create policy club_assets_select on storage.objects
  for select to authenticated
  using (bucket_id = 'club-assets');

create policy club_assets_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'club-assets'
    and public.can_admin_club(((storage.foldername(name))[1])::uuid)
  );

create policy club_assets_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'club-assets'
    and public.can_admin_club(((storage.foldername(name))[1])::uuid)
  );

create policy club_assets_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'club-assets'
    and public.can_admin_club(((storage.foldername(name))[1])::uuid)
  );
