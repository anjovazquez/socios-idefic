-- VS-003: platform administration of clubs (§3.1, §17).

create table public.platform_admins (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;
revoke all on public.platform_admins from anon, authenticated;

create function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.platform_admins where user_id = (select auth.uid())
  );
$$;

revoke execute on function public.is_platform_admin() from public, anon;
grant execute on function public.is_platform_admin() to authenticated;

-- Sensitive operations, attributed to the real actor (§17).
create table public.audit_log (
  id bigint generated always as identity primary key,
  club_id uuid references public.clubs (id) on delete set null,
  actor_id uuid references public.profiles (id) on delete set null,
  as_platform_admin boolean not null default false,
  action text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_club_id_idx on public.audit_log (club_id, created_at desc);

alter table public.audit_log enable row level security;
revoke all on public.audit_log from anon;
revoke insert, update, delete, truncate on public.audit_log from authenticated;

create policy audit_log_select_platform on public.audit_log
  for select to authenticated
  using ((select public.is_platform_admin()));

create function public.audit(
  p_club_id uuid,
  p_action text,
  p_payload jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_log (club_id, actor_id, as_platform_admin, action, payload)
  values (
    p_club_id,
    (select auth.uid()),
    (select public.is_platform_admin()),
    p_action,
    coalesce(p_payload, '{}'::jsonb)
  );
$$;

revoke execute on function public.audit(uuid, text, jsonb) from public, anon, authenticated;

-- Pending sign-ups by a club. VS-006 adds token, expiry and email delivery.
create table public.club_invitations (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  email text not null check (email = lower(email) and email like '%_@_%'),
  first_name text,
  role text not null default 'member' check (role in ('club_admin', 'member')),
  invited_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);

create unique index club_invitations_pending_idx
  on public.club_invitations (club_id, email)
  where accepted_at is null;

alter table public.club_invitations enable row level security;
revoke all on public.club_invitations from anon;
revoke insert, update, delete, truncate on public.club_invitations from authenticated;

create policy club_invitations_select_platform on public.club_invitations
  for select to authenticated
  using ((select public.is_platform_admin()));

-- One administrator per club in the MVP (§3.2).
create unique index club_memberships_one_admin_idx
  on public.club_memberships (club_id)
  where role = 'club_admin' and status <> 'inactive';

create unique index club_invitations_one_admin_idx
  on public.club_invitations (club_id)
  where role = 'club_admin' and accepted_at is null;

-- Platform admins read every club (including deactivated ones).
create policy clubs_select_platform on public.clubs
  for select to authenticated
  using ((select public.is_platform_admin()));

create function public.require_platform_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'platform admin required' using errcode = '42501';
  end if;
end;
$$;

revoke execute on function public.require_platform_admin() from public, anon, authenticated;

create function public.normalize_club_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(regexp_replace(coalesce(p_code, ''), '\s+', '', 'g'));
$$;

-- Makes [p_email] the administrator of [p_club_id]: directly when the user
-- exists (RF-004), otherwise as a pending invitation (sent in VS-006).
create function public.assign_club_admin(
  p_club_id uuid,
  p_email text,
  p_name text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(p_email));
  v_user_id uuid;
  v_next_number integer;
begin
  perform public.require_platform_admin();

  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid admin email' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.club_memberships
    where club_id = p_club_id and role = 'club_admin' and status <> 'inactive'
  ) or exists (
    select 1 from public.club_invitations
    where club_id = p_club_id and role = 'club_admin' and accepted_at is null
  ) then
    raise exception 'club already has an admin' using errcode = 'P0001',
      hint = 'club_already_has_admin';
  end if;

  select id into v_user_id from public.profiles where email = v_email;

  if v_user_id is null then
    insert into public.club_invitations (club_id, email, first_name, role, invited_by)
    values (p_club_id, v_email, nullif(trim(p_name), ''), 'club_admin', (select auth.uid()));
    perform public.audit(p_club_id, 'club_admin_invited', jsonb_build_object('email', v_email));
    return 'invited';
  end if;

  select coalesce(max(member_number), 0) + 1 into v_next_number
  from public.club_memberships where club_id = p_club_id;

  insert into public.club_memberships (user_id, club_id, role, member_number, status)
  values (v_user_id, p_club_id, 'club_admin', v_next_number, 'active')
  on conflict (user_id, club_id) do update
    set role = 'club_admin', status = 'active', updated_at = now();

  perform public.audit(p_club_id, 'club_admin_assigned', jsonb_build_object('email', v_email));
  return 'assigned';
end;
$$;

create function public.create_club(
  p_name text,
  p_code text,
  p_admin_email text,
  p_admin_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id uuid;
  v_code text := public.normalize_club_code(p_code);
begin
  perform public.require_platform_admin();

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'club name required' using errcode = '22023';
  end if;
  if v_code !~ '^[A-Z0-9_-]{2,20}$' then
    raise exception 'invalid club code' using errcode = '22023';
  end if;

  insert into public.clubs (name, code)
  values (trim(p_name), v_code)
  returning id into v_club_id;

  perform public.audit(v_club_id, 'club_created', jsonb_build_object('name', trim(p_name), 'code', v_code));
  perform public.assign_club_admin(v_club_id, p_admin_email, p_admin_name);

  return v_club_id;
end;
$$;

create function public.update_club(p_club_id uuid, p_name text, p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := public.normalize_club_code(p_code);
begin
  perform public.require_platform_admin();

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'club name required' using errcode = '22023';
  end if;
  if v_code !~ '^[A-Z0-9_-]{2,20}$' then
    raise exception 'invalid club code' using errcode = '22023';
  end if;

  update public.clubs
  set name = trim(p_name), code = v_code, updated_at = now()
  where id = p_club_id;
  if not found then
    raise exception 'club not found' using errcode = 'P0002';
  end if;

  perform public.audit(p_club_id, 'club_updated', jsonb_build_object('name', trim(p_name), 'code', v_code));
end;
$$;

create function public.set_club_active(p_club_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_platform_admin();

  update public.clubs
  set is_active = p_active, updated_at = now()
  where id = p_club_id;
  if not found then
    raise exception 'club not found' using errcode = 'P0002';
  end if;

  perform public.audit(
    p_club_id,
    case when p_active then 'club_activated' else 'club_deactivated' end
  );
end;
$$;

create function public.get_platform_clubs()
returns table (
  club_id uuid,
  name text,
  code text,
  is_active boolean,
  member_count integer,
  admin_email text,
  pending_admin_email text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_platform_admin();

  return query
  select
    c.id,
    c.name,
    c.code,
    c.is_active,
    (select count(*)::integer from public.club_memberships m
      where m.club_id = c.id and m.status = 'active'),
    (select p.email from public.club_memberships m
      join public.profiles p on p.id = m.user_id
      where m.club_id = c.id and m.role = 'club_admin' and m.status <> 'inactive'
      limit 1),
    (select i.email from public.club_invitations i
      where i.club_id = c.id and i.role = 'club_admin' and i.accepted_at is null
      limit 1)
  from public.clubs c
  order by c.name;
end;
$$;

revoke execute on function public.assign_club_admin(uuid, text, text) from public, anon;
revoke execute on function public.create_club(text, text, text, text) from public, anon;
revoke execute on function public.update_club(uuid, text, text) from public, anon;
revoke execute on function public.set_club_active(uuid, boolean) from public, anon;
revoke execute on function public.get_platform_clubs() from public, anon;
grant execute on function public.assign_club_admin(uuid, text, text) to authenticated;
grant execute on function public.create_club(text, text, text, text) to authenticated;
grant execute on function public.update_club(uuid, text, text) to authenticated;
grant execute on function public.set_club_active(uuid, boolean) to authenticated;
grant execute on function public.get_platform_clubs() to authenticated;

-- The selector of a platform admin lists every active club (§17 "acceder al club").
create or replace function public.get_my_clubs()
returns table (
  club_id uuid,
  name text,
  code text,
  logo_path text,
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
  select c.id, c.name, c.code, c.logo_path, c.primary_color, c.secondary_color,
         coalesce(m.role, 'platform_admin'), m.member_number
  from public.clubs c
  left join public.club_memberships m
    on m.club_id = c.id
   and m.user_id = (select auth.uid())
   and m.status = 'active'
  where c.is_active
    and (m.id is not null or (select public.is_platform_admin()))
  order by c.name;
$$;
