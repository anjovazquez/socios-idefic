-- VS-010: per-club member number, editable only by the club admin
-- (RF-006, RN-006). New members get max + 1 (see attach_invited_member).

create function public.set_member_number(p_membership_id uuid, p_number integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_membership public.club_memberships;
begin
  select * into v_membership from public.club_memberships where id = p_membership_id;
  if not found or not public.can_admin_club(v_membership.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if p_number is null or p_number <= 0 then
    raise exception 'invalid member number' using errcode = '22023';
  end if;
  if v_membership.member_number = p_number then
    return;
  end if;
  if exists (
    select 1 from public.club_memberships
    where club_id = v_membership.club_id and member_number = p_number
  ) then
    raise exception 'member number taken' using errcode = 'P0001', hint = 'number_taken';
  end if;

  update public.club_memberships
  set member_number = p_number, updated_at = now()
  where id = p_membership_id;

  perform public.audit(
    v_membership.club_id,
    'member_number_changed',
    jsonb_build_object('membership_id', p_membership_id, 'from', v_membership.member_number, 'to', p_number)
  );
end;
$$;

revoke execute on function public.set_member_number(uuid, integer) from public, anon;
grant execute on function public.set_member_number(uuid, integer) to authenticated;
