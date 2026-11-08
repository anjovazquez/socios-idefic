begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role, raw_user_meta_data) values
  ('a7000000-0000-0000-0000-000000000001', 'marta7@test.com', 'authenticated', 'authenticated', '{"first_name":"Marta"}'),
  ('a7000000-0000-0000-0000-000000000002', 'google7@test.com', 'authenticated', 'authenticated', '{}');
insert into auth.identities (provider_id, user_id, identity_data, provider) values
  ('g-123', 'a7000000-0000-0000-0000-000000000002', '{"sub":"g-123"}', 'google');
insert into public.clubs (id, name, code) values
  ('c7000000-0000-0000-0000-000000000001', 'Siete TEST', 'SIETETEST');
insert into public.club_memberships (user_id, club_id, member_number, status) values
  ('a7000000-0000-0000-0000-000000000001', 'c7000000-0000-0000-0000-000000000001', 1, 'invited');
insert into public.club_invitations (club_id, email, first_name, user_id) values
  ('c7000000-0000-0000-0000-000000000001', 'marta7@test.com', 'Marta', 'a7000000-0000-0000-0000-000000000001');

set local role authenticated;
set local request.jwt.claims = '{"sub":"a7000000-0000-0000-0000-000000000001","role":"authenticated"}';

select results_eq(
  $$select completed, needs_password, first_name from public.get_my_onboarding_status()$$,
  $$values (false, true, 'Marta'::text)$$,
  'an invited member must complete the first access, with password'
);
select is_empty('select 1 from public.get_my_clubs()', 'before activating, no club is reachable');
select throws_ok(
  $$select public.complete_onboarding('Marta', 'Gómez', null, null, 'old-version')$$,
  'P0001', null, 'the conditions of the current version must be accepted'
);
select throws_ok(
  $$select public.complete_onboarding('Marta', ' ', null, null, public.current_terms_version())$$,
  '22023', null, 'last name is required'
);
select throws_ok(
  $$select public.complete_onboarding('Marta', 'Gómez', '12', null, public.current_terms_version())$$,
  '22023', null, 'phone must be valid'
);
select throws_ok(
  $$select public.complete_onboarding('Marta', 'Gómez', null, current_date + 1, public.current_terms_version())$$,
  '22023', null, 'birth date cannot be in the future'
);
select lives_ok(
  $$select public.complete_onboarding(' Marta ', 'Gómez', '600 11 22 33', '1990-05-01', public.current_terms_version())$$,
  'the member completes the first access'
);
select results_eq(
  $$select completed, needs_password, first_name, last_name, phone from public.get_my_onboarding_status()$$,
  $$values (true, false, 'Marta'::text, 'Gómez'::text, '600112233'::text)$$,
  'profile saved and onboarding completed'
);
select results_eq(
  'select code from public.get_my_clubs()',
  array['SIETETEST'],
  'the membership is now active'
);
select is(
  (select count(*)::int from public.terms_acceptances),
  1,
  'the acceptance of the conditions is recorded'
);
reset role;
select ok(
  (select accepted_at is not null from public.club_invitations where email = 'marta7@test.com'),
  'the invitation is accepted'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"a7000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select completed, needs_password from public.get_my_onboarding_status()$$,
  $$values (false, false)$$,
  'Google users skip the password step'
);

select * from finish();
rollback;
