-- VS-016: public validation of the card QR (RF-020, RN-017).

-- Server-only (Edge Function `validate-card` with the service role): the
-- public never calls it directly. Returns only the RF-020 data.
create function public.validate_card(p_token text)
returns table (
  state text,
  club_name text,
  club_logo_path text,
  club_primary_color text,
  first_name text,
  last_name text,
  photo_path text,
  member_number integer,
  season_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    case
      when s.status = 'active' and sm.status = 'active' and m.status = 'active' and c.is_active
        then 'active'
      else 'not_current'
    end,
    c.name, c.logo_path, c.primary_color,
    p.first_name, p.last_name, p.photo_path,
    m.member_number, s.name
  from public.season_memberships sm
  join public.seasons s on s.id = sm.season_id
  join public.club_memberships m on m.id = sm.club_membership_id
  join public.clubs c on c.id = m.club_id
  join public.profiles p on p.id = m.user_id
  where sm.card_token = p_token
    and length(coalesce(p_token, '')) >= 16;
$$;

revoke execute on function public.validate_card(text) from public, anon, authenticated;
grant execute on function public.validate_card(text) to service_role;

-- New token for a season membership (e.g. a leaked QR): the old one stops
-- working immediately.
create function public.regenerate_card_token(p_season_membership_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id uuid;
begin
  select m.club_id into v_club_id
  from public.season_memberships sm
  join public.club_memberships m on m.id = sm.club_membership_id
  where sm.id = p_season_membership_id;
  if v_club_id is null or not public.can_admin_club(v_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;

  update public.season_memberships
  set card_token = translate(encode(extensions.gen_random_bytes(16), 'base64'), '+/=', '-_'),
      updated_at = now()
  where id = p_season_membership_id;

  perform public.audit(v_club_id, 'card_regenerated',
    jsonb_build_object('season_membership_id', p_season_membership_id));
end;
$$;

revoke execute on function public.regenerate_card_token(uuid) from public, anon;
grant execute on function public.regenerate_card_token(uuid) to authenticated;
