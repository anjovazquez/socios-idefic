// VS-021: the club admin connects the club to Stripe (Express account,
// ADR-001) and returns to Configuración; `refresh` reads the account status.
//
// POST { clubId, action?: "link" | "refresh" } (admin JWT)
//   link    → 200 { url } (Stripe onboarding)
//   refresh → 200 { accountId, chargesEnabled }
// Errors: 401, 403 forbidden, 503 payments_not_configured.

import { corsHeaders, guardRpc, HttpError, json } from "../_shared/http.ts";
import { type StripeOptions, stripeRequest } from "../_shared/stripe.ts";
import { rpc } from "../_shared/supabase_rest.ts";

type Row = Record<string, unknown>;

export interface StripeAccounts {
  create(clubId: string): Promise<{ id: string }>;
  retrieve(accountId: string): Promise<{ id: string; charges_enabled?: boolean }>;
  onboardingLink(accountId: string, returnUrl: string): Promise<{ url: string }>;
}

export interface Deps {
  userRpc(fn: string, params: Row): Promise<Row[]>;
  serviceRpc(fn: string, params: Row): Promise<unknown>;
  stripe: StripeAccounts | null;
  appUrl: string;
}

export async function handle(body: { clubId?: string; action?: string }, deps: Deps) {
  if (!deps.stripe) throw new HttpError(503, "payments_not_configured");
  if (!body.clubId) throw new HttpError(400, "invalid_request");
  const stripe = deps.stripe;
  // Admin check by the database (42501 → 403).
  const [status] = await guardRpc(() => deps.userRpc("get_club_online_payments", { p_club_id: body.clubId }));
  let accountId = status?.stripe_account_id as string | null;

  if (body.action === "refresh") {
    if (!accountId) return { accountId: null, chargesEnabled: false };
    const account = await stripe.retrieve(accountId);
    const chargesEnabled = account.charges_enabled === true;
    await guardRpc(() =>
      deps.serviceRpc("set_club_stripe_account", {
        p_club_id: body.clubId,
        p_account_id: accountId,
        p_charges_enabled: chargesEnabled,
      })
    );
    return { accountId, chargesEnabled };
  }

  if (!accountId) {
    accountId = (await stripe.create(body.clubId)).id;
    await guardRpc(() =>
      deps.serviceRpc("set_club_stripe_account", {
        p_club_id: body.clubId,
        p_account_id: accountId,
        p_charges_enabled: false,
      })
    );
  }
  const returnUrl = `${deps.appUrl.replace(/\/$/, "")}/#/club/settings?stripe=volver`;
  return { url: (await stripe.onboardingLink(accountId, returnUrl)).url };
}

function stripeAccounts(options: StripeOptions): StripeAccounts {
  return {
    create: (clubId) =>
      stripeRequest(options, "POST", "/v1/accounts", {
        type: "express",
        country: "ES",
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
          sepa_debit_payments: { requested: true },
        },
        metadata: { club_id: clubId },
      }),
    retrieve: (accountId) => stripeRequest(options, "GET", `/v1/accounts/${accountId}`),
    onboardingLink: (accountId, returnUrl) =>
      stripeRequest(options, "POST", "/v1/account_links", {
        account: accountId,
        type: "account_onboarding",
        refresh_url: returnUrl,
        return_url: returnUrl,
      }),
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
    const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY")!;
    const secretKey = env("STRIPE_SECRET_KEY");
    try {
      const body = await request.json().catch(() => ({}));
      return json(
        200,
        await handle(body, {
          userRpc: (fn, params) => rpc<Row[]>({ url, apiKey: anonKey, bearer: authorization }, fn, params),
          serviceRpc: (fn, params) => rpc({ url, apiKey: serviceKey, bearer: `Bearer ${serviceKey}` }, fn, params),
          stripe: secretKey ? stripeAccounts({ secretKey, apiUrl: env("STRIPE_API_URL") }) : null,
          appUrl: env("APP_URL") ?? "http://localhost:3000",
        }),
      );
    } catch (error) {
      if (error instanceof HttpError) return json(error.status, { error: error.code });
      console.error("stripe-onboarding failed", error);
      return json(500, { error: "unavailable" });
    }
  });
}
