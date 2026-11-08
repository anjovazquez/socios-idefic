# Current State

Snapshot operativo. Se actualiza al final de cada loop.

## Estado general

- Fase actual: **1 — Acceso multi-club (0.1)**.
- Tarea activa: ninguna.
- Última tarea completada: `VS-001 — Login email/contraseña y selector de club` (2026-11-08).
- Siguiente tarea READY: `VS-002 — Login con Google` (después `VS-003`). VS-002 se implementa y testea con fakes; la prueba OAuth real necesita un client ID de Google (lo configura el usuario).
- Bloqueos globales: ninguno.

## Milestones

| Milestone | Estado |
|---|---|
| Bootstrap | DONE |
| 0.1 Acceso multi-club | IN_PROGRESS (VS-001 DONE; VS-002, VS-003 READY) |
| 0.2 Socios | TODO |
| 0.3 Temporadas y cuotas | TODO |
| 0.4 Carnet digital | TODO |
| 0.5 Pagos | TODO |
| 0.6 Pago real y renovación automática | TODO |
| 0.7 Comunidad | TODO |
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
- Esquema: `profiles`, `clubs`, `club_memberships` + RPC `get_my_clubs` (VS-001). Seed local: `admin@`, `ana@`, `luis@example.com` (contraseña `<nombre>-password`).
- Sesión cloud: Flutter en `$HOME/flutter/bin`; Docker requiere arrancar `dockerd` en segundo plano (ver `QUALITY_GATES.md`).
