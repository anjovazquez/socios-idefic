# Project Memory — Socios IDEFIC

Memoria estable. Solo hechos válidos durante muchas tareas (ver `MEMORY_POLICY.md`).

## Producto

- Nombre de trabajo: **Socios IDEFIC** (nombre comercial pendiente, D-pendiente).
- Plataforma **multi-club** de gestión de socios para baloncesto amateur.
- Primer club de validación: **IDEFIC**, temporada **2026/2027**.
- Especificación funcional: `docs/PROPUESTA_FUNCIONAL_MVP.md` (RF-001…RF-030, RN-001…RN-017).
- Proyecto hermano: Xogalle (gestión de equipo). Se reutiliza su metodología, stack y estilo de arquitectura; no se comparte base de datos.

## Stack decidido

- Flutter (Web para administración y socio; Android/iOS para socio).
- Arquitectura hexagonal, vertical slices, BDD.
- `get_it` (composition root), `provider`/`ChangeNotifier`, `go_router`.
- Supabase: Auth (email+contraseña y Google), Postgres, RLS, RPC, Storage, Edge Functions, pg_cron.
- Pagos detrás del puerto `PaymentGateway`; proveedor real **Stripe** (Connect por club, tarjeta + SEPA; ADR-001).
- Emails transaccionales con **Resend** detrás de un puerto `Mailer` en Edge Functions.

## Reglas arquitectónicas

- `domain` no importa Flutter, Supabase, Provider, GetIt ni SDKs de pago.
- La UI no llama a Supabase directamente.
- ViewModels solo estado de presentación + orquestación de use cases.
- Use cases con dependencias por constructor.
- RLS en todas las tablas expuestas; operaciones multi-paso en RPC `security definer` con comprobación explícita de rol.
- Importes en **céntimos enteros** (`amount_cents`), moneda EUR.
- Nunca confiar en el reloj del dispositivo para cobros, avisos o validez.
- Claves de proveedores (pago, email, service role) solo en Edge Functions.

## Invariantes de dominio

- No hay registro público (RN-001); signup deshabilitado en Supabase Auth.
- Un socio siempre lo da de alta un administrador (RN-002).
- El email identifica al usuario globalmente; una sola cuenta por persona (RN-003, RN-005).
- La pertenencia es `usuario + club` (`club_memberships`), con número de socio propio por club (RN-006).
- La condición de socio es por temporada: `season_memberships` (RN-007).
- Una sola temporada activa por club (RF-007).
- Cada temporada tiene cuota general; cada socio-temporada puede tener cuota personalizada, incluida 0 € (RN-008…RN-010).
- Estados de pago mínimos: `pending`, `paid`, `failed`, `cancelled` (RF-015).
- Antes de cualquier cobro automático hay aviso previo y posibilidad de cancelar (RN-012, RN-013).
- El carnet válido corresponde a una temporada concreta (RN-014).
- Patrocinadores vinculados a temporadas; no pasan solos a la siguiente (RN-016).
- Todo el contenido es privado salvo la validación mínima del QR (RN-017), que nunca muestra teléfono, email, fecha de nacimiento ni datos de pago.
- Roles: `platform_admin` (global), `club_admin` (uno por club en el MVP), `member`.
- Acciones del superadmin sobre un club quedan auditadas como suyas.

## Modelo conceptual (tablas previstas)

`profiles`, `clubs`, `club_memberships`, `club_invitations`, `seasons`,
`season_memberships`, `payments`, `payment_methods`, `renewal_notices`,
`sponsors`, `sponsor_seasons`, `posts`, `perks`, `platform_admins`, `audit_log`.

## Conocimiento técnico estable

