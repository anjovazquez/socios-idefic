-- VS-011: member management for the club admin (§16 Socios).

drop function public.get_club_members(uuid);

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
           m.member_number, m.role, m.status, i.last_sent_at as invited_at
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

-- Leaving the club keeps the number and the history; access is revoked
-- because only active memberships reach the club (get_my_clubs).
create function public.deactivate_membership(p_membership_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_membership public.club_memberships;
begin
  select * into v_membership from public.club_memberships where id = p_membership_id for update;
  if not found or not public.can_admin_club(v_membership.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if v_membership.role = 'club_admin' then
    raise exception 'the club admin cannot be deactivated' using errcode = 'P0001',
      hint = 'cannot_deactivate_admin';
  end if;
  if v_membership.status = 'inactive' then
    return;
  end if;

  update public.club_memberships
  set status = 'inactive', updated_at = now()
  where id = p_membership_id;

  perform public.audit(v_membership.club_id, 'member_deactivated',
    jsonb_build_object('membership_id', p_membership_id, 'member_number', v_membership.member_number));
end;
$$;

-- Back with the same number: active if the first access was completed,
-- otherwise invited again (the admin can resend the invitation).
create function public.reactivate_membership(p_membership_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_membership public.club_memberships;
  v_status text;
begin
  select * into v_membership from public.club_memberships where id = p_membership_id for update;
  if not found or not public.can_admin_club(v_membership.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if v_membership.status <> 'inactive' then
    return v_membership.status;
  end if;

  select case when p.onboarded_at is not null then 'active' else 'invited' end
  into v_status
  from public.profiles p where p.id = v_membership.user_id;

  update public.club_memberships
  set status = v_status, updated_at = now()
  where id = p_membership_id;

  perform public.audit(v_membership.club_id, 'member_reactivated',
    jsonb_build_object('membership_id', p_membership_id, 'member_number', v_membership.member_number));
  return v_status;
end;
$$;

revoke execute on function public.deactivate_membership(uuid) from public, anon;
revoke execute on function public.reactivate_membership(uuid) from public, anon;
grant execute on function public.deactivate_membership(uuid) to authenticated;
grant execute on function public.reactivate_membership(uuid) to authenticated;
