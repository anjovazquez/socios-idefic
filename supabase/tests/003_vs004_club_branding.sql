begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email, aud, role) values
  ('e0000000-0000-0000-0000-000000000001', 'root4@test.com', 'authenticated', 'authenticated'),
  ('e0000000-0000-0000-0000-000000000002', 'admin4@test.com', 'authenticated', 'authenticated'),
  ('e0000000-0000-0000-0000-000000000003', 'socio4@test.com', 'authenticated', 'authenticated');
insert into public.platform_admins (user_id) values ('e0000000-0000-0000-0000-000000000001');
insert into public.clubs (id, name, code) values
  ('f0000000-0000-0000-0000-000000000001', 'Marca TEST', 'MARCATEST'),
  ('f0000000-0000-0000-0000-000000000002', 'Ajeno TEST', 'AJENOTEST');
insert into public.club_memberships (user_id, club_id, role, member_number) values
  ('e0000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('e0000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000001', 'member', 2);

set local role authenticated;

-- Club admin
set local request.jwt.claims = '{"sub":"e0000000-0000-0000-0000-000000000002","role":"authenticated"}';
select ok(public.can_admin_club('f0000000-0000-0000-0000-000000000001'), 'club admin can admin their club');
select ok(not public.can_admin_club('f0000000-0000-0000-0000-000000000002'), 'club admin cannot admin another club');
select lives_ok(
  $$select public.update_club_branding('f0000000-0000-0000-0000-000000000001', 'Marca Nueva', '#0b3d91', '#f2a900',
    'f0000000-0000-0000-0000-000000000001/logo.png', null)$$,
  'club admin updates the branding'
);
select results_eq(
  $$select name, primary_color, secondary_color, logo_path from public.get_my_clubs() where code = 'MARCATEST'$$,
  $$values ('Marca Nueva'::text, '#0B3D91'::text, '#F2A900'::text, 'f0000000-0000-0000-0000-000000000001/logo.png'::text)$$,
  'members see the new identity'
);
select throws_ok(
  $$select public.update_club_branding('f0000000-0000-0000-0000-000000000002', 'X', '#000000', null, null, null)$$,
  '42501', null, 'club admin cannot brand another club'
);
select throws_ok(
  $$select public.update_club_branding('f0000000-0000-0000-0000-000000000001', 'X', 'blue', null, null, null)$$,
  '22023', null, 'invalid colors are rejected'
);
select throws_ok(
  $$select public.update_club_branding('f0000000-0000-0000-0000-000000000001', 'X', '#000000', null,
    'f0000000-0000-0000-0000-000000000002/logo.png', null)$$,
  '22023', null, 'assets must live in the club folder'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner) values
    ('club-assets', 'f0000000-0000-0000-0000-000000000001/logo.png', 'e0000000-0000-0000-0000-000000000002')$$,
  'club admin uploads into their club folder'
);
select isnt_empty(
  $$select 1 from storage.objects where bucket_id = 'club-assets'$$,
  'club admins can read bucket rows (storage upsert needs SELECT)'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('club-assets', 'f0000000-0000-0000-0000-000000000002/logo.png')$$,
  '42501', null, 'club admin cannot upload into another club folder'
);

-- Member
set local request.jwt.claims = '{"sub":"e0000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select public.update_club_branding('f0000000-0000-0000-0000-000000000001', 'Hack', '#000000', null, null, null)$$,
  '42501', null, 'members cannot change the branding'
);

-- Platform admin
set local request.jwt.claims = '{"sub":"e0000000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.update_club_branding('f0000000-0000-0000-0000-000000000002', 'Ajeno', '#123456', null, null, null)$$,
  'platform admin can brand any club'
);

reset role;
select is(
  (select count(*)::int from public.audit_log where action = 'club_branding_updated'
   and club_id in ('f0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002')),
  2,
  'branding changes are audited'
);

select * from finish();
rollback;
