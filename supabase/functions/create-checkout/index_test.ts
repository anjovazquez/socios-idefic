import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { HttpError } from "../_shared/http.ts";
import { RpcFailure } from "../_shared/supabase_rest.ts";
import { type Deps, handle } from "./index.ts";

const prepared = {
  payment_id: "pay-1",
  amount_cents: 5000,
  concept: "Cuota de socio 2026/2027",
  stripe_account_id: "acct_idefic",
  club_name: "IDEFIC",
  member_email: "marta@example.com",
};

function deps(overrides: Partial<Deps> = {}) {
  const calls: { fn: string; params: Record<string, unknown>; account?: string }[] = [];
  const value: Deps = {
    backend: {
      userRpc: (fn, params) => {
        calls.push({ fn, params });
        return Promise.resolve([prepared]);
      },
      serviceRpc: (fn, params) => {
        calls.push({ fn, params });
        return Promise.resolve(null);
      },
    },
    createSession: (account, params) => {
      calls.push({ fn: "stripe.checkout", params, account });
      return Promise.resolve({ id: "cs_test_1", url: "https://checkout.stripe.com/c/cs_test_1" });
    },
    appUrl: "https://socios.example/",
    ...overrides,
  };
  return { value, calls };
}

Deno.test("opens a Checkout in the club account for Marta's 50 € fee", async () => {
  const { value, calls } = deps();
  const result = await handle({ seasonMembershipId: "sm-marta" }, value);

  assertEquals(result, { url: "https://checkout.stripe.com/c/cs_test_1", paymentId: "pay-1" });
  assertEquals(calls[0], { fn: "prepare_online_payment", params: { p_season_membership_id: "sm-marta" } });
  const checkout = calls[1];
  assertEquals(checkout.account, "acct_idefic");
  const params = checkout.params as {
    line_items: { price_data: { unit_amount: number; currency: string } }[];
    metadata: { payment_id: string };
    payment_intent_data: { metadata: { payment_id: string } };
    payment_method_types: string[];
    success_url: string;
  };
  assertEquals(params.line_items[0].price_data.unit_amount, 5000);
  assertEquals(params.line_items[0].price_data.currency, "eur");
  assertEquals(params.metadata.payment_id, "pay-1");
  assertEquals(params.payment_intent_data.metadata.payment_id, "pay-1");
  assertEquals(params.payment_method_types, ["card", "sepa_debit"]);
  assertEquals(params.success_url, "https://socios.example/#/club/subscription?pago=ok");
  assertEquals(calls[2], {
    fn: "attach_checkout_session",
    params: { p_payment_id: "pay-1", p_session_id: "cs_test_1" },
  });
});

Deno.test("without Stripe keys online payments are not configured", async () => {
  const { value } = deps({ createSession: null });
  const error = await assertRejects(() => handle({ seasonMembershipId: "sm" }, value), HttpError);
  assertEquals([error.status, error.code], [503, "payments_not_configured"]);
});

Deno.test("database refusals become HTTP errors", async () => {
  const { value } = deps({
    backend: {
      userRpc: () =>
        Promise.reject(new RpcFailure({ code: "P0001", hint: "online_payments_disabled", message: "x" })),
      serviceRpc: () => Promise.resolve(null),
    },
  });
  const error = await assertRejects(() => handle({ seasonMembershipId: "sm" }, value), HttpError);
  assertEquals([error.status, error.code], [409, "online_payments_disabled"]);
});
