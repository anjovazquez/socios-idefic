begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

-- Usuario pertenece a A; B lo da de alta. Admins distintos por club.
insert into auth.users (id, email, aud, role, last_sign_in_at) values
  ('a8000000-0000-0000-0000-000000000001', 'adminA8@test.com', 'authenticated', 'authenticated', now()),
  ('a8000000-0000-0000-0000-000000000002', 'adminB8@test.com', 'authenticated', 'authenticated', now()),
  ('a8000000-0000-0000-0000-000000000003', 'usuario8@test.com', 'authenticated', 'authenticated', now()),
  ('a8000000-0000-0000-0000-000000000004', 'amedias8@test.com', 'authenticated', 'authenticated', now());
update public.profiles set onboarded_at = now(), phone = '600000008'
where id in ('a8000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000002',
             'a8000000-0000-0000-0000-000000000003');
insert into public.terms_acceptances (user_id, version)
values ('a8000000-0000-0000-0000-000000000003', public.current_terms_version());
insert into public.clubs (id, name, code) values
  ('c8000000-0000-0000-0000-00000000000a', 'A TEST', 'A8TEST'),
  ('c8000000-0000-0000-0000-00000000000b', 'B TEST', 'B8TEST');
insert into public.club_memberships (user_id, club_id, role, member_number, status) values
  ('a8000000-0000-0000-0000-000000000001', 'c8000000-0000-0000-0000-00000000000a', 'club_admin', 1, 'active'),
  ('a8000000-0000-0000-0000-000000000002', 'c8000000-0000-0000-0000-00000000000b', 'club_admin', 1, 'active'),
  ('a8000000-0000-0000-0000-000000000003', 'c8000000-0000-0000-0000-00000000000a', 'member', 57, 'active'),
  ('a8000000-0000-0000-0000-000000000004', 'c8000000-0000-0000-0000-00000000000a', 'member', 58, 'invited');

set local role authenticated;
set local request.jwt.claims = '{"sub":"a8000000-0000-0000-0000-000000000002","role":"authenticated"}';

select results_eq(
  $$select existing_user_id, existing_user_active, email
    from public.prepare_member_invitation('c8000000-0000-0000-0000-00000000000b', 'Usuario8@Test.COM', 'Usuario')$$,
  $$values ('a8000000-0000-0000-0000-000000000003'::uuid, true, 'usuario8@test.com'::text)$$,
  'an email with capitals matches the existing account'
);
select results_eq(
  $$select existing_user_active
    from public.prepare_member_invitation('c8000000-0000-0000-0000-00000000000b', 'amedias8@test.com', 'A medias')$$,
  array[false],
  'an account that signed in but never finished the first access is not active'
);

reset role;
select lives_ok(
  $$select public.attach_invited_member(
      (select id from public.club_invitations
       where email = 'usuario8@test.com' and club_id = 'c8000000-0000-0000-0000-00000000000b'),
      'a8000000-0000-0000-0000-000000000003', 'active')$$,
  'the server adds the existing account to club B'
);
select is(
  (select count(*)::int from auth.users where lower(email) = 'usuario8@test.com'),
  1,
  'no second account is created (RN-005)'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"a8000000-0000-0000-0000-000000000003","role":"authenticated"}';
select results_eq(
  'select code, member_number from public.get_my_clubs() order by code',
  $$values ('A8TEST'::text, 57), ('B8TEST'::text, 1 + 1)$$,
  'the user sees both clubs, each with its own member number'
);
select results_eq(
  'select completed from public.get_my_onboarding_status()',
  array[true],
  'no data or conditions are asked again'
);

-- Privacy: admin of B
set local request.jwt.claims = '{"sub":"a8000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select member_number from public.get_club_members('c8000000-0000-0000-0000-00000000000b')
    where email = 'usuario8@test.com'$$,
  array[2],
  'admin of B sees the member number in B'
);
select throws_ok(
  $$select * from public.get_club_members('c8000000-0000-0000-0000-00000000000a')$$,
  '42501', null, 'admin of B cannot list the members of A'
);
select is_empty(
  $$select 1 from public.club_memberships where club_id = 'c8000000-0000-0000-0000-00000000000a'$$,
  'admin of B cannot read memberships (or member numbers) of A'
);
select is_empty(
  $$select 1 from public.profiles where id = 'a8000000-0000-0000-0000-000000000003'$$,
  'admin of B cannot read the profile table directly'
);
select is_empty(
  $$select 1 from public.club_invitations$$,
  'admin of B cannot read invitations of any club directly'
);

select * from finish();
rollback;
