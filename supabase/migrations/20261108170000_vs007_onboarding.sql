-- VS-007: first access of an invited member (RF-003).

alter table public.profiles add column onboarded_at timestamptz;

create table public.terms_acceptances (
  user_id uuid not null references public.profiles (id) on delete cascade,
  version text not null,
  accepted_at timestamptz not null default now(),
  primary key (user_id, version)
);

alter table public.terms_acceptances enable row level security;
revoke all on public.terms_acceptances from anon;
revoke insert, update, delete, truncate on public.terms_acceptances from authenticated;

create policy terms_acceptances_select_own on public.terms_acceptances
  for select to authenticated
  using (user_id = (select auth.uid()));

-- Version of the conditions members must accept. Bump it when the text in
-- the app changes: everyone accepts again on their next access.
create function public.current_terms_version()
returns text
language sql
immutable
set search_path = ''
as $$
  select '2026-11-v1'::text;
$$;

grant execute on function public.current_terms_version() to authenticated;

create function public.get_my_onboarding_status()
returns table (
  completed boolean,
  needs_password boolean,
  terms_version text,
  email text,
  first_name text,
  last_name text,
  phone text,
  birth_date date
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.onboarded_at is not null
      and exists (
        select 1 from public.terms_acceptances t
        where t.user_id = p.id and t.version = public.current_terms_version()
      ),
    p.onboarded_at is null
      and not exists (
        select 1 from auth.identities i
        where i.user_id = p.id and i.provider <> 'email'
      ),
    public.current_terms_version(),
    p.email,
    coalesce(p.first_name, u.raw_user_meta_data ->> 'first_name'),
    p.last_name,
    p.phone,
    p.birth_date
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id = (select auth.uid());
$$;

revoke execute on function public.get_my_onboarding_status() from public, anon;
grant execute on function public.get_my_onboarding_status() to authenticated;

create function public.complete_onboarding(
  p_first_name text,
  p_last_name text,
  p_phone text,
  p_birth_date date,
  p_terms_version text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '[\s.-]', '', 'g'), '');
  v_club record;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_first_name, ''))) = 0 then
    raise exception 'first name required' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_last_name, ''))) = 0 then
    raise exception 'last name required' using errcode = '22023';
  end if;
  if v_phone is not null and v_phone !~ '^\+?[0-9]{9,15}$' then
    raise exception 'invalid phone' using errcode = '22023';
  end if;
  if p_birth_date is not null and (p_birth_date > current_date or p_birth_date < date '1900-01-01') then
    raise exception 'invalid birth date' using errcode = '22023';
  end if;
  if p_terms_version is distinct from public.current_terms_version() then
    raise exception 'terms not accepted' using errcode = 'P0001', hint = 'terms_outdated';
  end if;

  update public.profiles
  set first_name = trim(p_first_name),
      last_name = trim(p_last_name),
      phone = v_phone,
      birth_date = p_birth_date,
      onboarded_at = coalesce(onboarded_at, now()),
      updated_at = now()
  where id = v_user_id;

  insert into public.terms_acceptances (user_id, version)
  values (v_user_id, p_terms_version)
  on conflict do nothing;

  for v_club in
    update public.club_memberships
    set status = 'active', updated_at = now()
    where user_id = v_user_id and status = 'invited'
    returning club_id
  loop
    perform public.audit(v_club.club_id, 'member_activated', '{}'::jsonb);
  end loop;

  update public.club_invitations
  set accepted_at = now()
  where user_id = v_user_id and accepted_at is null;
end;
$$;

revoke execute on function public.complete_onboarding(text, text, text, date, text) from public, anon;
grant execute on function public.complete_onboarding(text, text, text, date, text) to authenticated;
