begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email, aud, role) values
  ('ba000000-0000-0000-0000-000000000001', 'ana19@test.com', 'authenticated', 'authenticated'),
  ('ba000000-0000-0000-0000-000000000002', 'admin19@test.com', 'authenticated', 'authenticated'),
  ('ba000000-0000-0000-0000-000000000003', 'otro19@test.com', 'authenticated', 'authenticated');
update public.profiles set first_name = 'Ana', last_name = 'Pérez'
where id = 'ba000000-0000-0000-0000-000000000001';
insert into public.clubs (id, name, code) values ('da000000-0000-0000-0000-000000000001', 'Diecinueve TEST', 'DIECINUEVETEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('aa000000-0000-0000-0000-000000000026', 'da000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, member_number, role) values
  ('ea000000-0000-0000-0000-000000000001', 'ba000000-0000-0000-0000-000000000001', 'da000000-0000-0000-0000-000000000001', 7, 'member'),
  ('ea000000-0000-0000-0000-000000000002', 'ba000000-0000-0000-0000-000000000002', 'da000000-0000-0000-0000-000000000001', 1, 'club_admin');
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.season_memberships (id, club_membership_id, season_id, fee_cents, status) values
  ('fa000000-0000-0000-0000-000000000001', 'ea000000-0000-0000-0000-000000000001', 'aa000000-0000-0000-0000-000000000026', 5000, 'pending_payment'),
  ('fa000000-0000-0000-0000-000000000002', 'ea000000-0000-0000-0000-000000000002', 'aa000000-0000-0000-0000-000000000026', 5000, 'pending_payment');
insert into public.payments (id, season_membership_id, amount_cents, concept, status, provider, method, paid_at) values
  ('ca000000-0000-0000-0000-000000000001', 'fa000000-0000-0000-0000-000000000001', 5000, 'Cuota de socio 2026/2027', 'paid', 'manual', 'bizum', '2026-09-10'),
  ('ca000000-0000-0000-0000-000000000003', 'fa000000-0000-0000-0000-000000000002', 5000, 'Cuota de socio 2026/2027', 'pending', 'stripe', null, null);

select is(
  (select receipt_number from public.payments where id = 'ca000000-0000-0000-0000-000000000001'),
  1, 'the first paid payment of the club gets receipt 1'
);
select is(
  (select receipt_number from public.payments where id = 'ca000000-0000-0000-0000-000000000003'),
  null, 'pending payments have no receipt'
);
update public.payments set status = 'paid', method = 'card', paid_at = '2026-09-11'
where id = 'ca000000-0000-0000-0000-000000000003';
select is(
  (select receipt_number from public.payments where id = 'ca000000-0000-0000-0000-000000000003'),
  2, 'receipts are correlative per club when payments become paid'
);

-- The club and the member change after the payment.
update public.clubs set name = 'Nombre Nuevo' where id = 'da000000-0000-0000-0000-000000000001';
update public.profiles set last_name = 'Cambiado' where id = 'ba000000-0000-0000-0000-000000000001';
update public.payments set updated_at = now() where id = 'ca000000-0000-0000-0000-000000000001';

set local role authenticated;
set local request.jwt.claims = '{"sub":"ba000000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select receipt_number, club_name, club_code, member_first_name, member_last_name,
           member_number, season_name, concept, amount_cents, method
    from public.get_receipt('ca000000-0000-0000-0000-000000000001')$$,
  $$values (1, 'Diecinueve TEST'::text, 'DIECINUEVETEST'::text, 'Ana'::text, 'Pérez'::text,
            7, '2026/2027'::text, 'Cuota de socio 2026/2027'::text, 5000, 'bizum'::text)$$,
  'the owner gets her receipt with the data at payment time'
);
select is(
  (select payment_id from public.get_receipt('ca000000-0000-0000-0000-000000000001')),
  'ca000000-0000-0000-0000-000000000001'::uuid, 'the receipt identifies the payment'
);
select results_eq(
  $$select receipt_number from public.get_my_payments('da000000-0000-0000-0000-000000000001')$$,
  $$values (1)$$,
  'her history tells which payments have a receipt'
);
select throws_ok(
  $$select * from public.get_receipt('ca000000-0000-0000-0000-000000000003')$$,
  '42501', null, 'members cannot get other members'' receipts'
);

set local request.jwt.claims = '{"sub":"ba000000-0000-0000-0000-000000000002","role":"authenticated"}';
select is(
  (select receipt_number from public.get_receipt('ca000000-0000-0000-0000-000000000001')),
  1, 'the club admin gets any receipt of the club'
);

set local request.jwt.claims = '{"sub":"ba000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_receipt('ca000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'strangers get nothing'
);

reset role;
update public.payments set status = 'cancelled' where id = 'ca000000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claims = '{"sub":"ba000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_receipt('ca000000-0000-0000-0000-000000000001')$$,
  'P0001', null, 'a cancelled payment offers no receipt'
);
reset role;
select is(
  (select receipt_number from public.payments where id = 'ca000000-0000-0000-0000-000000000001'),
  1, 'the number is never reused'
);

select * from finish();
rollback;
