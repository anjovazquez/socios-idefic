# Decisions Log

Resumen de decisiones. Las de impacto fuerte tienen ADR en `adr/`.

| ID | Estado | Decisión |
|---|---|---|
| D-001 | ACCEPTED | Flutter como cliente único (Web + Android/iOS), como en Xogalle. |
| D-002 | ACCEPTED | Supabase/PostgreSQL como backend. |
| D-003 | ACCEPTED | Arquitectura hexagonal. |
| D-004 | ACCEPTED | Vertical slicing + BDD/Gherkin como aceptación. |
| D-005 | ACCEPTED | GetIt (composition root), Provider/ChangeNotifier, go_router. |
| D-006 | ACCEPTED | RLS obligatoria; operaciones críticas en RPC. |
| D-007 | ACCEPTED | Importes en céntimos enteros, EUR. |
| D-008 | ACCEPTED | Usuario global (`auth.users` + `profiles`) y pertenencia por club (`club_memberships`), con número de socio por club. |
| D-009 | ACCEPTED | Socio por temporada en `season_memberships`; el carnet y el QR cuelgan de ella. |
| D-010 | ACCEPTED | Signup público deshabilitado; altas por invitación desde Edge Function `invite-member` (service role solo en servidor). |
| D-011 | ACCEPTED | Pagos detrás de `PaymentGateway`; primero proveedor `manual` (el admin marca pagado) para no bloquear el MVP. |
| D-012 | PROPOSED | Proveedor real de pagos: ver ADR-001 (recomendado Stripe con Connect, tarjeta + SEPA). Bloquea VS-021…VS-024. |
| D-013 | PROPOSED | Proveedor de email transaccional (recomendado Resend) detrás de `Mailer`. Necesario en VS-006 (en local se usa Inbucket/Mailpit de Supabase). |
| D-014 | ACCEPTED | QR = URL `/v/<token>` con token aleatorio de 128 bits por `season_membership`; validación por RPC anónima que devuelve solo datos mínimos (RF-020). |
| D-015 | ACCEPTED | Recibos en PDF generados en cliente (paquete `pdf`) a partir de una RPC que devuelve los datos inmutables del pago. Sin facturas en el MVP. |
| D-016 | PROPOSED | Nombre comercial del producto y bundle id (pendiente de usuario). |

## Cuándo crear un ADR

Si la decisión cambia una dependencia central, límites de contexto,
persistencia o seguridad, introduce una excepción arquitectónica o invalida
una decisión anterior.
