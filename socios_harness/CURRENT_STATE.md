# Current State

Snapshot operativo. Se actualiza al final de cada loop.

## Estado general

- Fase actual: **2 — Socios (0.2)**.
- Tarea activa: ninguna.
- Última tarea completada: `VS-006 — Alta de socio e invitación por email` (2026-11-08).
- Siguiente tarea READY: `VS-007 — Activación de cuenta en el primer acceso` (también READY: VS-010, VS-025).
- Bloqueos globales: ninguno.

## Milestones

| Milestone | Estado |
|---|---|
| Bootstrap | DONE |
| 0.1 Acceso multi-club | DONE |
| 0.2 Socios | IN_PROGRESS (VS-006 DONE; VS-007, VS-010 READY) |
| 0.3 Temporadas y cuotas | TODO |
| 0.4 Carnet digital | TODO |
| 0.5 Pagos | TODO |
| 0.6 Pago real y renovación automática | TODO |
| 0.7 Comunidad | READY (VS-025) |
| 0.8 Piloto IDEFIC | TODO |

## Decisiones pendientes del usuario

- ADR-001 aceptado (Stripe). Abierto sin bloquear: confirmar Connect por club y comisión de plataforma (default: Connect, sin comisión) antes de VS-021.
- D-013 aceptado (Resend).
- Credenciales que configurará el usuario: Google OAuth (VS-002), claves test de Stripe (VS-021), `RESEND_API_KEY` (VS-033).
- D-016: nombre comercial / bundle id (provisional `es.idefic.socios_idefic`).

## Infraestructura

- Flutter 3.35.1 (`.fvmrc`); proyecto `socios_idefic`, plataformas web/android/ios.
- Config cliente: `--dart-define=SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` (ver `.env.example`).
- Supabase CLI 2.122 (devDependency npm); signup deshabilitado; Google declarado y desactivado.
- CI: `.github/workflows/ci.yml` con `quality` y `sql-tests` (aún sin ejecución en GitHub: el workflow corre en PR/main).
- Esquema: `profiles`, `clubs`, `club_memberships` + RPC `get_my_clubs` (VS-001). Seed local: `admin@`, `ana@`, `luis@`, `root@example.com` (superadmin) con contraseña `<nombre>-password`.
- Plataforma (VS-003): `platform_admins`, `is_platform_admin()`, `audit_log` + `audit()`, `club_invitations` mínima, RPC `create_club`/`update_club`/`set_club_active`/`assign_club_admin`/`get_platform_clubs`.
- Identidad (VS-004): `can_admin_club()`, `update_club_branding`, `get_club_branding`, bucket público `club-assets`; tema por club en `presentation/theme/club_theme.dart`; `DESIGN.md` creado.
- Suplantación (VS-005): banner `ImpersonationBanner` en el `builder` de `MaterialApp`, `get_audit_log` + pantalla `/platform/audit`.
- Socios (VS-006): `prepare_member_invitation`, `attach_invited_member` (service role), `get_club_members`, `prepare_invitation_resend`; Edge Function `invite-member` (`_shared/mailer.ts`, `_shared/emails.ts`, `_shared/supabase_rest.ts`); pantalla `/club/members`. Secretos en `DEPLOYMENT.md`.
- Sesión cloud: Flutter en `$HOME/flutter/bin`; Docker requiere arrancar `dockerd` en segundo plano (ver `QUALITY_GATES.md`). Para probar Edge Functions arrancar sin excluir `edge-runtime`; emails locales en Mailpit `http://127.0.0.1:54324`. El edge-runtime del sandbox no puede descargar de npm (CA del proxy): las funciones no usan npm.
