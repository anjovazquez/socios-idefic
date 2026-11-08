begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- Fixtures
insert into auth.users (id, email, aud, role)
values
  ('a0000000-0000-0000-0000-000000000001', 'Ana@Test.com', 'authenticated', 'authenticated'),
  ('a0000000-0000-0000-0000-000000000002', 'luis@test.com', 'authenticated', 'authenticated'),
  ('a0000000-0000-0000-0000-000000000003', 'eva@test.com', 'authenticated', 'authenticated');

insert into public.clubs (id, name, code) values
  ('c0000000-0000-0000-0000-000000000001', 'IDEFIC TEST', 'IDTEST'),
  ('c0000000-0000-0000-0000-000000000002', 'Demo TEST', 'DEMOTEST'),
  ('c0000000-0000-0000-0000-000000000003', 'Cerrado TEST', 'CLOSEDTEST');
update public.clubs set is_active = false where code = 'CLOSEDTEST';

insert into public.club_memberships (user_id, club_id, member_number, status) values
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 1, 'active'),
  ('a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 2, 'active'),
  ('a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 7, 'active'),
  ('a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003', 1, 'active'),
  ('a0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000002', 8, 'inactive');

select is(
  (select email from public.profiles where id = 'a0000000-0000-0000-0000-000000000001'),
  'ana@test.com',
  'a profile is created for each auth user with a lowercase email'
);

-- Ana: one club
set local role authenticated;
set local request.jwt.claims = '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';

select results_eq(
  'select code from public.get_my_clubs()',
  array['IDTEST'],
  'Ana only sees IDEFIC'
);
select is_empty(
  $$select 1 from public.clubs where code = 'DEMOTEST'$$,
  'Ana cannot read a club she does not belong to'
);
select is_empty(
  $$select 1 from public.club_memberships where club_id = 'c0000000-0000-0000-0000-000000000001' and user_id <> 'a0000000-0000-0000-0000-000000000001'$$,
  'Ana cannot read other members of her club yet'
);
select is(
  (select count(*)::int from public.profiles),
  1,
  'Ana only reads her own profile'
);
select throws_ok(
  $$insert into public.clubs (name, code) values ('Hack', 'HACK')$$,
  '42501',
  null,
  'members cannot create clubs'
);
select throws_ok(
  $$update public.club_memberships set role = 'club_admin'$$,
  '42501',
  null,
  'members cannot change their membership'
);

-- Luis: two active clubs + one inactive club
set local request.jwt.claims = '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  'select code from public.get_my_clubs() order by code',
  array['DEMOTEST', 'IDTEST'],
  'Luis sees both active clubs and not the deactivated one'
);
select results_eq(
  $$select member_number from public.get_my_clubs() where code = 'DEMOTEST'$$,
  array[7],
  'member number belongs to the club membership'
);

-- Eva: membership not active
set local request.jwt.claims = '{"sub":"a0000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is_empty('select 1 from public.get_my_clubs()', 'inactive memberships give no club access');

-- Anonymous
reset role;
set local role anon;
select throws_ok('select * from public.clubs', '42501', null, 'anon cannot read clubs');
select throws_ok('select * from public.get_my_clubs()', '42501', null, 'anon cannot list clubs');

select * from finish();
rollback;
