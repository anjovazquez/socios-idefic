import { assertEquals } from "jsr:@std/assert@1";
import { signPayload } from "../_shared/stripe.ts";
import { type Deps, handle, paymentUpdateOf, savedMethodOf } from "./index.ts";

const secret = "whsec_test";
const now = 1_800_000_000;

function event(id: string, type: string, object: Record<string, unknown>) {
  return JSON.stringify({ id, type, account: "acct_idefic", data: { object } });
}

/** Fake database: applies each event id once, like apply_payment_event. */
function fakeDeps() {
  const applied = new Set<string>();
  const calls: { fn: string; params: Record<string, unknown> }[] = [];
  const deps: Deps = {
    secret,
    nowSeconds: now,
    serviceRpc: (fn, params) => {
      calls.push({ fn, params });
      if (fn !== "apply_payment_event") return Promise.resolve(null);
      const id = params.p_event_id as string;
      if (applied.has(id)) return Promise.resolve("duplicate");
      applied.add(id);
      return Promise.resolve("applied");
    },
  };
  return { deps, calls };
}

async function deliver(payload: string, deps: Deps, signature?: string | null) {
  return await handle(payload, signature === undefined ? await signPayload(payload, secret, now) : signature, deps);
}

const paidCheckout = event("evt_paid", "checkout.session.completed", {
  id: "cs_1",
  payment_status: "paid",
  payment_intent: "pi_1",
  metadata: { payment_id: "pay-marta" },
});

Deno.test("a valid card payment marks the payment paid", async () => {
  const { deps, calls } = fakeDeps();
  const result = await deliver(paidCheckout, deps);
  assertEquals(result, { status: 200, body: { result: "applied" } });
  assertEquals(calls[0].params, {
    p_event_id: "evt_paid",
    p_type: "checkout.session.completed",
    p_payment_id: "pay-marta",
    p_status: "paid",
    p_method: "card",
    p_reference: "pi_1",
  });
});

Deno.test("a repeated event is not processed twice", async () => {
  const { deps } = fakeDeps();
  await deliver(paidCheckout, deps);
  const again = await deliver(paidCheckout, deps);
  assertEquals(again, { status: 200, body: { result: "duplicate" } });
});

Deno.test("a webhook without a valid signature is rejected", async () => {
  const { deps, calls } = fakeDeps();
  assertEquals((await deliver(paidCheckout, deps, null)).status, 400);
  assertEquals((await deliver(paidCheckout, deps, await signPayload(paidCheckout, "whsec_forged", now))).status, 400);
  const tampered = paidCheckout.replace("pay-marta", "pay-other");
  assertEquals((await deliver(tampered, deps, await signPayload(paidCheckout, secret, now))).status, 400);
  assertEquals(calls.length, 0);
});

Deno.test("a declined card marks the payment failed", async () => {
  const { deps, calls } = fakeDeps();
  await deliver(
    event("evt_declined", "payment_intent.payment_failed", {
      id: "pi_2",
      metadata: { payment_id: "pay-marta" },
    }),
    deps,
  );
  assertEquals(calls[0].params.p_status, "failed");
});

Deno.test("maps SEPA, expiry and unrelated events", () => {
  const object = { id: "cs_1", metadata: { payment_id: "p" } };
  const parse = (type: string, extra: Record<string, unknown> = {}) =>
    paymentUpdateOf(JSON.parse(event("e", type, { ...object, ...extra })));
  assertEquals(parse("checkout.session.completed", { payment_status: "unpaid" }), null);
  assertEquals(parse("checkout.session.async_payment_succeeded")?.method, "sepa");
  assertEquals(parse("checkout.session.async_payment_failed")?.status, "failed");
  assertEquals(parse("checkout.session.expired")?.status, "cancelled");
  assertEquals(parse("customer.created"), null);
});

