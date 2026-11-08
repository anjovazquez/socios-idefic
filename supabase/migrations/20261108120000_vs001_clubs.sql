-- VS-001: global users, clubs and per-club membership (RF-001, RF-030, RN-003..RN-006).

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  first_name text,
  last_name text,
  phone text,
  birth_date date,
  photo_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_email_lowercase check (email = lower(email))
);

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  code text not null unique check (code = upper(code) and length(code) between 2 and 20),
  logo_path text,
  primary_color text check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  secondary_color text check (secondary_color ~ '^#[0-9A-Fa-f]{6}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.club_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  club_id uuid not null references public.clubs (id) on delete cascade,
  role text not null default 'member' check (role in ('club_admin', 'member')),
  member_number integer check (member_number > 0),
  status text not null default 'active' check (status in ('invited', 'active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, club_id),
  unique (club_id, member_number)
);

create index club_memberships_club_id_idx on public.club_memberships (club_id);

-- Every auth user gets a global profile keyed by the same id.
create function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, lower(new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

alter table public.profiles enable row level security;
alter table public.clubs enable row level security;
alter table public.club_memberships enable row level security;

revoke all on public.profiles, public.clubs, public.club_memberships from anon;
revoke insert, update, delete, truncate on public.profiles, public.clubs, public.club_memberships from authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy club_memberships_select_own on public.club_memberships
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy clubs_select_member on public.clubs
  for select to authenticated
  using (
    is_active
    and exists (
      select 1
      from public.club_memberships m
      where m.club_id = clubs.id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
    )
  );

-- Clubs the current user can enter (selector, RF-030).
create function public.get_my_clubs()
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
         m.role, m.member_number
  from public.club_memberships m
  join public.clubs c on c.id = m.club_id
  where m.user_id = (select auth.uid())
    and m.status = 'active'
    and c.is_active
  order by c.name;
$$;

revoke execute on function public.get_my_clubs() from public, anon;
grant execute on function public.get_my_clubs() to authenticated;
revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;
