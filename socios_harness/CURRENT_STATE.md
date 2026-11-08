# Current State

Snapshot operativo. Se actualiza al final de cada loop.

## Estado general

- Fase actual: **1 — Acceso multi-club (0.1)**.
- Tarea activa: ninguna.
- Última tarea completada: `BOOTSTRAP-000` (2026-11-08).
- Siguiente tarea READY: `VS-001 — Login email/contraseña y selector de club`.
- Bloqueos globales: ninguno.

## Milestones

| Milestone | Estado |
|---|---|
| Bootstrap | DONE |
| 0.1 Acceso multi-club | READY (VS-001) |
| 0.2 Socios | TODO |
| 0.3 Temporadas y cuotas | TODO |
| 0.4 Carnet digital | TODO |
| 0.5 Pagos | TODO |
| 0.6 Pago real y renovación automática | TODO (pendiente ADR-001) |
| 0.7 Comunidad | TODO |
| 0.8 Piloto IDEFIC | TODO |

## Decisiones pendientes del usuario

- ADR-001: proveedor de pagos y si cada club cobra en su cuenta (bloquea fase 6).
- D-013: proveedor de email transaccional (necesario antes de staging).
- D-016: nombre comercial / bundle id (provisional `es.idefic.socios_idefic`).

## Infraestructura

- Flutter 3.35.1 (`.fvmrc`); proyecto `socios_idefic`, plataformas web/android/ios.
- Config cliente: `--dart-define=SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` (ver `.env.example`).
- Supabase CLI 2.122 (devDependency npm); signup deshabilitado; Google declarado y desactivado.
- CI: `.github/workflows/ci.yml` con `quality` y `sql-tests` (aún sin ejecución en GitHub: el workflow corre en PR/main).
- Sesión cloud: Flutter en `$HOME/flutter/bin`; Docker requiere arrancar `dockerd` en segundo plano (ver `QUALITY_GATES.md`).
