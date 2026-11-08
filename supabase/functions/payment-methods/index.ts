// VS-022: the member saves a payment method for automatic renewals without
// paying (Checkout in setup mode), or removes it.
//
// POST { clubId, action: "setup" } (member JWT) → 200 { url }
// POST { clubId, action: "remove" }             → 200 { removed: true }
// Errors: 401, 403 forbidden, 409 online_payments_disabled,
// 503 payments_not_configured (setup only).

import { corsHeaders, guardRpc, HttpError, json } from "../_shared/http.ts";
import { type StripeOptions, stripeRequest } from "../_shared/stripe.ts";
import { rpc } from "../_shared/supabase_rest.ts";

type Row = Record<string, unknown>;

export interface StripePort {
  createCustomer(account: string, email: string, clubMembershipId: string): Promise<{ id: string }>;
  createSetupSession(account: string, params: Row): Promise<{ id: string; url: string }>;
  detach(account: string, methodId: string): Promise<unknown>;
}

export interface Deps {
  userRpc(fn: string, params: Row): Promise<Row[]>;
  stripe: StripePort | null;
  appUrl: string;
}

export function setupParams(row: Row, customer: string, appUrl: string): Row {
  const base = appUrl.replace(/\/$/, "");
  return {
    mode: "setup",
    payment_method_types: ["card", "sepa_debit"],
    customer,
    metadata: { club_membership_id: row.club_membership_id, save_method: "true" },
    setup_intent_data: { metadata: { club_membership_id: row.club_membership_id } },
    success_url: `${base}/#/club/subscription?metodo=ok`,
    cancel_url: `${base}/#/club/subscription?metodo=cancelado`,
  };
}

export async function handle(body: { clubId?: string; action?: string }, deps: Deps) {
  if (!body.clubId) throw new HttpError(400, "invalid_request");

  if (body.action === "remove") {
    const rows = await guardRpc(() => deps.userRpc("remove_my_payment_method", { p_club_id: body.clubId }));
    for (const row of rows) {
      try {
        await deps.stripe?.detach(row.stripe_account_id as string, row.provider_method_id as string);
      } catch (error) {
        // Already removed for the app: renewals will not use it anyway.
        console.error("detach failed", error);
      }
    }
    return { removed: true };
  }

  if (body.action === "setup") {
    if (!deps.stripe) throw new HttpError(503, "payments_not_configured");
    const [row] = await guardRpc(() => deps.userRpc("prepare_payment_method_setup", { p_club_id: body.clubId }));
    const account = row.stripe_account_id as string;
    const customer = (row.stripe_customer_id as string | null) ??
      (await deps.stripe.createCustomer(account, row.member_email as string, row.club_membership_id as string)).id;
    const session = await deps.stripe.createSetupSession(account, setupParams(row, customer, deps.appUrl));
    return { url: session.url };
  }

  throw new HttpError(400, "invalid_action");
}

function stripePort(options: StripeOptions): StripePort {
  return {
    createCustomer: (account, email, clubMembershipId) =>
      stripeRequest(options, "POST", "/v1/customers", {
        email,
        metadata: { club_membership_id: clubMembershipId },
      }, account),
    createSetupSession: (account, params) =>
      stripeRequest(options, "POST", "/v1/checkout/sessions", params, account),
    detach: (account, methodId) =>
      stripeRequest(options, "POST", `/v1/payment_methods/${methodId}/detach`, {}, account),
  };
}

if (import.meta.main) {
  Deno.serve(async (request) => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
    const authorization = request.headers.get("Authorization");
    if (!authorization) return json(401, { error: "unauthorized" });
    const env = (key: string) => Deno.env.get(key);
    const url = env("SUPABASE_URL")!;
    const anonKey = env("SUPABASE_ANON_KEY")!;
    const secretKey = env("STRIPE_SECRET_KEY");
    try {
      const body = await request.json().catch(() => ({}));
      return json(
        200,
        await handle(body, {
          userRpc: (fn, params) => rpc<Row[]>({ url, apiKey: anonKey, bearer: authorization }, fn, params),
          stripe: secretKey ? stripePort({ secretKey, apiUrl: env("STRIPE_API_URL") }) : null,
          appUrl: env("APP_URL") ?? "http://localhost:3000",
        }),
      );
    } catch (error) {
      if (error instanceof HttpError) return json(error.status, { error: error.code });
      console.error("payment-methods failed", error);
      return json(500, { error: "unavailable" });
    }
  });
}