Deno.test("account updates enable the club online payments", async () => {
  const { deps, calls } = fakeDeps();
  await deliver(event("evt_acct", "account.updated", { id: "acct_idefic", charges_enabled: true }), deps);
  assertEquals(calls[0], {
    fn: "set_club_stripe_account",
    params: { p_club_id: null, p_account_id: "acct_idefic", p_charges_enabled: true },
  });
});

function depsWithIntents(intent: Record<string, unknown>) {
  const { deps, calls } = fakeDeps();
  deps.retrieveIntent = (account, kind, id) => {
    calls.push({ fn: `stripe.${kind}`, params: { account, id } });
    return Promise.resolve(intent);
  };
  return { deps, calls };
}

Deno.test("«renovar automáticamente»: the card ending in 4242 is saved", async () => {
  const { deps, calls } = depsWithIntents({
    id: "pi_1",
    customer: "cus_marta",
    payment_method: { id: "pm_card", type: "card", card: { brand: "visa", last4: "4242", country: "ES" } },
  });
  const payload = event("evt_paid_save", "checkout.session.completed", {
    id: "cs_1",
    mode: "payment",
    payment_status: "paid",
    payment_intent: "pi_1",
    customer: "cus_marta",
    metadata: { payment_id: "pay-marta", club_membership_id: "cm-marta", save_method: "true" },
  });
  await deliver(payload, deps);

  assertEquals(calls[0], { fn: "stripe.payment_intents", params: { account: "acct_idefic", id: "pi_1" } });
  assertEquals(calls[1].fn, "save_payment_method");
  assertEquals(calls[1].params.p_last4, "4242");
  assertEquals(calls[1].params.p_brand, "visa");
  assertEquals(calls[2].fn, "apply_payment_event");
});

Deno.test("a bank account saved in setup mode keeps its mandate", async () => {
  const { deps, calls } = depsWithIntents({
    id: "seti_1",
    mandate: "mandate_1",
    payment_method: { id: "pm_sepa", type: "sepa_debit", sepa_debit: { last4: "3000", country: "ES" } },
  });
  const result = await deliver(
    event("evt_setup", "checkout.session.completed", {
      id: "cs_setup",
      mode: "setup",
      setup_intent: "seti_1",
      customer: "cus_marta",
      metadata: { club_membership_id: "cm-marta", save_method: "true" },
    }),
    deps,
  );
  assertEquals(calls[0].fn, "stripe.setup_intents");
  assertEquals(calls[1].params.p_kind, "sepa_debit");
  assertEquals(calls[1].params.p_mandate_id, "mandate_1");
  assertEquals(result.status, 200);
});

Deno.test("without «renovar automáticamente» nothing is saved", async () => {
  const { deps, calls } = depsWithIntents({});
  await deliver(paidCheckout, deps);
  assertEquals(calls.map((c) => c.fn), ["apply_payment_event"]);
});

Deno.test("only masked data leaves the intent", () => {
  const method = savedMethodOf(
    { customer: "cus", metadata: { club_membership_id: "cm" } },
    { payment_method: { id: "pm", type: "card", card: { brand: "visa", last4: "4242", number: "4242424242424242" } } },
  );
  assertEquals(Object.values(method ?? {}).includes("4242424242424242"), false);
  assertEquals(savedMethodOf({ metadata: {} }, { payment_method: "pm_not_expanded" }), null);
});

Deno.test("renewal payment intents are confirmed by the webhook; Checkout ones are not", () => {
  const renewal = paymentUpdateOf(JSON.parse(event("e", "payment_intent.succeeded", {
    id: "pi_r",
    metadata: { payment_id: "pay-r", source: "renewal", method: "sepa" },
  })));
  assertEquals(renewal, { paymentId: "pay-r", status: "paid", method: "sepa", reference: "pi_r" });
  const checkout = paymentUpdateOf(JSON.parse(event("e", "payment_intent.succeeded", {
    id: "pi_c",
    metadata: { payment_id: "pay-c" },
  })));
  assertEquals(checkout, null);
});
