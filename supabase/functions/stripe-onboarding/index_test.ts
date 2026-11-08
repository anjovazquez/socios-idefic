import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { HttpError } from "../_shared/http.ts";
import { RpcFailure } from "../_shared/supabase_rest.ts";
import { type Deps, handle } from "./index.ts";

function deps(accountId: string | null, chargesEnabled = false) {
  const calls: { fn: string; params: Record<string, unknown> }[] = [];
  const value: Deps = {
    userRpc: () => Promise.resolve([{ stripe_account_id: accountId, charges_enabled: chargesEnabled }]),
    serviceRpc: (fn, params) => {
      calls.push({ fn, params });
      return Promise.resolve(null);
    },
    stripe: {
      create: () => Promise.resolve({ id: "acct_new" }),
      retrieve: (id) => Promise.resolve({ id, charges_enabled: true }),
      onboardingLink: (id, returnUrl) => Promise.resolve({ url: `https://connect.stripe.com/${id}?r=${returnUrl}` }),
    },
    appUrl: "https://socios.example",
  };
  return { value, calls };
}

Deno.test("creates the club account once and returns the onboarding link", async () => {
  const { value, calls } = deps(null);
  const result = await handle({ clubId: "club-1" }, value);
  assertEquals(result, {
    url: "https://connect.stripe.com/acct_new?r=https://socios.example/#/club/settings?stripe=volver",
  });
  assertEquals(calls, [{
    fn: "set_club_stripe_account",
    params: { p_club_id: "club-1", p_account_id: "acct_new", p_charges_enabled: false },
  }]);
});

Deno.test("an existing account only gets a new link", async () => {
  const { value, calls } = deps("acct_old");
  await handle({ clubId: "club-1" }, value);
  assertEquals(calls.length, 0);
});

Deno.test("refresh stores whether the account can charge", async () => {
  const { value, calls } = deps("acct_old");
  assertEquals(await handle({ clubId: "club-1", action: "refresh" }, value), {
    accountId: "acct_old",
    chargesEnabled: true,
  });
  assertEquals(calls[0].params.p_charges_enabled, true);
});

Deno.test("only the club admin, and only with Stripe configured", async () => {
  const forbidden = deps(null).value;
  forbidden.userRpc = () => Promise.reject(new RpcFailure({ code: "42501" }));
  assertEquals((await assertRejects(() => handle({ clubId: "c" }, forbidden), HttpError)).status, 403);
  const unconfigured = { ...deps(null).value, stripe: null };
  assertEquals((await assertRejects(() => handle({ clubId: "c" }, unconfigured), HttpError)).code, "payments_not_configured");
});
