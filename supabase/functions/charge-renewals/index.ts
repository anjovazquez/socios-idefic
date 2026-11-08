// VS-024: daily job (pg_cron → this function) that charges the automatic
// renewals on their charge date (RF-012) with the saved method, off-session,
// in the club's connected account. Only renewals whose notice was sent
// (RN-012) and not cancelled (RF-014). One attempt per renewal: the claim in
// `renewal_charges` and the Stripe Idempotency-Key prevent double charges.
// Then it emails the members whose charge failed. Only the service role.
//
// POST { today?: "YYYY-MM-DD" } → 200 { today, charged, pending, failed, notified }

import { renewalFailedEmail } from "../_shared/emails.ts";
import { json } from "../_shared/http.ts";
import { type Mailer, mailerFromEnv } from "../_shared/mailer.ts";
import { StripeError, type StripeOptions, stripeRequest } from "../_shared/stripe.ts";
import { rpc } from "../_shared/supabase_rest.ts";
import { madridToday } from "../send-renewal-notices/index.ts";

type Row = Record<string, unknown>;

export interface PaymentIntent {
  id: string;
  status: string;
}

export interface Deps {
  serviceRpc<T>(fn: string, params: Row): Promise<T>;
  /** Null when STRIPE_SECRET_KEY is not configured: nothing is charged. */
  createPaymentIntent:
    | ((account: string, params: Row, idempotencyKey: string) => Promise<PaymentIntent>)
    | null;
  mailer: Mailer;
  appUrl: string;
  publicSupabaseUrl: string;
}

export function paymentIntentParams(seasonMembershipId: string, charge: Row): Row {
  const method = charge.method_kind === "sepa_debit" ? "sepa" : "card";
  return {
    amount: charge.amount_cents,
    currency: "eur",
    customer: charge.customer_id,
    payment_method: charge.method_id,
    payment_method_types: [charge.method_kind === "sepa_debit" ? "sepa_debit" : "card"],
    off_session: true,
    confirm: true,
    description: "Renovación automática de la cuota de socio",
    metadata: {
      payment_id: charge.payment_id,
      season_membership_id: seasonMembershipId,
      source: "renewal",
      method,
    },
  };
}

async function charge(deps: Deps, seasonMembershipId: string, today: string): Promise<"charged" | "pending" | "failed" | "skipped"> {
  const [claimed] = await deps.serviceRpc<Row[]>("claim_renewal_charge", {
    p_season_membership_id: seasonMembershipId,
    p_today: today,
  });
  if (!claimed) return "skipped";
  const paymentId = claimed.payment_id as string;
  const apply = (eventId: string, status: "paid" | "failed", method?: string, reference?: string) =>
    deps.serviceRpc("apply_payment_event", {
      p_event_id: eventId,
      p_type: "renewal.charge",
      p_payment_id: paymentId,
      p_status: status,
      p_method: method ?? null,
      p_reference: reference ?? null,
    });
  try {
    const params = paymentIntentParams(seasonMembershipId, claimed);
    const intent = await deps.createPaymentIntent!(
      claimed.stripe_account_id as string,
      params,
      `renewal-${seasonMembershipId}`,
    );
    if (intent.status === "succeeded") {
      // The webhook confirms it too; the first one applies, the other is ignored.
      await apply(`charge_ok:${intent.id}`, "paid", (params.metadata as Row).method as string, intent.id);
      return "charged";
    }
    if (intent.status === "processing") return "pending"; // SEPA: the webhook decides.
    // requires_action / requires_payment_method: cannot be charged off-session.
    await apply(`charge_failed:${paymentId}`, "failed", undefined, intent.id);
    return "failed";
  } catch (error) {
    // Declined (402) or any other error: failed; the member pays manually.
    // If Stripe did charge, its webhook later turns it into paid.
    console.error("renewal charge failed", seasonMembershipId, error instanceof StripeError ? error.code : error);
    await apply(`charge_failed:${paymentId}`, "failed");
    return "failed";
  }
}

export async function handle(body: { today?: string }, deps: Deps) {
  const today = body.today && /^\d{4}-\d{2}-\d{2}$/.test(body.today) ? body.today : madridToday();
  const result = { today, charged: 0, pending: 0, failed: 0, notified: 0 };
  if (deps.createPaymentIntent) {
    const due = await deps.serviceRpc<Row[]>("get_due_renewal_charges", { p_today: today });
    for (const row of due) {
      const outcome = await charge(deps, row.season_membership_id as string, today);
      if (outcome !== "skipped") result[outcome]++;
    }
  }

  // «No hemos podido cobrar tu cuota»: also failures confirmed by the webhook.
  const failed = await deps.serviceRpc<Row[]>("get_failed_renewal_charges", {});
  for (const row of failed) {
    const logoPath = row.club_logo_path as string | null;
    try {
      await deps.mailer.send(
        renewalFailedEmail({
          club: {
            name: row.club_name as string,
            primaryColor: row.club_primary_color as string | null,
            logoUrl: logoPath ? `${deps.publicSupabaseUrl}/storage/v1/object/public/club-assets/${logoPath}` : null,
          },
          to: { email: row.email as string, name: (row.first_name as string | null) ?? undefined },
          seasonName: row.season_name as string,
          amountCents: row.amount_cents as number,
          link: `${deps.appUrl.replace(/\/$/, "")}/#/club/subscription`,
        }),
      );
      await deps.serviceRpc("mark_renewal_failure_notified", { p_season_membership_id: row.season_membership_id });
      result.notified++;
    } catch (error) {
      console.error("renewal failure email not sent", row.email, error);
    }
  }
  return result;
}

if (import.meta.main) {
  Deno.serve(async (request) => {
    if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
    const env = (key: string) => Deno.env.get(key);
    const url = env("SUPABASE_URL")!;
    const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY")!;
    if (request.headers.get("Authorization") !== `Bearer ${serviceKey}`) {
      return json(403, { error: "forbidden" });
    }
    const secretKey = env("STRIPE_SECRET_KEY");
    const stripe: StripeOptions | null = secretKey ? { secretKey, apiUrl: env("STRIPE_API_URL") } : null;
    try {
      const body = await request.json().catch(() => ({}));
      return json(
        200,
        await handle(body, {
          serviceRpc: (fn, params) => rpc({ url, apiKey: serviceKey, bearer: `Bearer ${serviceKey}` }, fn, params),
          createPaymentIntent: stripe
            ? (account, params, key) => stripeRequest(stripe, "POST", "/v1/payment_intents", params, account, key)
            : null,
          mailer: mailerFromEnv(env),
          appUrl: env("APP_URL") ?? "http://localhost:3000",
          publicSupabaseUrl: env("PUBLIC_SUPABASE_URL") ?? url,
        }),
      );
    } catch (error) {
      console.error("charge-renewals failed", error);
      return json(500, { error: "unavailable" });
    }
  });
}
