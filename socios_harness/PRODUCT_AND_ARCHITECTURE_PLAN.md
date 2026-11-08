# Socios IDEFIC — Plan de producto y desarrollo por fases

Fuente funcional: `docs/PROPUESTA_FUNCIONAL_MVP.md` (convertido desde
`docs/Propuesta_Idefic_App.docx`). Los identificadores `RF-xxx` y `RN-xxx` de
este plan y de las tareas remiten a ese documento.

## 1. Objetivo

Plataforma **multi-club** (web + app) para clubes de baloncesto amateur que
gestiona socios, temporadas, cuotas, pagos, carnet digital, patrocinadores,
ventajas y comunicaciones privadas. Primer club de validación: **IDEFIC**,
temporada **2026/2027**.

Prioridades de producto (por orden):

1. Que el socio renueve y pague con la mínima fricción.
2. Carnet digital con QR verificable.
3. Renovación entre temporadas casi automática (con aviso y cancelación).
4. Espacio privado club ↔ socios (blog, ventajas, patrocinadores).
5. Gestión centralizada de varios clubes.

## 2. Metodología (heredada de Xogalle)

- Desarrollo por **vertical slices** (`VS-xxx`), cada uno de punta a punta:
  migración + RLS + RPC → adapter → use case → ViewModel → UI → tests.
- **BDD/Gherkin** en cada tarea como criterio de aceptación.
- Un loop autónomo = **un slice**, con `INIT_TASK` → implementar →
  `QUALITY_GATES` → `CLOSE_TASK` → handover.
- Memoria persistente en `socios_harness/` para no depender del chat.

## 3. Arquitectura

Mismo stack que Xogalle (ver `DECISIONS.md`):

```text
Flutter (Web para admin + socio; Android/iOS para socio)
  presentation → application → domain ← infrastructure
Supabase: Auth (email+password, Google), Postgres + RLS, RPC, Storage,
          Edge Functions (invitaciones, emails, pagos, webhooks), pg_cron
```

Puntos específicos de este producto:

| Necesidad | Solución prevista |
|---|---|
| Multi-club, usuario global | `auth.users` + `profiles` global; `club_memberships` (usuario+club, número de socio, rol) |
| Sin registro público | Signup deshabilitado; alta solo por invitación (Edge Function con service role) |
| Superadmin y suplantación | `platform_admins`; `acting_as_club_admin` comprobado en RPC; auditoría con `actor_id` real + `on_behalf_of` |
| Socio por temporada | `seasons` (una activa por club, índice parcial) + `season_memberships` (socio+temporada, cuota en céntimos, estado) |
| Pagos desacoplados | Puerto `PaymentGateway` (app) + Edge Functions por proveedor; primero proveedor **manual/fake**, después el real (ADR-001) |
| Renovación automática | Cron server-side: aviso previo (email) → ventana de cancelación → cobro off-session |
| Recibos | Datos del recibo vía RPC; PDF generado en cliente con el paquete `pdf` |
| QR | Token opaco aleatorio por `season_membership`; ruta pública `/v/<token>` que llama a RPC `validate_card` (anon, solo datos mínimos) |
| Identidad visual | `clubs.primary_color`, `secondary_color`, `logo_path`; `ThemeData` derivado por club activo |
| Emails | Edge Function + proveedor transaccional (por decidir, p. ej. Resend) detrás de un puerto `Mailer` |

## 4. Fases y milestones

| Fase | Milestone | Objetivo | Slices |
|---|---|---|---|
| 0 | Bootstrap | Proyecto Flutter + Supabase local + CI + harness | BOOTSTRAP-000 |
| 1 | 0.1 Acceso multi-club | Entrar, elegir club, ver su identidad | VS-001 … VS-005 |
| 2 | 0.2 Socios | Alta por invitación, activación, perfil, número de socio | VS-006 … VS-011 |
| 3 | 0.3 Temporadas y cuotas | Temporadas, cuota general/personalizada, renovación masiva | VS-012 … VS-014 |
| 4 | 0.4 Carnet digital | Carnet por temporada y QR de validación pública | VS-015 … VS-016 |
| 5 | 0.5 Pagos | Pago de cuota detrás de un puerto, suscripción, histórico, recibos, vista admin | VS-017 … VS-020 |
| 6 | 0.6 Pago real y renovación automática | Proveedor real, método guardado, aviso previo, cancelación, cobro automático | VS-021 … VS-024 |
| 7 | 0.7 Comunidad | Blog privado, patrocinadores por temporada, ventajas | VS-025 … VS-030 |
| 8 | 0.8 Piloto IDEFIC | Dashboard, acabado visual, despliegue staging, piloto real | VS-031 … VS-034 |

Orden de dependencias simplificado:

```text
BOOTSTRAP-000
 └ VS-001 login+selector ─┬ VS-002 Google
                          ├ VS-003 clubes (superadmin) ─ VS-004 identidad visual ─ VS-005 suplantación
                          └ VS-006 alta+invitación ─ VS-007 activación ─ VS-008 usuario existente
                                                      ├ VS-009 mis datos
                                                      └ VS-010 nº socio ─ VS-011 gestión socios
VS-011 ─ VS-012 temporadas ─ VS-013 socio-temporada/cuotas ─ VS-014 renovación masiva
VS-013 ─ VS-015 mi carnet ─ VS-016 QR validación
VS-013 ─ VS-017 pago cuota (puerto + manual) ─ VS-018 mi suscripción ─ VS-019 recibo ─ VS-020 pagos admin
VS-020 + ADR-001 ─ VS-021 proveedor real ─ VS-022 método guardado ─ VS-023 aviso previo ─ VS-024 cancelación/cobro auto
VS-004 ─ VS-025 blog admin ─ VS-026 blog socio
VS-012 ─ VS-027 patrocinadores ─ VS-028 patrocinadores socio ─ VS-029 ventajas ─ VS-030 mis ventajas
Todo ─ VS-031 dashboard ─ VS-032 acabado visual ─ VS-033 CI/CD staging ─ VS-034 piloto IDEFIC
```

Las fases 5 (pago manual) y 7 (comunidad) no dependen de la decisión del
proveedor de pago; la fase 6 sí (ADR-001). Si ADR-001 sigue `PROPOSED` al
llegar a VS-021, el loop salta a la fase 7.

## 5. Fuera del MVP

Ver §22 del documento funcional: registro público, acceso de patrocinadores,
facturación, contabilidad, equipos/jugadores, licencias, tienda, mensajería,
push avanzadas, múltiples administradores por club, web pública, PWA por club.
No se implementan "por si acaso".
