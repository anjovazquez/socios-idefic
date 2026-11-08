begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users (id, email, aud, role) values
  ('bc000000-0000-0000-0000-000000000001', 'admin21@test.com', 'authenticated', 'authenticated'),
  ('bc000000-0000-0000-0000-000000000002', 'marta21@test.com', 'authenticated', 'authenticated'),
  ('bc000000-0000-0000-0000-000000000003', 'otro21@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values ('dc000000-0000-0000-0000-000000000001', 'Veintiuno TEST', 'VEINTIUNOTEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('ac000000-0000-0000-0000-000000000026', 'dc000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, member_number, role) values
  ('ec000000-0000-0000-0000-000000000001', 'bc000000-0000-0000-0000-000000000001', 'dc000000-0000-0000-0000-000000000001', 1, 'club_admin'),
  ('ec000000-0000-0000-0000-000000000002', 'bc000000-0000-0000-0000-000000000002', 'dc000000-0000-0000-0000-000000000001', 2, 'member');
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.season_memberships (id, club_membership_id, season_id, fee_cents, status) values
  ('fc000000-0000-0000-0000-000000000002', 'ec000000-0000-0000-0000-000000000002', 'ac000000-0000-0000-0000-000000000026', 5000, 'pending_payment');

set local role authenticated;
set local request.jwt.claims = '{"sub":"bc000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select * from public.prepare_online_payment('fc000000-0000-0000-0000-000000000002')$$,
  'P0001', null, 'no online payment while the club has no active Stripe account'
);
select is(
  (select online_payments from public.get_my_subscription('dc000000-0000-0000-0000-000000000001')),
  false, 'the subscription says online payments are off'
);

reset role;
select public.set_club_stripe_account('dc000000-0000-0000-0000-000000000001', 'acct_test_21', true);
set local role authenticated;
set local request.jwt.claims = '{"sub":"bc000000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select stripe_account_id, charges_enabled from public.get_club_online_payments('dc000000-0000-0000-0000-000000000001')$$,
  $$values ('acct_test_21'::text, true)$$,
  'the admin sees the connected account status'
);
select throws_ok(
  $$select public.set_club_stripe_account('dc000000-0000-0000-0000-000000000001', 'acct_evil', true)$$,
  '42501', null, 'only the server links Stripe accounts'
);

set local request.jwt.claims = '{"sub":"bc000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_club_online_payments('dc000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'members do not see the club Stripe account'
);
select results_eq(
  $$select amount_cents, concept, stripe_account_id, member_email
    from public.prepare_online_payment('fc000000-0000-0000-0000-000000000002')$$,
  $$values (5000, 'Cuota de socio 2026/2027'::text, 'acct_test_21'::text, 'marta21@test.com'::text)$$,
  'Marta opens the payment of her 50 € fee in the club account'
);
select is(
  (select count(*)::int from public.prepare_online_payment('fc000000-0000-0000-0000-000000000002')),
  1, 'reopening the checkout'
);
reset role;
select is(
  (select count(*)::int from public.payments where season_membership_id = 'fc000000-0000-0000-0000-000000000002'),
  1, 'reuses the pending Stripe payment'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"bc000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select * from public.prepare_online_payment('fc000000-0000-0000-0000-000000000002')$$,
  '42501', null, 'nobody else can open Marta''s payment'
);
select throws_ok(
  $$select public.apply_payment_event('evt_x', 'checkout.session.completed', gen_random_uuid(), 'paid')$$,
  '42501', null, 'users cannot apply provider events'
);

-- Webhook (service role).
reset role;
create temporary table t_payment as
  select id from public.payments where season_membership_id = 'fc000000-0000-0000-0000-000000000002';
select public.attach_checkout_session((select id from t_payment), 'cs_test_1');

-- Declined card: failed, and Marta can retry with a new payment.
select is(
  public.apply_payment_event('evt_fail', 'payment_intent.payment_failed', (select id from t_payment), 'failed'),
  'applied', 'a declined card marks the payment failed'
);
select is(
  (select status from public.season_memberships where id = 'fc000000-0000-0000-0000-000000000002'),
  'pending_payment', 'the fee is still pending after a failure'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"bc000000-0000-0000-0000-000000000002","role":"authenticated"}';
create temporary table t_retry as
  select payment_id from public.prepare_online_payment('fc000000-0000-0000-0000-000000000002');
reset role;
select isnt(
  (select payment_id from t_retry), (select id from t_payment), 'the retry opens a new payment'
);

select is(
  public.apply_payment_event('evt_ok', 'checkout.session.completed', (select payment_id from t_retry), 'paid', 'card', 'pi_1'),
  'applied', 'a valid card payment is applied'
);
select results_eq(
  $$select p.status, p.method, sm.status, p.receipt_number is not null
    from public.payments p join public.season_memberships sm on sm.id = p.season_membership_id
    where p.id = (select payment_id from t_retry)$$,
  $$values ('paid'::text, 'card'::text, 'active'::text, true)$$,
  'paid after the webhook, Marta is an active member and has a receipt'
);
select is(
  public.apply_payment_event('evt_ok', 'checkout.session.completed', (select payment_id from t_retry), 'paid', 'card', 'pi_1'),
  'duplicate', 'a repeated event is not processed twice'
);

select is(
  public.apply_payment_event('evt_late_fail', 'payment_intent.payment_failed', (select payment_id from t_retry), 'failed'),
  'ignored', 'a late failure never undoes a paid payment'
);
-- The first (failed) attempt succeeds later in the same Checkout.
select is(
  public.apply_payment_event('evt_first_ok', 'checkout.session.completed', (select id from t_payment), 'paid', 'card'),
  'applied', 'a failed attempt can still be paid in the same Checkout'
);
select throws_ok(
  $$select public.apply_payment_event('evt_bad', 'x', (select id from t_payment), 'bogus')$$,
  '22023', null, 'unknown statuses are rejected'
);

select * from finish();
rollback;
