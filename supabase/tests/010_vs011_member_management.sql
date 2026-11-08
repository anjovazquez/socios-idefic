begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email, aud, role) values
  ('b2000000-0000-0000-0000-000000000001', 'admin11@test.com', 'authenticated', 'authenticated'),
  ('b2000000-0000-0000-0000-000000000002', 'marta.gomez11@test.com', 'authenticated', 'authenticated'),
  ('b2000000-0000-0000-0000-000000000003', 'pedro11@test.com', 'authenticated', 'authenticated'),
  ('b2000000-0000-0000-0000-000000000004', 'invitada11@test.com', 'authenticated', 'authenticated');
update public.profiles set first_name = 'Marta', last_name = 'Gómez', onboarded_at = now()
where id = 'b2000000-0000-0000-0000-000000000002';
update public.profiles set first_name = 'Pedro', last_name = 'Ruiz', onboarded_at = now()
where id = 'b2000000-0000-0000-0000-000000000003';
insert into public.clubs (id, name, code) values
  ('d2000000-0000-0000-0000-000000000001', 'Once TEST', 'ONCETEST');
insert into public.club_memberships (id, user_id, club_id, role, member_number, status) values
  ('e2000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000001', 'club_admin', 1, 'active'),
  ('e2000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000002', 'd2000000-0000-0000-0000-000000000001', 'member', 15, 'active'),
  ('e2000000-0000-0000-0000-000000000003', 'b2000000-0000-0000-0000-000000000003', 'd2000000-0000-0000-0000-000000000001', 'member', 16, 'active'),
  ('e2000000-0000-0000-0000-000000000004', 'b2000000-0000-0000-0000-000000000004', 'd2000000-0000-0000-0000-000000000001', 'member', 17, 'inactive');

set local role authenticated;
set local request.jwt.claims = '{"sub":"b2000000-0000-0000-0000-000000000001","role":"authenticated"}';

select results_eq(
  $$select email from public.get_club_members('d2000000-0000-0000-0000-000000000001', 'MARTA')$$,
  array['marta.gomez11@test.com'],
  'search by name (case insensitive)'
);
select results_eq(
  $$select email from public.get_club_members('d2000000-0000-0000-0000-000000000001', 'pedro11@')$$,
  array['pedro11@test.com'],
  'search by email'
);
select results_eq(
  $$select email from public.get_club_members('d2000000-0000-0000-0000-000000000001', '15')$$,
  array['marta.gomez11@test.com'],
  'search by member number'
);
select results_eq(
  $$select email from public.get_club_members('d2000000-0000-0000-0000-000000000001', null, 'inactive')$$,
  array['invitada11@test.com'],
  'filter by status'
);
select results_eq(
  $$select count(*)::int, max(total_count)::int
    from public.get_club_members('d2000000-0000-0000-0000-000000000001', null, null, 2, 0)$$,
  $$values (2, 4)$$,
  'paginated with the total count'
);

select lives_ok(
  $$select public.deactivate_membership('e2000000-0000-0000-0000-000000000002')$$,
  'the admin deactivates Marta'
);
select throws_ok(
  $$select public.deactivate_membership('e2000000-0000-0000-0000-000000000001')$$,
  'P0001', null, 'the club admin cannot be deactivated'
);

set local request.jwt.claims = '{"sub":"b2000000-0000-0000-0000-000000000002","role":"authenticated"}';
select is_empty('select 1 from public.get_my_clubs()', 'Marta no longer reaches the club');
select throws_ok(
  $$select public.reactivate_membership('e2000000-0000-0000-0000-000000000002')$$,
  '42501', null, 'members cannot reactivate themselves'
);

set local request.jwt.claims = '{"sub":"b2000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(
  public.reactivate_membership('e2000000-0000-0000-0000-000000000002'),
  'active',
  'the admin reactivates Marta'
);
select results_eq(
  $$select member_number, status from public.get_club_members('d2000000-0000-0000-0000-000000000001', 'marta')$$,
  $$values (15, 'active'::text)$$,
  'she keeps her number'
);
select is(
  public.reactivate_membership('e2000000-0000-0000-0000-000000000004'),
  'invited',
  'someone who never activated comes back as invited'
);

set local request.jwt.claims = '{"sub":"b2000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq('select code from public.get_my_clubs()', array['ONCETEST'], 'Marta sees the club again');

reset role;
select is(
  (select count(*)::int from public.audit_log
   where action in ('member_deactivated', 'member_reactivated')
     and club_id = 'd2000000-0000-0000-0000-000000000001'),
  3,
  'leaving and coming back are audited'
);

select * from finish();
rollback;
