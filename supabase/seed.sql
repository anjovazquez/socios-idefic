-- Local demo data only. Never applied to staging/production.
-- Passwords are local-only: <name>-password.

create or replace function pg_temp.seed_user(p_id uuid, p_email text, p_password text)
returns void
language plpgsql
as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data,
    raw_user_meta_data, is_super_admin, confirmation_token, email_change,
    email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated',
    'authenticated', p_email, crypt(p_password, gen_salt('bf')), now(), now(),
    now(), '{"provider":"email","providers":["email"]}', '{}', false, '', '',
    '', ''
  )
  on conflict (id) do nothing;

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, created_at, updated_at
  ) values (
    p_id::text, p_id,
    jsonb_build_object('sub', p_id::text, 'email', p_email),
    'email', now(), now()
  )
  on conflict do nothing;
end;
$$;

select pg_temp.seed_user('10000000-0000-0000-0000-000000000001', 'admin@example.com', 'admin-password');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000002', 'ana@example.com', 'ana-password');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000003', 'luis@example.com', 'luis-password');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000099', 'root@example.com', 'root-password');

update public.profiles set first_name = 'Admin', last_name = 'IDEFIC'
where id = '10000000-0000-0000-0000-000000000001';
update public.profiles set first_name = 'Ana', last_name = 'Pérez'
where id = '10000000-0000-0000-0000-000000000002';
update public.profiles set first_name = 'Luis', last_name = 'García'
where id = '10000000-0000-0000-0000-000000000003';

insert into public.clubs (id, name, code, primary_color, secondary_color, is_active) values
  ('20000000-0000-0000-0000-000000000001', 'IDEFIC', 'IDEFIC', '#0B3D91', '#F2A900', true),
  ('20000000-0000-0000-0000-000000000002', 'Club Demo', 'DEMO', '#B3261E', '#FFFFFF', true),
  ('20000000-0000-0000-0000-000000000003', 'Club Antiguo', 'ANTIGUO', '#555555', '#FFFFFF', false)
on conflict (id) do nothing;

insert into public.club_memberships (user_id, club_id, role, member_number, status) values
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'club_admin', 1, 'active'),
  ('10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'member', 2, 'active'),
  ('10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001', 'member', 3, 'active'),
  ('10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 'member', 1, 'active'),
  ('10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 'member', 1, 'active')
on conflict (user_id, club_id) do nothing;

-- Platform administrator (VS-003): no club membership of their own.
insert into public.platform_admins (user_id)
values ('10000000-0000-0000-0000-000000000099')
on conflict do nothing;

-- Demo accounts have already completed their first access (VS-007).
update public.profiles set onboarded_at = now()
where id in (
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000099'
);
insert into public.terms_acceptances (user_id, version)
select id, public.current_terms_version() from public.profiles
where onboarded_at is not null
on conflict do nothing;

-- Seasons (VS-012): IDEFIC with 2025/2026 closed and 2026/2027 active at 50 €.
insert into public.seasons (club_id, name, starts_on, ends_on, default_fee_cents, status, activated_at, closed_at) values
  ('20000000-0000-0000-0000-000000000001', '2025/2026', '2025-09-01', '2026-08-31', 4500, 'closed', now() - interval '1 year', now()),
  ('20000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active', now(), null)
on conflict (club_id, name) do nothing;

-- Members per season (VS-013): the seed memberships were created before the
-- seasons, so their season rows are explicit.
insert into public.season_memberships (club_membership_id, season_id, fee_cents, status)
select m.id, s.id,
       case when p.email = 'admin@example.com' then 0 else s.default_fee_cents end,
       case
         when s.name = '2025/2026' then 'active'
         when p.email in ('admin@example.com', 'ana@example.com') then 'active'
         else 'pending_payment'
       end
from public.club_memberships m
join public.profiles p on p.id = m.user_id
join public.seasons s on s.club_id = m.club_id
where m.club_id = '20000000-0000-0000-0000-000000000001'
on conflict (club_membership_id, season_id) do nothing;

-- Payments (VS-017): how IDEFIC is paid and the payments of the seed
-- members (Luis still owes 2026/2027).
update public.clubs
set payment_instructions = 'Transferencia a ES12 3456 7890 1234 5678 9012 (concepto: tu nombre y nº de socio) o Bizum al 600 000 000.'
where id = '20000000-0000-0000-0000-000000000001';

insert into public.payments (season_membership_id, amount_cents, concept, status, provider, method, paid_at)
select sm.id, sm.fee_cents, 'Cuota de socio ' || s.name, 'paid', 'manual',
       case when s.name = '2025/2026' then 'cash' else 'transfer' end,
       s.starts_on::timestamptz + interval '10 days'
from public.season_memberships sm
join public.seasons s on s.id = sm.season_id
where sm.status = 'active' and sm.fee_cents > 0
  and s.club_id = '20000000-0000-0000-0000-000000000001'
  and not exists (select 1 from public.payments p where p.season_membership_id = sm.id);

-- VS-026: IDEFIC news for the members' home (no images: local seeds only).
insert into public.posts (club_id, title, body, status, published_at, author_id) values
  ('20000000-0000-0000-0000-000000000001', 'Arranca la temporada 2026/2027',
   E'Ya está abierta la nueva temporada. Renueva tu cuota desde Mi suscripción y descarga tu carnet.\n\nGracias por seguir con nosotros un año más.',
   'published', now() - interval '20 days', '10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000001', 'Horarios de entrenamiento',
   E'Los entrenamientos de los equipos de base serán de lunes a jueves de 17:30 a 20:30 en el pabellón municipal.\n\nLos horarios de cada equipo están en el tablón del club.',
   'published', now() - interval '6 days', '10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000001', 'Asamblea de socios',
   E'Te convocamos a la asamblea ordinaria el viernes a las 20:00 en el pabellón.\n\nOrden del día: memoria de la temporada, cuentas y ruegos y preguntas.',
   'published', now() - interval '1 day', '10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000001', 'Cena de Navidad',
   'Estamos cerrando fecha y restaurante.', 'draft', null, '10000000-0000-0000-0000-000000000001');

-- VS-027: IDEFIC sponsors (logos are uploaded from the app).
insert into public.sponsors (club_id, name, website_url) values
  ('20000000-0000-0000-0000-000000000001', 'Restaurante O Porto', 'https://restauranteoporto.example'),
  ('20000000-0000-0000-0000-000000000001', 'Ferretería Galicia', 'https://ferreteriagalicia.example'),
  ('20000000-0000-0000-0000-000000000001', 'Autoescuela Norte', 'https://autoescuelanorte.example');
insert into public.sponsor_seasons (sponsor_id, season_id)
select sp.id, se.id
from public.sponsors sp
join public.seasons se on se.club_id = sp.club_id
where sp.club_id = '20000000-0000-0000-0000-000000000001'
  and ((sp.name in ('Restaurante O Porto', 'Ferretería Galicia') and se.name in ('2025/2026', '2026/2027'))
    or (sp.name = 'Autoescuela Norte' and se.name = '2025/2026'));
