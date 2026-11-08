-- VS-015: digital membership card of the signed-in member (RF-019, RF-021).

create function public.get_my_card(p_club_id uuid)
returns table (
  club_name text,
  club_logo_path text,
  club_primary_color text,
  club_secondary_color text,
  first_name text,
  last_name text,
  photo_path text,
  member_number integer,
  season_name text,
  state text,
  card_token text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_membership public.club_memberships;
  v_season public.seasons;
  v_season_membership public.season_memberships;
  v_state text;
begin
  select * into v_membership from public.club_memberships
  where club_id = p_club_id and user_id = (select auth.uid()) and status = 'active';
  if not found then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select * into v_season from public.seasons where club_id = p_club_id and status = 'active';
  if v_season.id is not null then
    select * into v_season_membership from public.season_memberships
    where club_membership_id = v_membership.id and season_id = v_season.id;
  end if;

  v_state := case
    when v_season.id is null then 'no_season'
    when v_season_membership.id is null then 'not_renewed'
    when v_season_membership.status = 'active' then 'active'
    when v_season_membership.status = 'pending_payment' then 'pending_payment'
    else 'not_renewed'
  end;

  return query
  select c.name, c.logo_path, c.primary_color, c.secondary_color,
         p.first_name, p.last_name, p.photo_path, v_membership.member_number,
         v_season.name, v_state,
         -- Only an active card carries the token of its QR (RN-014).
         case when v_state = 'active' then v_season_membership.card_token end
  from public.clubs c
  join public.profiles p on p.id = v_membership.user_id
  where c.id = p_club_id;
end;
$$;

revoke execute on function public.get_my_card(uuid) from public, anon;
grant execute on function public.get_my_card(uuid) to authenticated;
