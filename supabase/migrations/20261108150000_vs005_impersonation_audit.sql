-- VS-005: functional impersonation by the platform admin (§17).

-- "As platform admin" means acting on a club without being its own admin.
create or replace function public.audit(
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
    (select public.is_platform_admin())
      and not exists (
        select 1 from public.club_memberships
        where club_id = p_club_id
          and user_id = (select auth.uid())
          and role = 'club_admin'
          and status = 'active'
      ),
    p_action,
    coalesce(p_payload, '{}'::jsonb)
  );
$$;

revoke execute on function public.audit(uuid, text, jsonb) from public, anon, authenticated;

create function public.get_audit_log(
  p_club_id uuid default null,
  p_before_id bigint default null,
  p_limit integer default 50
)
returns table (
  id bigint,
  club_id uuid,
  club_name text,
  actor_email text,
  as_platform_admin boolean,
  action text,
  payload jsonb,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_platform_admin();

  return query
  select a.id, a.club_id, c.name, p.email, a.as_platform_admin, a.action,
         a.payload, a.created_at
  from public.audit_log a
  left join public.clubs c on c.id = a.club_id
  left join public.profiles p on p.id = a.actor_id
  where (p_club_id is null or a.club_id = p_club_id)
    and (p_before_id is null or a.id < p_before_id)
  order by a.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

revoke execute on function public.get_audit_log(uuid, bigint, integer) from public, anon;
grant execute on function public.get_audit_log(uuid, bigint, integer) to authenticated;
