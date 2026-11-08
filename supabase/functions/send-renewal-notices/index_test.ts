import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { EmailMessage, Mailer } from "../_shared/mailer.ts";
import { type Deps, handle, madridToday } from "./index.ts";

const marta = {
  season_membership_id: "sm-marta",
  email: "marta@example.com",
  first_name: "Marta",
  club_name: "IDEFIC",
  club_primary_color: "#0B3D91",
  club_logo_path: null,
  season_name: "2027/2028",
  amount_cents: 5000,
  charge_on: "2027-09-01",
  method_kind: "card",
  method_brand: "visa",
  method_last4: "4242",
};

/** Fake database with the same claim rules as renewal_notices. */
function fake(options: { failSend?: boolean } = {}) {
  const claimed = new Set<string>();
  const released: string[] = [];
  const sent: EmailMessage[] = [];
  const mailer: Mailer = {
    send: (message) => {
      if (options.failSend) return Promise.reject(new Error("smtp down"));
      sent.push(message);
      return Promise.resolve();
    },
  };
  const deps: Deps = {
    serviceRpc: <T>(fn: string, params: Record<string, unknown>) => {
      if (fn === "get_due_renewal_notices") {
        return Promise.resolve((claimed.has("sm-marta") ? [] : [marta]) as T);
      }
      if (fn === "claim_renewal_notice") {
        const id = params.p_season_membership_id as string;
        const fresh = !claimed.has(id);
        claimed.add(id);
        return Promise.resolve(fresh as T);
      }
      if (fn === "release_renewal_notice") {
        const id = params.p_season_membership_id as string;
        claimed.delete(id);
        released.push(id);
      }
      return Promise.resolve(null as T);
    },
    mailer,
    appUrl: "https://socios.example",
    publicSupabaseUrl: "https://ref.supabase.co",
  };
  return { deps, sent, released };
}

Deno.test("on the notice date Marta receives the notice", async () => {
  const { deps, sent } = fake();
  const result = await handle({ today: "2027-08-17" }, deps);
  assertEquals(result, { today: "2027-08-17", sent: 1, failed: 0 });
  assertEquals(sent[0].to.email, "marta@example.com");
  assertStringIncludes(sent[0].text, "temporada 2027/2028 por un importe de 50 €");
  assertStringIncludes(sent[0].text, "1 de septiembre de 2027");
  assertStringIncludes(sent[0].text, "Puedes cancelar la renovación");
});

Deno.test("running the job several times sends a single notice", async () => {
  const { deps, sent } = fake();
  await handle({ today: "2027-08-17" }, deps);
  await handle({ today: "2027-08-17" }, deps);
  await handle({ today: "2027-08-18" }, deps);
  assertEquals(sent.length, 1);
});

Deno.test("a notice that cannot be sent is released for the next run", async () => {
  const { deps, released } = fake({ failSend: true });
  const result = await handle({ today: "2027-08-17" }, deps);
  assertEquals(result.failed, 1);
  assertEquals(released, ["sm-marta"]);
});

Deno.test("today follows the Madrid calendar", () => {
  // 23:30 UTC on 16 August is already 17 August in Madrid (UTC+2).
  assertEquals(madridToday(new Date("2027-08-16T23:30:00Z")), "2027-08-17");
});
