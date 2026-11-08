begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

insert into auth.users (id, email, aud, role) values
  ('b0000000-0000-0000-0000-000000000001', 'root@test.com', 'authenticated', 'authenticated'),
  ('b0000000-0000-0000-0000-000000000002', 'admin@test.com', 'authenticated', 'authenticated'),
  ('b0000000-0000-0000-0000-000000000003', 'socio@test.com', 'authenticated', 'authenticated'),
  ('b0000000-0000-0000-0000-000000000004', 'other@test.com', 'authenticated', 'authenticated');
insert into public.platform_admins (user_id) values ('b0000000-0000-0000-0000-000000000001');

insert into public.clubs (id, name, code) values
  ('d0000000-0000-0000-0000-000000000001', 'Existente TEST', 'EXISTTEST');
insert into public.club_memberships (user_id, club_id, role, member_number) values
  ('b0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('b0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001', 'member', 2);

-- Platform admin
set local role authenticated;
set local request.jwt.claims = '{"sub":"b0000000-0000-0000-0000-000000000001","role":"authenticated"}';

select ok(public.is_platform_admin(), 'root is platform admin');

select lives_ok(
  $$select public.create_club('Club Ourense', ' cou ', 'other@test.com', 'Otro')$$,
  'platform admin creates a club with an existing user as admin'
);
select results_eq(
  $$select is_active, admin_email, pending_admin_email, member_count
    from public.get_platform_clubs() where code = 'COU'$$,
  $$values (true, 'other@test.com'::text, null::text, 1)$$,
  'new club is active, code normalized, admin assigned'
);
select is(
  (select role from public.club_memberships m join public.clubs c on c.id = m.club_id
   where c.code = 'COU' and m.user_id = 'b0000000-0000-0000-0000-000000000004'),
  null,
  'memberships of others stay hidden through RLS even for root'
);

select lives_ok(
  $$select public.create_club('Club Nuevo', 'NUEVO', 'Nadie@Test.com', 'Nadie')$$,
  'unknown admin email becomes a pending invitation'
);
select results_eq(
  $$select admin_email, pending_admin_email from public.get_platform_clubs() where code = 'NUEVO'$$,
  $$values (null::text, 'nadie@test.com'::text)$$,
  'pending admin is listed'
);

select throws_ok(
  $$select public.create_club('Duplicado', 'existtest', 'x@test.com')$$,
  '23505',
  null,
  'duplicate code (case-insensitive) is rejected'
);
select throws_ok(
  $$select public.create_club('  ', 'VACIO', 'x@test.com')$$,
  '22023',
  null,
  'empty name is rejected'
);
select throws_ok(
  $$select public.assign_club_admin('d0000000-0000-0000-0000-000000000001', 'other@test.com')$$,
  'P0001',
  null,
  'a club cannot get a second admin'
);
select throws_ok(
  $$select public.assign_club_admin((select id from public.clubs where code = 'NUEVO'), 'other@test.com')$$,
  'P0001',
  null,
  'a pending admin invitation also counts as the admin'
);

select lives_ok(
  $$select public.set_club_active('d0000000-0000-0000-0000-000000000001', false)$$,
  'platform admin deactivates a club'
);
select results_eq(
  $$select is_active from public.get_platform_clubs() where code = 'EXISTTEST'$$,
  array[false],
  'deactivated club stays visible to the platform admin'
);
select lives_ok(
  $$select public.update_club('d0000000-0000-0000-0000-000000000001', 'Renombrado', 'renom')$$,
  'platform admin edits a club'
);
select is(
  (select count(*)::int from public.audit_log
   where actor_id = 'b0000000-0000-0000-0000-000000000001' and as_platform_admin),
  6,
  'every platform operation is audited as the platform admin'
);
select ok(
  (select count(*) from public.get_my_clubs()) >= 2
  and not exists (select 1 from public.get_my_clubs() where code = 'RENOM'),
  'root sees active clubs in the selector, not deactivated ones'
);

-- Socio of the deactivated club
set local request.jwt.claims = '{"sub":"b0000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is_empty('select 1 from public.get_my_clubs()', 'members no longer see a deactivated club');

-- Club admin cannot manage clubs
set local request.jwt.claims = '{"sub":"b0000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.create_club('Hack', 'HACK', 'admin@test.com')$$,
  '42501', null, 'club admins cannot create clubs'
);
select throws_ok(
  $$select public.set_club_active('d0000000-0000-0000-0000-000000000001', true)$$,
  '42501', null, 'club admins cannot (de)activate clubs'
);

select * from finish();
rollback;
