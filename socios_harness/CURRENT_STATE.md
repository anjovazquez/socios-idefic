# Current State

Snapshot operativo. Se actualiza al final de cada loop.

## Estado general

- Fase actual: **0 — Bootstrap**.
- Tarea activa: ninguna.
- Última tarea completada: ninguna (harness creado el 2026-11-08 a partir de `docs/Propuesta_Idefic_App.docx`).
- Siguiente tarea READY: `BOOTSTRAP-000`.
- Bloqueos globales: ninguno.

## Milestones

| Milestone | Estado |
|---|---|
| Bootstrap | READY |
| 0.1 Acceso multi-club | TODO |
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
- D-016: nombre comercial / bundle id.

## Infraestructura

- Flutter: no inicializado.
- Supabase local: no inicializado.
- CI: no existe.
