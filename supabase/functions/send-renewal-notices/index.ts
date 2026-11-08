// VS-023: daily job (pg_cron → this function) that sends the notice before
// every automatic renewal charge (RF-013, RN-012). Each notice is claimed in
// `renewal_notices` before sending, so runs can repeat safely: one notice per
// renewal. Only the service role may call it.
//
// POST { today?: "YYYY-MM-DD" } → 200 { sent, failed }

import { renewalNoticeEmail } from "../_shared/emails.ts";
import { json } from "../_shared/http.ts";
import { type Mailer, mailerFromEnv } from "../_shared/mailer.ts";
import { rpc } from "../_shared/supabase_rest.ts";

type Row = Record<string, unknown>;

export interface Deps {
  serviceRpc<T>(fn: string, params: Row): Promise<T>;
  mailer: Mailer;
  appUrl: string;
  publicSupabaseUrl: string;
}

/** Today in Spain (the club calendar), `YYYY-MM-DD`. */
export function madridToday(now = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Madrid",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

export async function handle(body: { today?: string }, deps: Deps) {
  const today = body.today && /^\d{4}-\d{2}-\d{2}$/.test(body.today) ? body.today : madridToday();
  const due = await deps.serviceRpc<Row[]>("get_due_renewal_notices", { p_today: today });
  let sent = 0;
  let failed = 0;
  for (const row of due) {
    const claimed = await deps.serviceRpc<boolean>("claim_renewal_notice", {
      p_season_membership_id: row.season_membership_id,
      p_charge_on: row.charge_on,
      p_amount_cents: row.amount_cents,
      p_email: row.email,
    });
    if (!claimed) continue;
    const logoPath = row.club_logo_path as string | null;
    try {
      await deps.mailer.send(
        renewalNoticeEmail({
          club: {
            name: row.club_name as string,
            primaryColor: row.club_primary_color as string | null,
            logoUrl: logoPath ? `${deps.publicSupabaseUrl}/storage/v1/object/public/club-assets/${logoPath}` : null,
          },
          to: { email: row.email as string, name: (row.first_name as string | null) ?? undefined },
          seasonName: row.season_name as string,
          amountCents: row.amount_cents as number,
          chargeOn: row.charge_on as string,
          method: {
            kind: row.method_kind as string | null,
            brand: row.method_brand as string | null,
            last4: row.method_last4 as string | null,
          },
          link: `${deps.appUrl.replace(/\/$/, "")}/#/club/subscription`,
        }),
      );
      sent++;
    } catch (error) {
      // Not sent: free the claim so the next run retries it.
      console.error("renewal notice failed", row.email, error);
      await deps.serviceRpc("release_renewal_notice", { p_season_membership_id: row.season_membership_id });
      failed++;
    }
  }
  return { today, sent, failed };
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
    try {
      const body = await request.json().catch(() => ({}));
      return json(
        200,
        await handle(body, {
          serviceRpc: (fn, params) => rpc({ url, apiKey: serviceKey, bearer: `Bearer ${serviceKey}` }, fn, params),
          mailer: mailerFromEnv(env),
          appUrl: env("APP_URL") ?? "http://localhost:3000",
          publicSupabaseUrl: env("PUBLIC_SUPABASE_URL") ?? url,
        }),
      );
    } catch (error) {
      console.error("send-renewal-notices failed", error);
      return json(500, { error: "unavailable" });
    }
  });
}
