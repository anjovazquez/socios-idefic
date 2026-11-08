import { assertEquals } from "jsr:@std/assert@1";
import { signPayload } from "../_shared/stripe.ts";
import { type Deps, handle, paymentUpdateOf } from "./index.ts";

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
