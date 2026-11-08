begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email, aud, role, last_sign_in_at) values
  ('a6000000-0000-0000-0000-000000000001', 'admin6@test.com', 'authenticated', 'authenticated', now()),
  ('a6000000-0000-0000-0000-000000000002', 'socio6@test.com', 'authenticated', 'authenticated', now()),
  ('a6000000-0000-0000-0000-000000000003', 'otro6@test.com', 'authenticated', 'authenticated', now());
-- "Existing active account" = first access completed (VS-008).
update public.profiles set onboarded_at = now()
where id in ('a6000000-0000-0000-0000-000000000001', 'a6000000-0000-0000-0000-000000000002',
             'a6000000-0000-0000-0000-000000000003');
insert into public.clubs (id, name, code, primary_color) values
  ('c6000000-0000-0000-0000-000000000001', 'Seis TEST', 'SEISTEST', '#0B3D91');
insert into public.club_memberships (user_id, club_id, role, member_number) values
  ('a6000000-0000-0000-0000-000000000001', 'c6000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('a6000000-0000-0000-0000-000000000002', 'c6000000-0000-0000-0000-000000000001', 'member', 2);

set local role authenticated;
set local request.jwt.claims = '{"sub":"a6000000-0000-0000-0000-000000000001","role":"authenticated"}';

select results_eq(
  $$select email, first_name, existing_user_id, club_name
    from public.prepare_member_invitation('c6000000-0000-0000-0000-000000000001', ' Marta@Test.com ', ' Marta ')$$,
  $$values ('marta@test.com'::text, 'Marta'::text, null::uuid, 'Seis TEST'::text)$$,
  'admin prepares an invitation for a new person (email normalized)'
);
select results_eq(
  $$select existing_user_id, existing_user_active
    from public.prepare_member_invitation('c6000000-0000-0000-0000-000000000001', 'otro6@test.com', 'Otro')$$,
  $$values ('a6000000-0000-0000-0000-000000000003'::uuid, true)$$,
  'an existing account is detected (RF-004)'
);
reset role;
select is(
  (select count(*)::int from public.club_invitations
   where club_id = 'c6000000-0000-0000-0000-000000000001' and email = 'marta@test.com'),
  1,
  'one pending invitation per club and email'
);
set local role authenticated;
select lives_ok(
  $$select public.prepare_member_invitation('c6000000-0000-0000-0000-000000000001', 'marta@test.com', 'Marta G.')$$,
  'preparing again reuses the pending invitation'
);
reset role;
select is(
  (select count(*)::int from public.club_invitations
   where club_id = 'c6000000-0000-0000-0000-000000000001' and email = 'marta@test.com'),
  1,
  'still one pending invitation'
);
set local role authenticated;
select throws_ok(
  $$select public.prepare_member_invitation('c6000000-0000-0000-0000-000000000001', 'no-es-email', 'X')$$,
  '22023', null, 'invalid email is rejected'
);
select throws_ok(
  $$select public.prepare_member_invitation('c6000000-0000-0000-0000-000000000001', 'x@test.com', '  ')$$,
  '22023', null, 'name is required'
);
select throws_ok(
  $$select public.prepare_member_invitation('c6000000-0000-0000-0000-000000000001', 'socio6@test.com', 'Socio')$$,
  'P0001', null, 'active members cannot be invited again'
);
select throws_ok(
  $$select public.attach_invited_member(gen_random_uuid(), 'a6000000-0000-0000-0000-000000000003', 'active')$$,
  '42501', null, 'only the server (service role) attaches members'
);

-- Server side: the Edge Function creates the auth user and attaches it.
reset role;
insert into auth.users (id, email, aud, role) values
  ('a6000000-0000-0000-0000-000000000004', 'marta@test.com', 'authenticated', 'authenticated');
select lives_ok(
  $$select public.attach_invited_member(
      (select id from public.club_invitations where email = 'marta@test.com'),
      'a6000000-0000-0000-0000-000000000004', 'invited')$$,
  'service attaches the invited member'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"a6000000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select first_name, member_number, status from public.get_club_members('c6000000-0000-0000-0000-000000000001')
    where email = 'marta@test.com'$$,
  $$values ('Marta G.'::text, 3, 'invited'::text)$$,
  'the admin sees Marta as invited with the next member number'
);
select is(
  (select count(*)::int from public.prepare_invitation_resend(
     (select membership_id from public.get_club_members('c6000000-0000-0000-0000-000000000001') where email = 'marta@test.com'))),
  1,
  'the admin can resend a pending invitation'
);

-- A member cannot invite or list
set local request.jwt.claims = '{"sub":"a6000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.prepare_member_invitation('c6000000-0000-0000-0000-000000000001', 'x@test.com', 'X')$$,
  '42501', null, 'members cannot invite'
);
select throws_ok(
  $$select * from public.get_club_members('c6000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'members cannot list the members'
);

select * from finish();
rollback;
