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
| D-012 | ACCEPTED | Proveedor real de pagos: **Stripe** (ADR-001): Connect por club, tarjeta + SEPA, cobros off-session tras aviso previo. |
| D-013 | ACCEPTED | Email transaccional con **Resend** detrás del puerto `Mailer` en Edge Functions (`RESEND_API_KEY` solo como secreto de función). En local se usa Mailpit de Supabase. |
| D-014 | ACCEPTED | QR = URL `/v/<token>` con token aleatorio de 128 bits por `season_membership`; validación por RPC anónima que devuelve solo datos mínimos (RF-020). |
| D-015 | ACCEPTED | Recibos en PDF generados en cliente (paquete `pdf`) a partir de una RPC que devuelve los datos inmutables del pago. Sin facturas en el MVP. |
| D-017 | ACCEPTED | Logos e imágenes de club en el bucket **público** `club-assets/<club_id>/` (PNG/JPG/WebP ≤ 2 MB): son marca y aparecen en la validación pública del QR y en emails. Escritura solo `can_admin_club`; lectura de filas para autenticados (el upsert de Storage la necesita). Las fotos de socios irán en un bucket privado (VS-009). |
| D-018 | ACCEPTED | `can_admin_club(club_id)` = admin activo del club o superadmin; toda RPC/policy de administración de club la usa. |
| D-019 | ACCEPTED | `audit_log.as_platform_admin` es verdadero solo cuando un superadmin actúa sobre un club del que no es admin. Mientras lo hace, la app muestra un banner persistente con salida. La auditoría completa solo la ve el superadmin (`get_audit_log`). |
| D-020 | ACCEPTED | Invitaciones: la Edge Function `invite-member` crea la cuenta con GoTrue `generate_link` (invite, o magiclink si ya existía sin activar) y envía su propio email con la marca del club por el puerto `Mailer`. Cada envío genera un enlace nuevo que invalida el anterior; caducan a las 24 h. Si el email ya tiene cuenta activa, entra directamente en el club (RF-004). Las Edge Functions no usan paquetes npm: hablan con PostgREST y GoTrue por `fetch`. |
| D-021 | ACCEPTED | Los emails de invitación enlazan a la app (`APP_URL/#/activar?token_hash=…&type=…`) y la app llama a `verifyOTP`: compatible con PKCE y sin tokens en la URL. El primer acceso es un estado de sesión (`onboarding`) que bloquea todo lo demás hasta completar contraseña (salvo Google), datos (nombre y apellidos obligatorios) y condiciones de la versión vigente (`current_terms_version()`); `complete_onboarding` lo hace todo en una transacción y activa las pertenencias invitadas. |
| D-022 | ACCEPTED | Staging: web en Firebase Hosting y proyecto Supabase propio; despliegue manual por `workflow_dispatch` en el environment `staging` de GitHub, cada paso condicionado a sus tests; nunca se sube la seed. Ajustes de Auth del proyecto remoto se configuran en el dashboard (no `config push`). |
| D-023 | ACCEPTED | Fotos de socio en el bucket **privado** `profile-photos/<user_id>/` (≤ 2 MB): escribe solo el dueño; leen él, los admins de sus clubes y el superadmin (`can_see_member_photo`); la app las muestra con URL firmada de 1 h. Los datos personales se editan solo con `update_my_profile` (sin UPDATE directo) y el email no se cambia. |
| D-024 | ACCEPTED | Temporadas `YYYY/YYYY+1`, por defecto del 1 de septiembre al 31 de agosto. Estados draft → active → closed; una sola activa por club (índice parcial) y activar cierra la anterior en la misma transacción; una cerrada no se reactiva; reactivar la activa solo cambia su cuota. La cuota ordinaria es obligatoria (≥ 0, céntimos) para activar. |
| D-025 | ACCEPTED | `season_memberships` es la condición de socio por temporada (cuota en céntimos, estado y token del carnet). Toda pertenencia nueva entra sola en la temporada activa con la cuota general (trigger); 0 € = activo. Hasta VS-017 el admin marca a mano pagado/pendiente (`set_season_membership_status`, auditado). El histórico deriva «No renovado» de las temporadas sin fila desde la primera del socio. Las comprobaciones RLS que cruzan `club_memberships` usan funciones `security definer`. |
| D-016 | PROPOSED | Nombre comercial del producto y bundle id (pendiente de usuario). |

## Cuándo crear un ADR

Si la decisión cambia una dependencia central, límites de contexto,
persistencia o seguridad, introduce una excepción arquitectónica o invalida
una decisión anterior.
