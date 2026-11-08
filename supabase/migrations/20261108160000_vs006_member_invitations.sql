-- VS-006: sign-up of members by the club admin with an email invitation
-- (RF-002, RN-001, RN-002).

alter table public.club_invitations
  add column user_id uuid references public.profiles (id) on delete set null,
  add column last_sent_at timestamptz,
  add column send_count integer not null default 0;

create function public.normalize_email(p_email text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(trim(coalesce(p_email, '')));
$$;

-- Step 1 (as the club admin): validates and records the invitation.
-- Returns whether the person already has an account (RF-004).
create function public.prepare_member_invitation(
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

  select p.id into v_user_id from public.profiles p where p.email = v_email;

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
  select v_invitation_id, v_email, v_name, v_user_id,
         coalesce((select u.last_sign_in_at is not null from auth.users u where u.id = v_user_id), false),
         c.name, c.logo_path, c.primary_color
  from public.clubs c where c.id = p_club_id;
end;
$$;

revoke execute on function public.prepare_member_invitation(uuid, text, text) from public, anon;
grant execute on function public.prepare_member_invitation(uuid, text, text) to authenticated;

-- Step 2 (Edge Function, service role, after the auth user exists): links the
-- membership and counts the email. New accounts stay `invited` until they
-- complete the first access (VS-007); existing accounts join directly.
create function public.attach_invited_member(
  p_invitation_id uuid,
  p_user_id uuid,
  p_status text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invitation public.club_invitations;
  v_membership_id uuid;
  v_next_number integer;
begin
  if p_status not in ('invited', 'active') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  select * into v_invitation from public.club_invitations where id = p_invitation_id for update;
  if not found then
    raise exception 'invitation not found' using errcode = 'P0002';
  end if;

  -- Numbers are per club (RN-006); serialize concurrent sign-ups of a club.
  perform 1 from public.clubs where id = v_invitation.club_id for update;
  select coalesce(max(member_number), 0) + 1 into v_next_number
  from public.club_memberships where club_id = v_invitation.club_id;

  insert into public.club_memberships (user_id, club_id, role, member_number, status)
  values (p_user_id, v_invitation.club_id, 'member', v_next_number, p_status)
  on conflict (user_id, club_id) do update
    set status = case
          when public.club_memberships.status = 'active' then 'active'
          else excluded.status
        end,
        updated_at = now()
  returning id into v_membership_id;

  update public.club_invitations
  set user_id = p_user_id,
      last_sent_at = now(),
      send_count = send_count + 1,
      accepted_at = case when p_status = 'active' then now() else accepted_at end
  where id = p_invitation_id;

  return v_membership_id;
end;
$$;

revoke execute on function public.attach_invited_member(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.attach_invited_member(uuid, uuid, text) to service_role;

-- Members of a club for its administration (RF-002; VS-011 adds search).
create function public.get_club_members(p_club_id uuid)
returns table (
  membership_id uuid,
  user_id uuid,
  email text,
  first_name text,
  last_name text,
  member_number integer,
  role text,
  status text,
  invited_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;

  return query
  select m.id, m.user_id, p.email,
         coalesce(p.first_name, i.first_name), p.last_name,
         m.member_number, m.role, m.status, i.last_sent_at
  from public.club_memberships m
  join public.profiles p on p.id = m.user_id
  left join lateral (
    select ci.first_name, ci.last_sent_at
    from public.club_invitations ci
    where ci.club_id = m.club_id and ci.email = p.email
    order by ci.created_at desc
    limit 1
  ) i on true
  where m.club_id = p_club_id
  order by m.member_number nulls last, p.email;
end;
$$;

revoke execute on function public.get_club_members(uuid) from public, anon;
grant execute on function public.get_club_members(uuid) to authenticated;

-- Resend (as the club admin): returns the pending invitation of a member.
create function public.prepare_invitation_resend(p_membership_id uuid)
returns table (
  invitation_id uuid,
  email text,
  first_name text,
  user_id uuid,
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
  v_membership public.club_memberships;
begin
  select * into v_membership from public.club_memberships where id = p_membership_id;
  if not found or not public.can_admin_club(v_membership.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if v_membership.status <> 'invited' then
    raise exception 'not pending' using errcode = 'P0001', hint = 'not_pending';
  end if;

  perform public.audit(v_membership.club_id, 'member_invitation_resent',
    jsonb_build_object('membership_id', p_membership_id));

  return query
  select i.id, i.email, i.first_name, v_membership.user_id, c.name, c.logo_path, c.primary_color
  from public.club_invitations i
  join public.clubs c on c.id = i.club_id
  where i.club_id = v_membership.club_id
    and i.user_id = v_membership.user_id
    and i.accepted_at is null
  order by i.created_at desc
  limit 1;
end;
$$;

revoke execute on function public.prepare_invitation_resend(uuid) from public, anon;
grant execute on function public.prepare_invitation_resend(uuid) to authenticated;
