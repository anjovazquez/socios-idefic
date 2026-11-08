-- VS-029: perks for members (RF-024, RN-015), optionally of a sponsor.

create table public.perks (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  sponsor_id uuid references public.sponsors (id) on delete set null,
  title text not null check (char_length(trim(title)) between 3 and 120),
  body text not null check (char_length(trim(body)) between 1 and 4000),
  image_path text,
  valid_from date,
  valid_until date,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_until is null or valid_from is null or valid_until >= valid_from)
);
create index perks_club_idx on public.perks (club_id, status);

alter table public.perks enable row level security;
-- Members see published perks within their validity (Madrid calendar);
-- the admin sees everything of the club. Writes only through the RPCs.
create policy perks_select on public.perks for select to authenticated
using (
  public.can_admin_club(club_id)
  or (
    status = 'published'
    and (valid_from is null or valid_from <= public.madrid_today())
    and (valid_until is null or valid_until >= public.madrid_today())
    and public.is_club_member(club_id)
  )
);
revoke all on public.perks from anon;

create function public.save_perk(
  p_perk_id uuid,
  p_club_id uuid,
  p_sponsor_id uuid,
  p_title text,
  p_body text,
  p_image_path text,
  p_valid_from date,
  p_valid_until date,
  p_publish boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_perk_id;
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if char_length(trim(coalesce(p_title, ''))) not between 3 and 120 then
    raise exception 'invalid title' using errcode = '22023';
  end if;
  if char_length(trim(coalesce(p_body, ''))) not between 1 and 4000 then
    raise exception 'invalid body' using errcode = '22023';
  end if;
  if p_valid_until is not null and p_valid_from is not null and p_valid_until < p_valid_from then
    raise exception 'invalid dates' using errcode = '22023';
  end if;
  -- RN-015: a perk belongs to a club; its sponsor too.
  if p_sponsor_id is not null and not exists (
    select 1 from public.sponsors where id = p_sponsor_id and club_id = p_club_id
  ) then
    raise exception 'invalid sponsor' using errcode = '22023';
  end if;
  if p_image_path is not null and left(p_image_path, 37) <> p_club_id::text || '/' then
    raise exception 'invalid image' using errcode = '22023';
  end if;

  if v_id is null then
    insert into public.perks (club_id, sponsor_id, title, body, image_path, valid_from, valid_until, status)
    values (p_club_id, p_sponsor_id, trim(p_title), trim(p_body), p_image_path, p_valid_from, p_valid_until,
            case when p_publish then 'published' else 'draft' end)
    returning id into v_id;
  else
    update public.perks
    set sponsor_id = p_sponsor_id, title = trim(p_title), body = trim(p_body), image_path = p_image_path,
        valid_from = p_valid_from, valid_until = p_valid_until,
        status = case when p_publish then 'published' else 'draft' end, updated_at = now()
    where id = v_id and club_id = p_club_id;
    if not found then
      raise exception 'perk not found' using errcode = 'P0002';
    end if;
  end if;
  perform public.audit(p_club_id, case when p_publish then 'perk_published' else 'perk_saved' end,
    jsonb_build_object('perk', v_id, 'title', trim(p_title)));
  return v_id;
end;
$$;

create function public.set_perk_status(p_perk_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_perk public.perks;
begin
  select * into v_perk from public.perks where id = p_perk_id;
  if not found then
    raise exception 'perk not found' using errcode = 'P0002';
  end if;
  if not public.can_admin_club(v_perk.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if p_status not in ('draft', 'archived') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  update public.perks set status = p_status, updated_at = now() where id = p_perk_id;
  perform public.audit(v_perk.club_id, 'perk_' || p_status, jsonb_build_object('perk', p_perk_id, 'title', v_perk.title));
end;
$$;

create function public.get_club_perks(p_club_id uuid)
returns table (
  id uuid,
  sponsor_id uuid,
  sponsor_name text,
  title text,
  body text,
  image_path text,
  valid_from date,
  valid_until date,
  status text,
  updated_at timestamptz
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
  select p.id, p.sponsor_id, s.name, p.title, p.body, p.image_path, p.valid_from, p.valid_until,
         p.status, p.updated_at
  from public.perks p
  left join public.sponsors s on s.id = p.sponsor_id
  where p.club_id = p_club_id
  order by (p.status = 'archived'), p.updated_at desc;
end;
$$;

revoke execute on function public.save_perk(uuid, uuid, uuid, text, text, text, date, date, boolean) from public, anon;
revoke execute on function public.set_perk_status(uuid, text) from public, anon;
revoke execute on function public.get_club_perks(uuid) from public, anon;
grant execute on function public.save_perk(uuid, uuid, uuid, text, text, text, date, date, boolean) to authenticated;
grant execute on function public.set_perk_status(uuid, text) to authenticated;
grant execute on function public.get_club_perks(uuid) to authenticated;
