// VS-021: the member pays their fee online (ADR-001). Opens a Stripe
// Checkout Session on the club's connected account for the pending payment.
//
// POST { seasonMembershipId, saveForRenewal? } (member JWT)
//   → 200 { url, paymentId }
// With saveForRenewal the card or bank account is kept for the automatic
// renewals (VS-022); the webhook stores it.
// Errors: 401 unauthorized, 403 forbidden, 409 online_payments_disabled |
// not_payable | already_paid, 503 payments_not_configured.

import { corsHeaders, guardRpc, HttpError, json } from "../_shared/http.ts";
import { type StripeOptions, stripeRequest } from "../_shared/stripe.ts";
import { rpc } from "../_shared/supabase_rest.ts";

type Row = Record<string, unknown>;

export interface Backend {
  userRpc(fn: string, params: Row): Promise<Row[]>;
  serviceRpc(fn: string, params: Row): Promise<unknown>;
}

export interface CheckoutSession {
  id: string;
  url: string;
}

export interface Deps {
  backend: Backend;
  /** Null when STRIPE_SECRET_KEY is not configured. */
  createSession: ((account: string, params: Row) => Promise<CheckoutSession>) | null;
  appUrl: string;
}

export function checkoutParams(row: Row, appUrl: string, saveForRenewal = false): Row {
  const base = appUrl.replace(/\/$/, "");
  const paymentId = row.payment_id as string;
  const customer = row.stripe_customer_id as string | null;
  const metadata = {
    payment_id: paymentId,
    club_membership_id: row.club_membership_id,
    save_method: saveForRenewal ? "true" : "false",
  };
  return {
    mode: "payment",
    payment_method_types: ["card", "sepa_debit"],
    ...(customer ? { customer } : { customer_email: row.member_email, customer_creation: "always" }),
    client_reference_id: paymentId,
    metadata,
    line_items: [{
      quantity: 1,
      price_data: {
        currency: "eur",
        unit_amount: row.amount_cents,
        product_data: { name: `${row.concept} · ${row.club_name}` },
      },
    }],
    payment_intent_data: {
      // Only kept for automatic renewals when the member asks (VS-022).
      ...(saveForRenewal ? { setup_future_usage: "off_session" } : {}),
      metadata,
    },
    success_url: `${base}/#/club/subscription?pago=ok`,
    cancel_url: `${base}/#/club/subscription?pago=cancelado`,
  };
}

export async function handle(body: { seasonMembershipId?: string; saveForRenewal?: boolean }, deps: Deps) {
  if (!deps.createSession) throw new HttpError(503, "payments_not_configured");
  if (!body.seasonMembershipId) throw new HttpError(400, "invalid_request");
  const [row] = await guardRpc(() =>
    deps.backend.userRpc("prepare_online_payment", { p_season_membership_id: body.seasonMembershipId })
  );
  const session = await deps.createSession(row.stripe_account_id as string, checkoutParams(row, deps.appUrl, body.saveForRenewal === true));
  await guardRpc(() =>
    deps.backend.serviceRpc("attach_checkout_session", {
      p_payment_id: row.payment_id,
      p_session_id: session.id,
    })
  );
  return { url: session.url, paymentId: row.payment_id };
}

export function depsFromEnv(env: (key: string) => string | undefined, authorization: string): Deps {
  const url = env("SUPABASE_URL")!;
  const anonKey = env("SUPABASE_ANON_KEY")!;
  const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY")!;
  const secretKey = env("STRIPE_SECRET_KEY");
  const stripe: StripeOptions | null = secretKey ? { secretKey, apiUrl: env("STRIPE_API_URL") } : null;
  return {
    backend: {
      userRpc: (fn, params) => rpc<Row[]>({ url, apiKey: anonKey, bearer: authorization }, fn, params),
      serviceRpc: (fn, params) => rpc({ url, apiKey: serviceKey, bearer: `Bearer ${serviceKey}` }, fn, params),
    },
    createSession: stripe
      ? (account, params) => stripeRequest<CheckoutSession>(stripe, "POST", "/v1/checkout/sessions", params, account)
      : null,
    appUrl: env("APP_URL") ?? "http://localhost:3000",
  };
}

if (import.meta.main) {
  Deno.serve(async (request) => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
    const authorization = request.headers.get("Authorization");
    if (!authorization) return json(401, { error: "unauthorized" });
    try {
      const body = await request.json().catch(() => ({}));
      return json(200, await handle(body, depsFromEnv((key) => Deno.env.get(key), authorization)));
    } catch (error) {
      if (error instanceof HttpError) return json(error.status, { error: error.code });
      console.error("create-checkout failed", error);
      return json(500, { error: "unavailable" });
    }
  });
}
