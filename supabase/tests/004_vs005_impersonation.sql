begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('a5000000-0000-0000-0000-000000000001', 'root5@test.com', 'authenticated', 'authenticated'),
  ('a5000000-0000-0000-0000-000000000002', 'admin5@test.com', 'authenticated', 'authenticated');
insert into public.platform_admins (user_id) values ('a5000000-0000-0000-0000-000000000001');
insert into public.clubs (id, name, code) values
  ('c5000000-0000-0000-0000-000000000001', 'Uno TEST', 'UNO5TEST'),
  ('c5000000-0000-0000-0000-000000000002', 'Dos TEST', 'DOS5TEST');
insert into public.club_memberships (user_id, club_id, role, member_number) values
  ('a5000000-0000-0000-0000-000000000002', 'c5000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('a5000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000002', 'club_admin', 1);

set local role authenticated;

-- Root administers club Uno (not their club) and their own club Dos.
set local request.jwt.claims = '{"sub":"a5000000-0000-0000-0000-000000000001","role":"authenticated"}';
select ok(public.can_admin_club('c5000000-0000-0000-0000-000000000001'), 'platform admin can administer any club');
select lives_ok(
  $$select public.update_club_branding('c5000000-0000-0000-0000-000000000001', 'Uno', '#123456', null, null, null)$$,
  'platform admin changes the configuration of a club'
);
select lives_ok(
  $$select public.update_club_branding('c5000000-0000-0000-0000-000000000002', 'Dos', '#123456', null, null, null)$$,
  'platform admin changes their own club'
);
select results_eq(
  $$select actor_email, as_platform_admin from public.get_audit_log('c5000000-0000-0000-0000-000000000001')$$,
  $$values ('root5@test.com'::text, true)$$,
  'acting on another club is recorded as the platform admin, as platform'
);
select results_eq(
  $$select as_platform_admin from public.get_audit_log('c5000000-0000-0000-0000-000000000002')$$,
  array[false],
  'acting on a club they administer is not flagged as platform'
);
select is(
  (select count(*)::int from public.get_audit_log(null, null, 1)),
  1,
  'the audit log is paginated'
);

-- Club admin
set local request.jwt.claims = '{"sub":"a5000000-0000-0000-0000-000000000002","role":"authenticated"}';
select ok(not public.can_admin_club('c5000000-0000-0000-0000-000000000002'), 'club admin cannot administer another club');
select throws_ok(
  $$select public.update_club_branding('c5000000-0000-0000-0000-000000000002', 'Hack', '#000000', null, null, null)$$,
  '42501', null, 'club admin cannot act on another club'
);
select throws_ok(
  $$select * from public.get_audit_log()$$,
  '42501', null, 'club admins cannot read the platform audit log'
);

select * from finish();
rollback;
