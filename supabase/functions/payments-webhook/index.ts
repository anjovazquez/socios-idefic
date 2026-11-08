// VS-021: Stripe webhook, the only source of truth of online payments
// (ADR-001). Public endpoint (no JWT); every event must carry a valid
// `Stripe-Signature`. Each event is applied once (payment_provider_events).
//
// Endpoint configured in Stripe for the platform AND its connected accounts.

import { json } from "../_shared/http.ts";
import { SignatureError, type StripeEvent, verifyWebhook } from "../_shared/stripe.ts";
import { rpc } from "../_shared/supabase_rest.ts";

type Row = Record<string, unknown>;

export interface Deps {
  secret: string;
  serviceRpc(fn: string, params: Row): Promise<unknown>;
  nowSeconds?: number;
}

export interface PaymentUpdate {
  paymentId: string;
  status: "paid" | "failed" | "cancelled";
  method?: string;
  reference?: string;
}

function paymentIdOf(object: Row): string | undefined {
  return ((object.metadata as Row | undefined)?.payment_id as string | undefined) ??
    (object.client_reference_id as string | undefined);
}

/** Which payment change an event means, if any. */
export function paymentUpdateOf(event: StripeEvent): PaymentUpdate | null {
  const object = event.data.object;
  const paymentId = paymentIdOf(object);
  if (!paymentId) return null;
  const reference = (object.payment_intent as string | undefined) ?? (object.id as string | undefined);
  switch (event.type) {
    case "checkout.session.completed":
      // Card: paid now. SEPA: `unpaid` until the async events.
      return object.payment_status === "paid" ? { paymentId, status: "paid", method: "card", reference } : null;
    case "checkout.session.async_payment_succeeded":
      return { paymentId, status: "paid", method: "sepa", reference };
    case "checkout.session.async_payment_failed":
    case "payment_intent.payment_failed":
      return { paymentId, status: "failed", reference };
    case "checkout.session.expired":
      return { paymentId, status: "cancelled", reference };
    default:
      return null;
  }
}

export async function handle(payload: string, signature: string | null, deps: Deps) {
  let event: StripeEvent;
  try {
    event = await verifyWebhook(payload, signature, deps.secret, deps.nowSeconds);
  } catch (error) {
    if (error instanceof SignatureError) return { status: 400, body: { error: "invalid_signature" } };
    throw error;
  }

  if (event.type === "account.updated") {
    const account = event.data.object;
    await deps.serviceRpc("set_club_stripe_account", {
      p_club_id: null,
      p_account_id: account.id,
      p_charges_enabled: account.charges_enabled === true,
    });
    return { status: 200, body: { result: "account_updated" } };
  }

  const update = paymentUpdateOf(event);
  if (!update) return { status: 200, body: { result: "ignored" } };
  const result = await deps.serviceRpc("apply_payment_event", {
    p_event_id: event.id,
    p_type: event.type,
    p_payment_id: update.paymentId,
    p_status: update.status,
    p_method: update.method ?? null,
    p_reference: update.reference ?? null,
  });
  return { status: 200, body: { result } };
}

if (import.meta.main) {
  Deno.serve(async (request) => {
    if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
    const env = (key: string) => Deno.env.get(key);
    const url = env("SUPABASE_URL")!;
    const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY")!;
    try {
      const { status, body } = await handle(await request.text(), request.headers.get("Stripe-Signature"), {
        secret: env("STRIPE_WEBHOOK_SECRET") ?? "",
        serviceRpc: (fn, params) => rpc({ url, apiKey: serviceKey, bearer: `Bearer ${serviceKey}` }, fn, params),
      });
      return json(status, body);
    } catch (error) {
      // 500 makes Stripe retry; the event id keeps it idempotent.
      console.error("payments-webhook failed", error);
      return json(500, { error: "unavailable" });
    }
  });
}
