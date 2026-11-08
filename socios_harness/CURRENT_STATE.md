# Current State

Snapshot operativo. Se actualiza al final de cada loop.

## Estado general

- Fase actual: **7 — Comunidad (0.7)**.
- Tarea activa: ninguna.
- Última tarea completada: `VS-024 — Cancelación y cobro automático de la renovación` (2026-11-09).
- Siguiente tarea READY: `VS-025 — Blog: publicar (admin)` (también READY: VS-027).
- Bloqueos globales: ninguno. VS-033 (staging) BLOCKED a la espera de credenciales del usuario.

## Milestones

| Milestone | Estado |
|---|---|
| Bootstrap | DONE |
| 0.1 Acceso multi-club | DONE |
| 0.2 Socios | DONE |
| 0.3 Temporadas y cuotas | DONE |
| 0.4 Carnet digital | DONE |
| 0.5 Pagos | DONE |
| 0.6 Pago real y renovación automática | DONE (con Stripe falso local; prueba real pendiente de claves) |
| 0.7 Comunidad | READY (VS-025, VS-027) |
| 0.8 Piloto IDEFIC | TODO (VS-033 adelantada, BLOCKED por credenciales) |

## Decisiones pendientes del usuario

- ADR-001 aceptado (Stripe). Implementado con el default (Connect por club, sin comisión de plataforma); confirmar si se quiere otra cosa. Faltan claves de test (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`) para probar con Stripe real (DEPLOYMENT.md §2.1).
- D-013 aceptado (Resend).
- Credenciales que configurará el usuario: Google OAuth (VS-002), claves test de Stripe (VS-021), `RESEND_API_KEY` (VS-033).
- D-016: nombre comercial / bundle id (provisional `es.idefic.socios_idefic`).

## Infraestructura

- Flutter 207.35.1 (`.fvmrc`); proyecto `socios_idefic`, plataformas web/android/ios.
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
- Mi suscripción (VS-018): RPC `get_my_subscription` y `get_my_payments` (solo el propio socio, 42501 si no es socio activo); pantalla `/club/subscription`; hoja «Cómo pagar» compartida (`startFeePayment`).
- Recibos (VS-019): número correlativo por club + snapshot inmutable al pagar (trigger), RPC `get_receipt` (dueño o admin), `ReceiptRenderer` → PDF (`pdf` + `printing`, Roboto incluida); «Descargar recibo» en el histórico.
- Pagos del club (VS-020): RPC `get_club_payments` (admin; temporada, socio, estado, paginación, totales cobrado/pendiente; las cuotas pendientes sin pago aparecen como «Pendiente» sin `payment_id`); pantalla `/club/payments` (acción «Pagos» de la portada) con recibo por pago.
- Pago online (VS-021): Stripe Connect (Express, cargos directos en la cuenta del club, sin comisión); `clubs.stripe_account_id/stripe_charges_enabled`, `payment_provider_events` (idempotencia), RPC `prepare_online_payment`, `attach_checkout_session`, `apply_payment_event`, `set_club_stripe_account`, `get_club_online_payments`; Edge Functions `create-checkout`, `payments-webhook` (pública, firma verificada), `stripe-onboarding`; `_shared/stripe.ts` y `_shared/http.ts`; `StripePaymentGateway`; «Pagar ahora» en Mi suscripción y «Pagos online» en Configuración. Sin `STRIPE_SECRET_KEY` responde 503 y la app sigue con el pago manual.
- Método guardado (VS-022): `payment_methods` (solo marca/últimos 4/país/mandato; uno activo por socio y club), `club_memberships.auto_renew` y `stripe_customer_id`; RPC `get_my_payment_method`, `prepare_payment_method_setup`, `remove_my_payment_method`, `save_payment_method` (webhook, idempotente); Edge Function `payment-methods` (setup / remove con detach); el webhook guarda el método si `metadata.save_method=true`; casilla «Usar este método para renovar automáticamente» (opt-in) y sección «Renovación automática» en Mi suscripción. `DeepLinkKeeper` en el router conserva el enlace abierto durante la carga (vuelta de Stripe).
- Aviso previo (VS-023): `seasons.renewal_charge_on` (null = inicio) y `renewal_notice_days` (15); vista `automatic_renewals`; `renewal_notices` (uno por renovación); RPC `get_due_renewal_notices`, `claim/release_renewal_notice`, `can_charge_renewal` (RN-012: sin aviso para esa fecha e importe no hay cobro), `set_season_renewal` (admin), `madrid_today`; `get_my_subscription` rellena el próximo cargo; Edge Function `send-renewal-notices` (solo service role) lanzada por pg_cron 07:05 UTC vía pg_net con `project_url`/`service_role_key` de Vault; email `renewalNoticeEmail`; «Cobro automático» por temporada en Temporadas.
- Cobro y cancelación (VS-024): `cancel_renewal` (dueño, antes de la fecha de cobro en hora de Madrid; P0001 `renewal_too_late`); `renewal_charges` (un intento por renovación, `failure_notified_at`); RPC `get_due_renewal_charges`, `claim_renewal_charge`, `get_failed_renewal_charges`, `mark_renewal_failure_notified`; Edge Function `charge-renewals` (pg_cron 08:05 UTC; PaymentIntent off-session con `Idempotency-Key renewal-<id>`; rechazo → fallido) y email `renewalFailedEmail`; webhook `payment_intent.succeeded` con `metadata.source=renewal`; Mi suscripción «Cancelar renovación»; Pagos lista renovaciones canceladas.
- Sesión cloud: Flutter en `$HOME/flutter/bin`; Docker requiere arrancar `dockerd` en segundo plano (ver `QUALITY_GATES.md`). Para probar Edge Functions arrancar sin excluir `edge-runtime`; emails locales en Mailpit `http://127.0.0.1:54324`. El edge-runtime del sandbox no puede descargar de npm (CA del proxy): las funciones no usan npm.
