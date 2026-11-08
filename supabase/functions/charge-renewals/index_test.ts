import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { EmailMessage } from "../_shared/mailer.ts";
import { StripeError } from "../_shared/stripe.ts";
import { type Deps, handle, type PaymentIntent } from "./index.ts";

const claim = {
  payment_id: "pay-marta",
  amount_cents: 5000,
  stripe_account_id: "acct_idefic",
  customer_id: "cus_marta",
  method_id: "pm_marta",
  method_kind: "card",
};

/** Fake database: one claim per renewal, failed charges to notify. */
function fake(intent: (key: string) => Promise<PaymentIntent>, due = ["sm-marta"]) {
  const claimed = new Set<string>();
  const applied: Record<string, unknown>[] = [];
  const keys: string[] = [];
  const intents: Record<string, unknown>[] = [];
  const sent: EmailMessage[] = [];
  const notified = new Set<string>();
  const deps: Deps = {
    serviceRpc: <T>(fn: string, params: Record<string, unknown>) => {
      switch (fn) {
        case "get_due_renewal_charges":
          return Promise.resolve(due.filter((id) => !claimed.has(id)).map((id) => ({ season_membership_id: id })) as T);
        case "claim_renewal_charge": {
          const id = params.p_season_membership_id as string;
          if (claimed.has(id)) return Promise.resolve([] as T);
          claimed.add(id);
          return Promise.resolve([claim] as T);
        }
        case "apply_payment_event":
          applied.push(params);
          return Promise.resolve("applied" as T);
        case "get_failed_renewal_charges":
          return Promise.resolve(
            (applied.some((a) => a.p_status === "failed") && !notified.has("sm-marta")
              ? [{
                season_membership_id: "sm-marta",
                email: "marta@example.com",
                first_name: "Marta",
                club_name: "IDEFIC",
                season_name: "2027/2028",
                amount_cents: 5000,
              }]
              : []) as T,
          );
        case "mark_renewal_failure_notified":
          notified.add(params.p_season_membership_id as string);
          return Promise.resolve(null as T);
      }
      return Promise.resolve(null as T);
    },
    createPaymentIntent: (_account, params, key) => {
      keys.push(key);
      intents.push(params);
      return intent(key);
    },
    mailer: { send: (m) => Promise.resolve(void sent.push(m)) },
    appUrl: "https://socios.example",
    publicSupabaseUrl: "https://ref.supabase.co",
  };
  return { deps, applied, keys, intents, sent };
}

Deno.test("on the charge date the saved card is charged off-session: paid", async () => {
  const { deps, applied, keys, intents } = fake(() => Promise.resolve({ id: "pi_1", status: "succeeded" }));
  const result = await handle({ today: "2027-09-01" }, deps);
  assertEquals(result.charged, 1);
  assertEquals(keys, ["renewal-sm-marta"]);
  const params = intents[0] as Record<string, unknown>;
  assertEquals([params.amount, params.off_session, params.confirm, params.payment_method], [5000, true, true, "pm_marta"]);
  assertEquals((params.metadata as Record<string, string>).source, "renewal");
  assertEquals(applied[0].p_status, "paid");
});

Deno.test("running the job twice the same day charges once", async () => {
  const { deps, intents } = fake(() => Promise.resolve({ id: "pi_1", status: "succeeded" }));
  await handle({ today: "2027-09-01" }, deps);
  await handle({ today: "2027-09-01" }, deps);
  assertEquals(intents.length, 1);
});

Deno.test("an expired card: failed and an email to pay manually", async () => {
  const { deps, applied, sent } = fake(() =>
    Promise.reject(new StripeError(402, "card_declined", "Your card has expired.", "expired_card"))
  );
  const result = await handle({ today: "2027-09-01" }, deps);
  assertEquals([result.failed, result.notified], [1, 1]);
  assertEquals(applied[0].p_status, "failed");
  assertEquals(sent[0].subject, "No hemos podido cobrar tu cuota de IDEFIC");
  assertStringIncludes(sent[0].text, "Tu renovación sigue pendiente");
  assertStringIncludes(sent[0].text, "https://socios.example/#/club/subscription");
  // Notified only once.
  await handle({ today: "2027-09-02" }, deps);
  assertEquals(sent.length, 1);
});

Deno.test("SEPA in process waits for the webhook", async () => {
  const { deps, applied } = fake(() => Promise.resolve({ id: "pi_2", status: "processing" }));
  assertEquals((await handle({ today: "2027-09-01" }, deps)).pending, 1);
  assertEquals(applied.length, 0);
});

Deno.test("without Stripe keys nothing is charged", async () => {
  const { deps, intents } = fake(() => Promise.resolve({ id: "x", status: "succeeded" }));
  const result = await handle({ today: "2027-09-01" }, { ...deps, createPaymentIntent: null });
  assertEquals([result.charged, intents.length], [0, 0]);
});
