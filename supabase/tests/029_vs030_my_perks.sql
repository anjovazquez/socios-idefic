begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (id, email, aud, role) values
  ('b0300000-0000-0000-0000-000000000002', 'ana30@test.com', 'authenticated', 'authenticated'),
  ('b0300000-0000-0000-0000-000000000003', 'otro30@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d0300000-0000-0000-0000-000000000001', 'Treinta TEST', 'TREINTATEST'),
  ('d0300000-0000-0000-0000-000000000002', 'Otro30 TEST', 'OTRO30TEST');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (user_id, club_id, member_number) values
  ('b0300000-0000-0000-0000-000000000002', 'd0300000-0000-0000-0000-000000000001', 2),
  ('b0300000-0000-0000-0000-000000000003', 'd0300000-0000-0000-0000-000000000002', 1);
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.sponsors (id, club_id, name, website_url, is_active) values
  ('50300000-0000-0000-0000-000000000001', 'd0300000-0000-0000-0000-000000000001', 'Restaurante X', 'https://restaurantex.es', true),
  ('50300000-0000-0000-0000-000000000002', 'd0300000-0000-0000-0000-000000000001', 'Retirado', null, false);
insert into public.perks (club_id, sponsor_id, title, body, status, valid_from, valid_until) values
  ('d0300000-0000-0000-0000-000000000001', '50300000-0000-0000-0000-000000000001', 'Vigente', 'x', 'published', null, public.madrid_today()),
  ('d0300000-0000-0000-0000-000000000001', null, 'Caducada', 'x', 'published', null, public.madrid_today() - 1),
  ('d0300000-0000-0000-0000-000000000001', null, 'Futura', 'x', 'published', public.madrid_today() + 1, null),
  ('d0300000-0000-0000-0000-000000000001', null, 'Borrador', 'x', 'draft', null, null),
  ('d0300000-0000-0000-0000-000000000001', '50300000-0000-0000-0000-000000000002', 'De patrocinador retirado', 'x', 'published', null, null);

set local role authenticated;
set local request.jwt.claims = '{"sub":"b0300000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select title, sponsor_name, sponsor_website_url from public.get_my_perks('d0300000-0000-0000-0000-000000000001')$$,
  $$values ('Vigente'::text, 'Restaurante X'::text, 'https://restaurantex.es'::text),
           ('De patrocinador retirado'::text, null::text, null::text)$$,
  'Ana only sees valid perks (valid today included), with their active sponsor'
);
select is(
  (select count(*)::int from public.get_my_perks('d0300000-0000-0000-0000-000000000001') where title in ('Caducada', 'Futura', 'Borrador')),
  0, 'no expired, future or draft perks'
);
select is((select count(*)::int from public.sponsors), 0, 'the sponsors table stays closed to members');

set local request.jwt.claims = '{"sub":"b0300000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_my_perks('d0300000-0000-0000-0000-000000000001')$$,
  '42501', null, 'members of another club get nothing'
);
reset role;
set local role anon;
select throws_ok(
  $$select * from public.get_my_perks('d0300000-0000-0000-0000-000000000001')$$,
  '42501', null, 'anonymous users get nothing'
);

select * from finish();
rollback;
