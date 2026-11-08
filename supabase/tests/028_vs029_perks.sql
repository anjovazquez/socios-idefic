begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role) values
  ('b0290000-0000-0000-0000-000000000001', 'admin29@test.com', 'authenticated', 'authenticated'),
  ('b0290000-0000-0000-0000-000000000002', 'ana29@test.com', 'authenticated', 'authenticated'),
  ('b0290000-0000-0000-0000-000000000003', 'demo29@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d0290000-0000-0000-0000-000000000001', 'Veintinueve TEST', 'VEINTINUEVETEST'),
  ('d0290000-0000-0000-0000-000000000002', 'Demo29 TEST', 'DEMO29TEST');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (user_id, club_id, member_number, role) values
  ('b0290000-0000-0000-0000-000000000001', 'd0290000-0000-0000-0000-000000000001', 1, 'club_admin'),
  ('b0290000-0000-0000-0000-000000000002', 'd0290000-0000-0000-0000-000000000001', 2, 'member'),
  ('b0290000-0000-0000-0000-000000000003', 'd0290000-0000-0000-0000-000000000002', 1, 'member');
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.sponsors (id, club_id, name) values
  ('50290000-0000-0000-0000-000000000001', 'd0290000-0000-0000-0000-000000000001', 'Restaurante X'),
  ('50290000-0000-0000-0000-000000000002', 'd0290000-0000-0000-0000-000000000002', 'Patrocinador Demo');

set local role authenticated;
set local request.jwt.claims = '{"sub":"b0290000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.save_perk(null, 'd0290000-0000-0000-0000-000000000001', '50290000-0000-0000-0000-000000000001',
      '10 % de descuento en Restaurante X', 'Presentando tu carnet de socio obtendrás un 10 % de descuento.',
      null, null, null, true)$$,
  'the admin publishes a sponsor perk'
);
select lives_ok(
  $$select public.save_perk(null, 'd0290000-0000-0000-0000-000000000001', null, 'Borrador de ventaja', 'x',
      null, null, null, false)$$,
  'and saves a draft'
);
select lives_ok(
  $$select public.save_perk(null, 'd0290000-0000-0000-0000-000000000001', null, 'Caducada', 'x',
      null, '2020-01-01', '2020-12-31', true)$$,
  'and an expired one'
);
select lives_ok(
  $$select public.save_perk(null, 'd0290000-0000-0000-0000-000000000001', null, 'Próximamente', 'x',
      null, public.madrid_today() + 5, null, true)$$,
  'and a future one'
);
select throws_ok(
  $$select public.save_perk(null, 'd0290000-0000-0000-0000-000000000001', '50290000-0000-0000-0000-000000000002',
      'Robada', 'x', null, null, null, true)$$,
  '22023', null, 'a sponsor of another club is rejected'
);
select throws_ok(
  $$select public.save_perk(null, 'd0290000-0000-0000-0000-000000000001', null, 'Fechas', 'x', null,
      '2026-12-31', '2026-01-01', true)$$,
  '22023', null, 'the end cannot be before the start'
);
select results_eq(
  $$select title, sponsor_name, status from public.get_club_perks('d0290000-0000-0000-0000-000000000001')
    where sponsor_name is not null$$,
  $$values ('10 % de descuento en Restaurante X'::text, 'Restaurante X'::text, 'published'::text)$$,
  'the admin sees it published and linked to the sponsor'
);
select is((select count(*)::int from public.perks), 4, 'the admin reads every perk of the club');

set local request.jwt.claims = '{"sub":"b0290000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select title from public.perks$$,
  $$values ('10 % de descuento en Restaurante X'::text)$$,
  'IDEFIC members only see published perks within their validity'
);
select throws_ok(
  $$select public.save_perk(null, 'd0290000-0000-0000-0000-000000000001', null, 'Socio', 'x', null, null, null, true)$$,
  '42501', null, 'members cannot publish perks'
);

set local request.jwt.claims = '{"sub":"b0290000-0000-0000-0000-000000000003","role":"authenticated"}';
select is((select count(*)::int from public.perks), 0, 'members of another club see nothing');

set local request.jwt.claims = '{"sub":"b0290000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.set_perk_status((select id from public.perks where title like '10 %%'), 'archived')$$,
  'the admin archives it'
);

select * from finish();
rollback;