- Supabase Auth: el registro público se cierra con `auth.enable_signup = false`; `[auth.email].enable_signup` debe seguir en `true` porque en GoTrue activa el proveedor email (si es `false`, no se puede iniciar sesión con contraseña).
- Google: proveedor activo con secretos por env; GoTrue rechaza cuentas nuevas (`signup_disabled`) y vincula por email verificado. Los fallos del retorno OAuth llegan como errores del stream de sesión (`AuthFailure`). Deep link móvil `es.idefic.socios://login-callback`.
- Cliente: `Supabase.initialize(publishableKey: ...)` (`anonKey` está deprecado).
- Navegación: cada `SessionStatus` tiene una ruta; `go_router` redirige con `refreshListenable` = `SessionViewModel`.
- Club activo recordado por dispositivo (`ActiveClubStore`, shared_preferences) y olvidado al cerrar sesión.
- Storage: un upload con `upsert` exige política SELECT sobre `storage.objects` además de INSERT/UPDATE.
- Rutas: cada estado de sesión tiene un área (`/club`, `/platform`…) y sus subrutas (`/club/settings`) se permiten con `redirectFor`.
- Pruebas web en el sandbox: `flutter build web --no-web-resources-cdn` (gstatic bloqueado); los campos de Flutter web se rellenan haciendo clic por coordenadas y escribiendo con el teclado; para `image_picker` web se engancha `HTMLInputElement.prototype.click` e inyecta el fichero con `DataTransfer` (build `--profile` para trazas legibles).

- Administración: toda RPC de gestión es `security definer`, valida el rol con `require_platform_admin()` (o `can_admin_club` desde VS-005) y registra `audit(club_id, action, payload)`, que guarda el actor real y si actuó como plataforma.
- Errores de RPC → SQLSTATE: `42501` permiso, `22023` dato inválido, `23505` duplicado, `P0001` regla de negocio (con `hint`), `P0002` no encontrado. Los adapters los mapean a fallos de dominio.
- Un único admin por club (índices parciales en `club_memberships` y `club_invitations`); el superadmin ve todos los clubes activos en el selector con rol `platform_admin` y tiene el estado de sesión `platform`.

- Edge Functions: Deno 2, sin dependencias npm en runtime (`supabase/functions/deno.json` con `lock: false` y `nodeModulesDir: none`); el acceso a Supabase va por `_shared/supabase_rest.ts`; la lógica se prueba con una interfaz `Backend` falsa (`deno test`, job `edge-functions` en CI). Los errores de RPC se traducen a HTTP (`403 forbidden`, `400 invalid_*`, `409 <hint>`), y la app los mapea a fallos de dominio.
- Enlaces de email: nunca el `action_link` de GoTrue (tokens implícitos incompatibles con PKCE), sino `APP_URL/#/activar?token_hash=…&type=…` + `verifyOTP` en la app. Los tokens son de un solo uso.
- GoTrue pone un hash aleatorio de contraseña a los invitados: «necesita contraseña» se deduce de no haber completado el primer acceso y no tener identidad Google. Volver a poner la misma contraseña devuelve `same_password` (se trata como éxito).
- «Cuenta existente activa» (RF-004) = `profiles.onboarded_at` no nulo; quien abrió una invitación sin terminar el primer acceso recibe un enlace de activación nuevo.
- Cualquier usuario autenticado pasa primero por `get_my_onboarding_status`; las cuentas de la seed ya lo tienen completado.

## Producto / UX

- Socio: navegación Inicio/Blog · Mi carnet · Mis ventajas · Mi suscripción · Mis datos.
- Admin de club (web): Dashboard · Socios · Temporadas · Pagos · Patrocinadores · Ventajas · Blog · Configuración.
- Selector de club tras login si hay más de uno; cambio sin re-login (RF-030).
- La identidad visual del club activo tiñe cabecera, navegación, carnet y recibos.
- Sistema de diseño en `DESIGN.md` (raíz): tema del club con `buildClubTheme`, contraste AA con `readableOn`, `ClubAvatar`, patrones de formulario/confirmación/estado vacío. Se amplía en cada slice que lo necesite.
