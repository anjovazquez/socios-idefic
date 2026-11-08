# Backlog — Vertical Slices

Estados: `TODO` · `READY` · `IN_PROGRESS` · `BLOCKED` · `DONE`.

El agente solo auto-selecciona tareas `READY` cuyas dependencias estén `DONE`,
de arriba abajo. Al cerrar una tarea, promueve a `READY` las `TODO` cuyas
dependencias ya estén todas `DONE` (salvo bloqueo explícito por decisión).

| ID | Slice | Estado | Depende de | Fase / Milestone | RF / RN |
|---|---|---|---|---|---|
| BOOTSTRAP-000 | Bootstrap Flutter + Supabase local + CI | DONE | - | 0 Bootstrap | - |
| VS-001 | Login email/contraseña y selector de club | DONE | BOOTSTRAP-000 | 1 · 0.1 Acceso | RF-001, RF-030, RN-001 |
| VS-002 | Login con Google | DONE | VS-001 | 1 · 0.1 Acceso | RF-001 |
| VS-003 | Superadmin: alta, edición y desactivación de clubes | DONE | VS-001 | 1 · 0.1 Acceso | §3.1, §17 |
| VS-004 | Identidad visual por club + DESIGN.md | DONE | VS-003 | 1 · 0.1 Acceso | §20, RF-030 |
| VS-005 | Suplantación funcional auditada | DONE | VS-003 | 1 · 0.1 Acceso | §17 |
| VS-006 | Alta de socio e invitación por email | DONE | VS-003 | 2 · 0.2 Socios | RF-002, RN-002 |
| VS-007 | Activación de cuenta en el primer acceso | DONE | VS-006 | 2 · 0.2 Socios | RF-003 |
| VS-008 | Alta de un usuario existente en otro club | DONE | VS-007 | 2 · 0.2 Socios | RF-004, RN-003…RN-005 |
| VS-009 | Mis datos (perfil y foto) | DONE | VS-007 | 2 · 0.2 Socios | RF-005 |
| VS-010 | Número de socio por club | DONE | VS-006 | 2 · 0.2 Socios | RF-006, RN-006 |
| VS-011 | Gestión de socios (listado, edición, baja) | DONE | VS-010 | 2 · 0.2 Socios | §16 Socios |
| VS-012 | Temporadas: crear, activar con cuota, histórico | DONE | VS-011 | 3 · 0.3 Temporadas | RF-007, RF-008, RN-009 |
| VS-013 | Socio por temporada y cuota personalizada | READY | VS-012 | 3 · 0.3 Temporadas | RF-010, RN-007, RN-008, RN-010 |
| VS-014 | Renovación masiva | TODO | VS-013 | 3 · 0.3 Temporadas | RF-009, RN-011 |
| VS-015 | Mi carnet digital | TODO | VS-013, VS-004 | 4 · 0.4 Carnet | RF-019, RF-021, RN-014 |
| VS-016 | QR y página pública de validación | TODO | VS-015 | 4 · 0.4 Carnet | RF-020, RN-017 |
| VS-017 | Pagar la cuota (puerto de pagos + proveedor manual) | TODO | VS-013 | 5 · 0.5 Pagos | §9, RF-015 |
| VS-018 | Mi suscripción e histórico de pagos | TODO | VS-017 | 5 · 0.5 Pagos | RF-011, RF-016 |
| VS-019 | Recibo descargable | TODO | VS-018 | 5 · 0.5 Pagos | RF-017 |
| VS-020 | Pagos del club para el admin (filtros y recibos) | TODO | VS-019 | 5 · 0.5 Pagos | RF-018 |
| VS-021 | Proveedor de pago real (checkout + webhook) | TODO | VS-020, ADR-001 | 6 · 0.6 Renovación | §9 |
| VS-022 | Método de pago guardado para renovaciones | TODO | VS-021 | 6 · 0.6 Renovación | RF-012 |
| VS-023 | Aviso previo de renovación | TODO | VS-022, VS-014 | 6 · 0.6 Renovación | RF-013, RN-012 |
| VS-024 | Cancelación y cobro automático de la renovación | TODO | VS-023 | 6 · 0.6 Renovación | RF-014, RN-013 |
| VS-025 | Blog: publicar (admin) | READY | VS-004 | 7 · 0.7 Comunidad | RF-022 |
| VS-026 | Blog: Inicio del socio | TODO | VS-025 | 7 · 0.7 Comunidad | RF-023 |
| VS-027 | Patrocinadores por temporada (admin) | READY | VS-012 | 7 · 0.7 Comunidad | RF-026…RF-028, RN-016 |
| VS-028 | Patrocinadores para el socio | TODO | VS-027 | 7 · 0.7 Comunidad | RF-029 |
| VS-029 | Ventajas (admin) | TODO | VS-027 | 7 · 0.7 Comunidad | RF-024, RN-015 |
| VS-030 | Mis ventajas | TODO | VS-029 | 7 · 0.7 Comunidad | RF-025 |
| VS-031 | Dashboard del club | TODO | VS-020, VS-030 | 8 · 0.8 Piloto | §16 Dashboard |
| VS-032 | Acabado visual y navegación final del socio | TODO | VS-031 | 8 · 0.8 Piloto | §14, §20 |
| VS-033 | CI/CD y entorno staging | BLOCKED | (adelantada por el usuario) | 8 · 0.8 Piloto | - |
| VS-034 | Piloto IDEFIC | TODO | VS-033 | 8 · 0.8 Piloto | §21 |

Notas:

- VS-021…VS-024 usan Stripe (ADR-001 `ACCEPTED`); necesitan claves de test
  de Stripe. Sin ellas se implementan con fakes y la prueba real queda pendiente.
- VS-033 se adelantó a petición del usuario (2026-11-08): pipeline listo, BLOCKED hasta
  que el usuario configure proyectos y secretos (`DEPLOYMENT.md`) y lance el primer despliegue.
- VS-006 usa el buzón local de Supabase (Inbucket/Mailpit) en desarrollo; el
  proveedor real de email (Resend, D-013) solo se configura en VS-033.
