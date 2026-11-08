import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { HttpError } from "../_shared/http.ts";
import { type Deps, handle } from "./index.ts";

function deps(customer: string | null = null) {
  const calls: string[] = [];
  let setup: Record<string, unknown> = {};
  const value: Deps = {
    userRpc: (fn) => {
      calls.push(fn);
      return Promise.resolve(
        fn === "remove_my_payment_method"
          ? [{ stripe_account_id: "acct_1", provider_method_id: "pm_1" }]
          : [{
            club_membership_id: "cm-marta",
            stripe_account_id: "acct_1",
            stripe_customer_id: customer,
            member_email: "marta@example.com",
          }],
      );
    },
    stripe: {
      createCustomer: (account) => {
        calls.push(`customer@${account}`);
        return Promise.resolve({ id: "cus_new" });
      },
      createSetupSession: (account, params) => {
        calls.push(`setup@${account}`);
        setup = params;
        return Promise.resolve({ id: "cs_setup", url: "https://checkout.stripe.test/setup" });
      },
      detach: (account, method) => {
        calls.push(`detach ${method}@${account}`);
        return Promise.resolve({});
      },
    },
    appUrl: "https://socios.example",
  };
  return { value, calls, setup: () => setup };
}

Deno.test("saving a method without paying opens a setup Checkout", async () => {
  const { value, calls, setup } = deps();
  assertEquals(await handle({ clubId: "c", action: "setup" }, value), { url: "https://checkout.stripe.test/setup" });
  assertEquals(calls, ["prepare_payment_method_setup", "customer@acct_1", "setup@acct_1"]);
  assertEquals(setup().mode, "setup");
  assertEquals(setup().customer, "cus_new");
  assertEquals((setup().metadata as Record<string, string>).save_method, "true");
});

Deno.test("an existing customer is reused", async () => {
  const { value, calls } = deps("cus_marta");
  await handle({ clubId: "c", action: "setup" }, value);
  assertEquals(calls.includes("customer@acct_1"), false);
});

Deno.test("removing the method detaches it in Stripe", async () => {
  const { value, calls } = deps();
  assertEquals(await handle({ clubId: "c", action: "remove" }, value), { removed: true });
  assertEquals(calls, ["remove_my_payment_method", "detach pm_1@acct_1"]);
});

Deno.test("removing still works if Stripe fails or is not configured", async () => {
  const failing = deps().value;
  failing.stripe = { ...failing.stripe!, detach: () => Promise.reject(new Error("down")) };
  assertEquals(await handle({ clubId: "c", action: "remove" }, failing), { removed: true });
  assertEquals(await handle({ clubId: "c", action: "remove" }, { ...deps().value, stripe: null }), { removed: true });
  const error = await assertRejects(
    () => handle({ clubId: "c", action: "setup" }, { ...deps().value, stripe: null }),
    HttpError,
  );
  assertEquals(error.code, "payments_not_configured");
});
