begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, aud, role) values
  ('be000000-0000-0000-0000-000000000001', 'admin23@test.com', 'authenticated', 'authenticated'),
  ('be000000-0000-0000-0000-000000000002', 'marta23@test.com', 'authenticated', 'authenticated'),
  ('be000000-0000-0000-0000-000000000003', 'pablo23@test.com', 'authenticated', 'authenticated');
update public.profiles set first_name = 'Marta' where id = 'be000000-0000-0000-0000-000000000002';
insert into public.clubs (id, name, code, stripe_account_id, stripe_charges_enabled)
values ('de000000-0000-0000-0000-000000000001', 'Veintitres TEST', 'VEINTITRESTEST', 'acct_test_23', true);
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('ae000000-0000-0000-0000-000000000027', 'de000000-0000-0000-0000-000000000001', '2027/2028', '2027-09-01', '2028-08-31', 5000, 'draft');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, member_number, role, auto_renew) values
  ('ee000000-0000-0000-0000-000000000001', 'be000000-0000-0000-0000-000000000001', 'de000000-0000-0000-0000-000000000001', 1, 'club_admin', false),
  ('ee000000-0000-0000-0000-000000000002', 'be000000-0000-0000-0000-000000000002', 'de000000-0000-0000-0000-000000000001', 2, 'member', true),
  ('ee000000-0000-0000-0000-000000000003', 'be000000-0000-0000-0000-000000000003', 'de000000-0000-0000-0000-000000000001', 3, 'member', false);
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.payment_methods (club_membership_id, provider_customer_id, provider_method_id, kind, brand, last4)
values ('ee000000-0000-0000-0000-000000000002', 'cus_m', 'pm_m', 'card', 'visa', '4242');
insert into public.season_memberships (id, club_membership_id, season_id, fee_cents, status) values
  ('fe000000-0000-0000-0000-000000000002', 'ee000000-0000-0000-0000-000000000002', 'ae000000-0000-0000-0000-000000000027', 5000, 'pending_payment'),
  ('fe000000-0000-0000-0000-000000000003', 'ee000000-0000-0000-0000-000000000003', 'ae000000-0000-0000-0000-000000000027', 5000, 'pending_payment');

-- Default: charge on the season start, notice 15 days before.
select is(
  (select count(*)::int from public.get_due_renewal_notices('2027-08-16')),
  0, 'no notice before the notice date'
);
select results_eq(
  $$select email, first_name, season_name, amount_cents, charge_on, method_last4
    from public.get_due_renewal_notices('2027-08-17')$$,
  $$values ('marta23@test.com'::text, 'Marta'::text, '2027/2028'::text, 5000, '2027-09-01'::date, '4242'::text)$$,
  'on 17 August Marta gets the notice: season, amount, charge date and method'
);
select is(
  (select count(*)::int from public.get_due_renewal_notices('2027-08-17') where email = 'pablo23@test.com'),
  0, 'members without automatic renewal get no notice'
);

-- Without notice there is no charge (RN-012).
select is(public.can_charge_renewal('fe000000-0000-0000-0000-000000000002', '2027-09-01'), false,
  'without notice the automatic charge does not run');

select is(public.claim_renewal_notice('fe000000-0000-0000-0000-000000000002', '2027-09-01', 5000, 'marta23@test.com'),
  true, 'the first run claims the notice');
select is(public.claim_renewal_notice('fe000000-0000-0000-0000-000000000002', '2027-09-01', 5000, 'marta23@test.com'),
  false, 'later runs do not send it again');
select is(
  (select count(*)::int from public.get_due_renewal_notices('2027-08-20')),
  0, 'a notified renewal is no longer due (single notice)'
);
select is(public.can_charge_renewal('fe000000-0000-0000-0000-000000000002', '2027-08-31'), false,
  'not before the charge date');
select is(public.can_charge_renewal('fe000000-0000-0000-0000-000000000002', '2027-09-01'), true,
  'notified and on the charge date: it can be charged');

-- A different amount needs a new notice.
update public.season_memberships set fee_cents = 6000 where id = 'fe000000-0000-0000-0000-000000000002';
select is(public.can_charge_renewal('fe000000-0000-0000-0000-000000000002', '2027-09-01'), false,
  'if the amount changes after the notice, it cannot be charged');
update public.season_memberships set fee_cents = 5000 where id = 'fe000000-0000-0000-0000-000000000002';

select public.release_renewal_notice('fe000000-0000-0000-0000-000000000002');
select is(
  (select count(*)::int from public.get_due_renewal_notices('2027-08-20')),
  1, 'a notice that could not be sent is retried'
);

-- Admin settings.
set local role authenticated;
set local request.jwt.claims = '{"sub":"be000000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.set_season_renewal('ae000000-0000-0000-0000-000000000027', '2027-09-15', 10)$$,
  'the admin sets the charge date and notice days'
);
reset role;
select is(
  (select notice_on from public.automatic_renewals where season_membership_id = 'fe000000-0000-0000-0000-000000000002'),
  '2027-09-05'::date, 'the notice moves with the charge date'
);
set local role authenticated;
select throws_ok(
  $$select public.set_season_renewal('ae000000-0000-0000-0000-000000000027', '2027-09-15', 0)$$,
  '22023', null, 'notice days must be between 1 and 60'
);
set local request.jwt.claims = '{"sub":"be000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.set_season_renewal('ae000000-0000-0000-0000-000000000027', '2027-09-15', 10)$$,
  '42501', null, 'members cannot change it'
);
select throws_ok(
  $$select * from public.get_due_renewal_notices()$$,
  '42501', null, 'only the server lists due notices'
);

select * from finish();
rollback;
