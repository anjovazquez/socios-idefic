begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email, aud, role) values
  ('b6000000-0000-0000-0000-000000000001', 'ana15@test.com', 'authenticated', 'authenticated'),
  ('b6000000-0000-0000-0000-000000000002', 'luis15@test.com', 'authenticated', 'authenticated'),
  ('b6000000-0000-0000-0000-000000000003', 'eva15@test.com', 'authenticated', 'authenticated'),
  ('b6000000-0000-0000-0000-000000000004', 'otro15@test.com', 'authenticated', 'authenticated');
update public.profiles set first_name = 'Ana', last_name = 'Pérez' where id = 'b6000000-0000-0000-0000-000000000001';
insert into public.clubs (id, name, code, primary_color) values
  ('d6000000-0000-0000-0000-000000000001', 'Quince TEST', 'QUINCETEST', '#0B3D91'),
  ('d6000000-0000-0000-0000-000000000002', 'Sin temporada TEST', 'SINT15TEST', null);
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('a6000000-0000-0000-0000-000000000026', 'd6000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, member_number) values
  ('e6000000-0000-0000-0000-000000000001', 'b6000000-0000-0000-0000-000000000001', 'd6000000-0000-0000-0000-000000000001', 7),
  ('e6000000-0000-0000-0000-000000000002', 'b6000000-0000-0000-0000-000000000002', 'd6000000-0000-0000-0000-000000000001', 8),
  ('e6000000-0000-0000-0000-000000000003', 'b6000000-0000-0000-0000-000000000003', 'd6000000-0000-0000-0000-000000000001', 9),
  ('e6000000-0000-0000-0000-000000000004', 'b6000000-0000-0000-0000-000000000003', 'd6000000-0000-0000-0000-000000000002', 1);
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.season_memberships (club_membership_id, season_id, fee_cents, status) values
  ('e6000000-0000-0000-0000-000000000001', 'a6000000-0000-0000-0000-000000000026', 5000, 'active'),
  ('e6000000-0000-0000-0000-000000000002', 'a6000000-0000-0000-0000-000000000026', 5000, 'pending_payment');

set local role authenticated;

set local request.jwt.claims = '{"sub":"b6000000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select club_name, first_name, member_number, season_name, state, length(card_token) > 20
    from public.get_my_card('d6000000-0000-0000-0000-000000000001')$$,
  $$values ('Quince TEST'::text, 'Ana'::text, 7, '2026/2027'::text, 'active'::text, true)$$,
  'an active member gets her card with the QR token'
);

set local request.jwt.claims = '{"sub":"b6000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select state, card_token from public.get_my_card('d6000000-0000-0000-0000-000000000001')$$,
  $$values ('pending_payment'::text, null::text)$$,
  'pending payment: no active card and no token'
);

set local request.jwt.claims = '{"sub":"b6000000-0000-0000-0000-000000000003","role":"authenticated"}';
select results_eq(
  $$select state, card_token from public.get_my_card('d6000000-0000-0000-0000-000000000001')$$,
  $$values ('not_renewed'::text, null::text)$$,
  'not renewed: not an active member of the season'
);
select results_eq(
  $$select state, season_name from public.get_my_card('d6000000-0000-0000-0000-000000000002')$$,
  $$values ('no_season'::text, null::text)$$,
  'a club without an active season'
);

set local request.jwt.claims = '{"sub":"b6000000-0000-0000-0000-000000000004","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_my_card('d6000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'only members of the club get a card'
);

reset role;
set local role anon;
select throws_ok(
  $$select * from public.get_my_card('d6000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'anonymous users cannot call it'
);
reset role;
select is(
  (select count(distinct card_token)::int from public.season_memberships
   where club_membership_id in ('e6000000-0000-0000-0000-000000000001', 'e6000000-0000-0000-0000-000000000002')),
  2,
  'each season membership has its own token'
);

select * from finish();
rollback;
