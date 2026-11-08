# Current State

Snapshot operativo. Se actualiza al final de cada loop.

## Estado general

- Fase actual: **5 — Pagos (0.5)**.
- Tarea activa: ninguna.
- Última tarea completada: `VS-017 — Pagar la cuota (puerto de pagos + proveedor manual)` (2026-11-09).
- Siguiente tarea READY: `VS-018 — Mi suscripción e histórico de pagos` (también READY: VS-025, VS-027).
- Bloqueos globales: ninguno. VS-033 (staging) BLOCKED a la espera de credenciales del usuario.

## Milestones

| Milestone | Estado |
|---|---|
| Bootstrap | DONE |
| 0.1 Acceso multi-club | DONE |
| 0.2 Socios | DONE |
| 0.3 Temporadas y cuotas | DONE |
| 0.4 Carnet digital | DONE |
| 0.5 Pagos | IN_PROGRESS (VS-017 DONE; VS-018 READY) |
| 0.6 Pago real y renovación automática | TODO |
| 0.7 Comunidad | READY (VS-025, VS-027) |
| 0.8 Piloto IDEFIC | TODO (VS-033 adelantada, BLOCKED por credenciales) |

## Decisiones pendientes del usuario

- ADR-001 aceptado (Stripe). Abierto sin bloquear: confirmar Connect por club y comisión de plataforma (default: Connect, sin comisión) antes de VS-021.
- D-013 aceptado (Resend).
- Credenciales que configurará el usuario: Google OAuth (VS-002), claves test de Stripe (VS-021), `RESEND_API_KEY` (VS-033).
- D-016: nombre comercial / bundle id (provisional `es.idefic.socios_idefic`).

## Infraestructura

- Flutter 3.35.1 (`.fvmrc`); proyecto `socios_idefic`, plataformas web/android/ios.
- Config cliente: `--dart-define=SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` (ver `.env.example`).
- Supabase CLI 2.122 (devDependency npm); signup deshabilitado; Google declarado y desactivado.
- CI/CD: `.github/workflows/ci.yml` con `quality`, `edge-functions`, `sql-tests` y despliegue manual a staging (`deploy-migrations`, `deploy-functions`, `deploy-hosting`). Aún sin ejecutar en GitHub.
- Esquema: `profiles`, `clubs`, `club_memberships` + RPC `get_my_clubs` (VS-001). Seed local: `admin@`, `ana@`, `luis@`, `root@example.com` (superadmin) con contraseña `<nombre>-password`.
- Plataforma (VS-003): `platform_admins`, `is_platform_admin()`, `audit_log` + `audit()`, `club_invitations` mínima, RPC `create_club`/`update_club`/`set_club_active`/`assign_club_admin`/`get_platform_clubs`.
- Identidad (VS-004): `can_admin_club()`, `update_club_branding`, `get_club_branding`, bucket público `club-assets`; tema por club en `presentation/theme/club_theme.dart`; `DESIGN.md` creado.
- Suplantación (VS-005): banner `ImpersonationBanner` en el `builder` de `MaterialApp`, `get_audit_log` + pantalla `/platform/audit`.
- Socios (VS-006): `prepare_member_invitation`, `attach_invited_member` (service role), `get_club_members`, `prepare_invitation_resend`; Edge Function `invite-member` (`_shared/mailer.ts`, `_shared/emails.ts`, `_shared/supabase_rest.ts`); pantalla `/club/members`. Secretos en `DEPLOYMENT.md`.
- Primer acceso (VS-007): `profiles.onboarded_at`, `terms_acceptances`, `current_terms_version()`, `get_my_onboarding_status`, `complete_onboarding`; rutas `/activar` y `/primer-acceso`. El texto de condiciones es PROVISIONAL (revisión legal antes del piloto).
- Mis datos (VS-009): bucket privado `profile-photos`, `can_see_member_photo`, `update_my_profile`; pantalla `/club/me`.
- Temporadas (VS-012): `seasons`, `create_season`, `activate_season`, `get_my_clubs.active_season_name`; pantalla `/club/seasons`; seed IDEFIC 2025/2026 (cerrada, 45 €) y 2026/2027 (activa, 50 €).
- Socio por temporada (VS-013): `season_memberships` (+ `card_token`), trigger `join_active_season`, `set_member_fee`, `set_season_membership_status` (provisional), `get_member_seasons`, `can_see_club_membership`; ficha con temporada actual e histórico.
- Renovación (VS-014): `get_renewal_candidates`, `bulk_renew`, `previous_season_id`; pantalla `/club/seasons/renew?season=…`.
- Carnet (VS-015): `get_my_card` (estado calculado en servidor; token solo si activo), `MembershipCardView`, pantalla `/club/card`.
- Validación QR (VS-016): `validate_card` (service role), Edge Function pública `validate-card`, `regenerate_card_token`; ruta pública `/v/:token`; `qr_flutter` 4.1.0; `PUBLIC_APP_URL` (dart-define) para la URL del QR fuera de la web.
- Pagos (VS-017): `payments` + triggers de transición y sincronía, `record_manual_payment`, `set_payment_status`, instrucciones de pago del club; `PaymentGateway` (manual); `get_my_card` devuelve `season_membership_id` y `fee_cents`.
- Sesión cloud: Flutter en `$HOME/flutter/bin`; Docker requiere arrancar `dockerd` en segundo plano (ver `QUALITY_GATES.md`). Para probar Edge Functions arrancar sin excluir `edge-runtime`; emails locales en Mailpit `http://127.0.0.1:54324`. El edge-runtime del sandbox no puede descargar de npm (CA del proxy): las funciones no usan npm.
