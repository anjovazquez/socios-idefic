-- Local demo data only. Never applied to staging/production.
-- Passwords are local-only: <name>-password.

create or replace function pg_temp.seed_user(p_id uuid, p_email text, p_password text)
returns void
language plpgsql
as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data,
    raw_user_meta_data, is_super_admin, confirmation_token, email_change,
    email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated',
    'authenticated', p_email, crypt(p_password, gen_salt('bf')), now(), now(),
    now(), '{"provider":"email","providers":["email"]}', '{}', false, '', '',
    '', ''
  )
  on conflict (id) do nothing;

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, created_at, updated_at
  ) values (
    p_id::text, p_id,
    jsonb_build_object('sub', p_id::text, 'email', p_email),
    'email', now(), now()
  )
  on conflict do nothing;
end;
$$;

select pg_temp.seed_user('10000000-0000-0000-0000-000000000001', 'admin@example.com', 'admin-password');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000002', 'ana@example.com', 'ana-password');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000003', 'luis@example.com', 'luis-password');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000099', 'root@example.com', 'root-password');

update public.profiles set first_name = 'Admin', last_name = 'IDEFIC'
where id = '10000000-0000-0000-0000-000000000001';
update public.profiles set first_name = 'Ana', last_name = 'Pérez'
where id = '10000000-0000-0000-0000-000000000002';
update public.profiles set first_name = 'Luis', last_name = 'García'
where id = '10000000-0000-0000-0000-000000000003';

insert into public.clubs (id, name, code, primary_color, secondary_color, is_active) values
  ('20000000-0000-0000-0000-000000000001', 'IDEFIC', 'IDEFIC', '#0B3D91', '#F2A900', true),
  ('20000000-0000-0000-0000-000000000002', 'Club Demo', 'DEMO', '#B3261E', '#FFFFFF', true),
  ('20000000-0000-0000-0000-000000000003', 'Club Antiguo', 'ANTIGUO', '#555555', '#FFFFFF', false)
on conflict (id) do nothing;

insert into public.club_memberships (user_id, club_id, role, member_number, status) values
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'club_admin', 1, 'active'),
  ('10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'member', 2, 'active'),
  ('10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001', 'member', 3, 'active'),
  ('10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 'member', 1, 'active'),
  ('10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 'member', 1, 'active')
on conflict (user_id, club_id) do nothing;

-- Platform administrator (VS-003): no club membership of their own.
insert into public.platform_admins (user_id)
values ('10000000-0000-0000-0000-000000000099')
on conflict do nothing;
