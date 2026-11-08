-- VS-008: an existing account joins another club (RF-004, RN-003..RN-005).
-- "Existing active account" means the first access was completed: someone
-- who opened an invitation but never finished it gets a new activation link.

create or replace function public.prepare_member_invitation(
  p_club_id uuid,
  p_email text,
  p_first_name text
)
returns table (
  invitation_id uuid,
  email text,
  first_name text,
  existing_user_id uuid,
  existing_user_active boolean,
  club_name text,
  club_logo_path text,
  club_primary_color text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_email text := public.normalize_email(p_email);
  v_name text := nullif(trim(coalesce(p_first_name, '')), '');
  v_user_id uuid;
  v_onboarded boolean;
  v_invitation_id uuid;
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if v_name is null then
    raise exception 'member name required' using errcode = '22023';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid member email' using errcode = '22023';
  end if;

  select p.id, p.onboarded_at is not null
  into v_user_id, v_onboarded
  from public.profiles p
  where p.email = v_email;

  if v_user_id is not null and exists (
    select 1 from public.club_memberships m
    where m.club_id = p_club_id and m.user_id = v_user_id and m.status = 'active'
  ) then
    raise exception 'already a member' using errcode = 'P0001', hint = 'already_member';
  end if;

  insert into public.club_invitations (club_id, email, first_name, role, invited_by, user_id)
  values (p_club_id, v_email, v_name, 'member', (select auth.uid()), v_user_id)
  on conflict (club_id, email) where accepted_at is null
  do update set first_name = excluded.first_name
  returning id into v_invitation_id;

  perform public.audit(p_club_id, 'member_invited', jsonb_build_object('email', v_email, 'name', v_name));

  return query
  select v_invitation_id, v_email, v_name, v_user_id, coalesce(v_onboarded, false),
         c.name, c.logo_path, c.primary_color
  from public.clubs c where c.id = p_club_id;
end;
$$;
