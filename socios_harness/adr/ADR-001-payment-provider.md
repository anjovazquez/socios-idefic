# ADR-001 — Proveedor de pagos

Status: Accepted (2026-11-08, confirmado por el usuario: Stripe)
Date: 2026-11-08

## Context

§9 del documento funcional pide, por prioridad: simplicidad para el socio,
facilidad de integración, renovación automática, bajo coste y mínima gestión
para el club. La plataforma es multi-club: el dinero de cada club debe llegar
a la cuenta de ese club. La integración debe quedar desacoplada.

## Decision

- **Stripe** con **Stripe Connect** (cuentas Express/Standard por club).
- Métodos: tarjeta (Apple Pay / Google Pay incluidos) y **SEPA Direct Debit**.
- Primer cobro con Checkout/Payment Element guardando el método
  (`setup_future_usage=off_session`); renovaciones como PaymentIntent
  off-session lanzado por cron tras el aviso previo (no Stripe Billing, para
  controlar aviso, cancelación e importe personalizado por socio).
- Webhook en Edge Function `payments-webhook` como única fuente de verdad del
  estado del pago.
- La app solo conoce el puerto `PaymentGateway`; el adaptador `manual`
  (D-011) se mantiene para pagos en efectivo / transferencia.

## Consequences

### Positive
- Renovación automática real con tarjeta y domiciliación.
- Cada club cobra en su cuenta; la plataforma puede cobrar comisión si se quiere.
- SEPA más barato que tarjeta para cuotas recurrentes.

### Negative
- Cada club debe completar el onboarding KYC de Stripe.
- SEPA confirma en días (estado `pending` largo).

## Alternatives considered

- **Bizum**: muy simple para el socio pero sin cobro recurrente; útil solo como pago manual.
- **Redsys (TPV virtual del banco)**: barato pero integración más pesada y recurrencia (COF) dependiente del banco de cada club.
- **GoCardless**: excelente para SEPA recurrente, sin tarjeta.
- **PayPal**: peor experiencia en España para cuotas recurrentes.

## Open questions (no bloquean hasta VS-021; default: Connect por club, sin comisión)

- ¿Cada club cobra en su propia cuenta (Connect) o IDEFIC centraliza al principio?
- ¿Comisión de plataforma?

## Supersedes

- None
