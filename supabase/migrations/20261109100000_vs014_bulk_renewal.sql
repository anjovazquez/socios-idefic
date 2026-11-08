-- VS-014: bulk renewal from the previous season (RF-009, RN-011).

create function public.previous_season_id(p_season_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select prev.id
  from public.seasons target
  join public.seasons prev on prev.club_id = target.club_id and prev.name < target.name
  where target.id = p_season_id and prev.status <> 'draft'
  order by prev.name desc
  limit 1;
$$;

revoke execute on function public.previous_season_id(uuid) from public, anon, authenticated;

-- Members of the previous season who can be renewed into [p_season_id].
-- Proposed fee: the ordinary fee of the target season (or of the previous
-- one while the target has none), or the previous custom fee if
-- [p_keep_custom].
create function public.get_renewal_candidates(p_season_id uuid, p_keep_custom boolean default true)
returns table (
  membership_id uuid,
  email text,
  first_name text,
  last_name text,
  member_number integer,
  previous_season_name text,
  previous_fee_cents integer,
  previous_was_custom boolean,
  proposed_fee_cents integer,
  already_renewed boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_target public.seasons;
  v_prev public.seasons;
begin
  select * into v_target from public.seasons where id = p_season_id;
  if not found or not public.can_admin_club(v_target.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  select * into v_prev from public.seasons where id = public.previous_season_id(p_season_id);
  if v_prev.id is null then
    return;
  end if;

  return query
  select m.id, p.email, p.first_name, p.last_name, m.member_number,
         v_prev.name,
         prev_sm.fee_cents,
         prev_sm.fee_cents is distinct from v_prev.default_fee_cents,
         case
           when p_keep_custom and prev_sm.fee_cents is distinct from v_prev.default_fee_cents
             then prev_sm.fee_cents
           else coalesce(v_target.default_fee_cents, v_prev.default_fee_cents)
         end,
         exists (
           select 1 from public.season_memberships t
           where t.club_membership_id = m.id and t.season_id = v_target.id
         )
  from public.season_memberships prev_sm
  join public.club_memberships m on m.id = prev_sm.club_membership_id
  join public.profiles p on p.id = m.user_id
  where prev_sm.season_id = v_prev.id
    and prev_sm.status = 'active'
    and m.status <> 'inactive'
  order by m.member_number nulls last, p.email;
end;
$$;

-- Creates the renewals of [p_items] = [{"membership_id": …, "fee_cents": …}]
-- in one transaction. Idempotent: members already in the season are skipped.
create function public.bulk_renew(p_season_id uuid, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.seasons;
  v_prev_id uuid;
  v_item jsonb;
  v_membership_id uuid;
  v_fee integer;
  v_created integer := 0;
  v_total bigint := 0;
  v_rows integer;
begin
  select * into v_target from public.seasons where id = p_season_id;
  if not found or not public.can_admin_club(v_target.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if v_target.status = 'closed' then
    raise exception 'closed season' using errcode = 'P0001', hint = 'season_closed';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'invalid items' using errcode = '22023';
  end if;
  v_prev_id := public.previous_season_id(p_season_id);

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_membership_id := (v_item ->> 'membership_id')::uuid;
    v_fee := (v_item ->> 'fee_cents')::integer;
    if v_fee is null or v_fee < 0 then
      raise exception 'invalid fee' using errcode = '22023';
    end if;
    -- Only renewable members of this club (active in the previous season,
    -- not deactivated).
    if not exists (
      select 1
      from public.season_memberships prev_sm
      join public.club_memberships m on m.id = prev_sm.club_membership_id
      where prev_sm.club_membership_id = v_membership_id
        and prev_sm.season_id = v_prev_id
        and prev_sm.status = 'active'
        and m.club_id = v_target.club_id
        and m.status <> 'inactive'
    ) then
      raise exception 'member not renewable' using errcode = 'P0001', hint = 'not_renewable';
    end if;

    insert into public.season_memberships (club_membership_id, season_id, fee_cents, status)
    values (v_membership_id, p_season_id, v_fee,
            case when v_fee = 0 then 'active' else 'pending_payment' end)
    on conflict (club_membership_id, season_id) do nothing;
    get diagnostics v_rows = row_count;
    v_created := v_created + v_rows;
    if v_rows > 0 then
      v_total := v_total + v_fee;
    end if;
  end loop;

  perform public.audit(v_target.club_id, 'season_renewed',
    jsonb_build_object('name', v_target.name, 'renewed', v_created, 'total_cents', v_total));
  return v_created;
end;
$$;

revoke execute on function public.get_renewal_candidates(uuid, boolean) from public, anon;
revoke execute on function public.bulk_renew(uuid, jsonb) from public, anon;
grant execute on function public.get_renewal_candidates(uuid, boolean) to authenticated;
grant execute on function public.bulk_renew(uuid, jsonb) to authenticated;
