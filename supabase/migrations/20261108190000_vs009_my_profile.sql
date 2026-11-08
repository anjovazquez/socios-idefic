-- VS-009: "Mis datos" (RF-005).

-- Private member photos: "<user_id>/<file>". The owner reads and writes;
-- administrators of the owner's clubs read (to see who is who). The public QR
-- validation gets a short signed URL from the server (VS-016).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos', 'profile-photos', false, 2097152,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

create function public.can_see_member_photo(p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_owner = (select auth.uid())
    or public.is_platform_admin()
    or exists (
      select 1
      from public.club_memberships owner_m
      join public.club_memberships admin_m
        on admin_m.club_id = owner_m.club_id
       and admin_m.user_id = (select auth.uid())
       and admin_m.role = 'club_admin'
       and admin_m.status = 'active'
      where owner_m.user_id = p_owner
    );
$$;

revoke execute on function public.can_see_member_photo(uuid) from public, anon;
grant execute on function public.can_see_member_photo(uuid) to authenticated;

create policy profile_photos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and public.can_see_member_photo(((storage.foldername(name))[1])::uuid)
  );

create policy profile_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy profile_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy profile_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Only the person changes their own data; the email is the login and stays.
create function public.update_my_profile(
  p_first_name text,
  p_last_name text,
  p_phone text,
  p_birth_date date,
  p_photo_path text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '[\s.-]', '', 'g'), '');
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_first_name, ''))) = 0 then
    raise exception 'first name required' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_last_name, ''))) = 0 then
    raise exception 'last name required' using errcode = '22023';
  end if;
  if v_phone is not null and v_phone !~ '^\+?[0-9]{9,15}$' then
    raise exception 'invalid phone' using errcode = '22023';
  end if;
  if p_birth_date is not null and (p_birth_date > current_date or p_birth_date < date '1900-01-01') then
    raise exception 'invalid birth date' using errcode = '22023';
  end if;
  if p_photo_path is not null and left(p_photo_path, 37) <> v_user_id::text || '/' then
    raise exception 'invalid photo' using errcode = '22023';
  end if;

  update public.profiles
  set first_name = trim(p_first_name),
      last_name = trim(p_last_name),
      phone = v_phone,
      birth_date = p_birth_date,
      photo_path = p_photo_path,
      updated_at = now()
  where id = v_user_id;
end;
$$;

revoke execute on function public.update_my_profile(text, text, text, date, text) from public, anon;
grant execute on function public.update_my_profile(text, text, text, date, text) to authenticated;
