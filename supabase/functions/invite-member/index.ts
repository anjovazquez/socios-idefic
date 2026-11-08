// VS-006: the club admin signs up a member and the member gets an email
// invitation with the club identity (RF-002, RF-003, RF-004).
//
// POST { action: "invite", clubId, email, firstName }
// POST { action: "resend", membershipId }
// → 200 { status: "invited" | "added", membershipId }

import { invitationEmail } from "../_shared/emails.ts";
import { type Mailer, mailerFromEnv } from "../_shared/mailer.ts";
import { generateLink, rpc, type RpcError, RpcFailure } from "../_shared/supabase_rest.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export type Body =
  | { action: "invite"; clubId: string; email: string; firstName: string }
  | { action: "resend"; membershipId: string };

type Row = Record<string, unknown>;

/** What the function needs from Supabase; faked in tests. */
export interface Backend {
  /** RPC as the calling user (permissions checked by the database). */
  userRpc(fn: string, params: Row): Promise<Row[]>;
  /** RPC with the service role (server-only steps). */
  serviceRpc<T>(fn: string, params: Row): Promise<T>;
  /** Creates or refreshes the auth user and returns a new sign-in link. */
  accessLink(email: string, firstName: string, redirectTo: string): Promise<{ userId: string; link: string }>;
}

export interface Deps {
  backend: Backend;
  mailer: Mailer;
  appUrl: string;
  publicSupabaseUrl: string;
}

export class HttpError extends Error {
  constructor(readonly status: number, readonly code: string) {
    super(code);
  }
}

/** Maps a PostgREST error from the RPCs to an HTTP error for the app. */
export function rpcError(error: RpcError): HttpError {
  switch (error.code) {
    case "42501":
      return new HttpError(403, "forbidden");
    case "22023":
      return new HttpError(400, (error.message ?? "").includes("email") ? "invalid_email" : "invalid_name");
    case "P0001":
      return new HttpError(409, error.hint ?? "conflict");
    default:
      return new HttpError(500, "unavailable");
  }
}

async function guard<T>(action: () => Promise<T>): Promise<T> {
  try {
    return await action();
  } catch (error) {
    if (error instanceof RpcFailure) throw rpcError(error.error);
    throw error;
  }
}

function clubOf(deps: Deps, row: Row) {
  const path = row.club_logo_path as string | null;
  return {
    name: row.club_name as string,
    logoUrl: path ? `${deps.publicSupabaseUrl}/storage/v1/object/public/club-assets/${path}` : null,
    primaryColor: row.club_primary_color as string | null,
  };
}

async function attach(deps: Deps, invitationId: string, userId: string, status: "invited" | "active") {
  return await guard(() =>
    deps.backend.serviceRpc<string>("attach_invited_member", {
      p_invitation_id: invitationId,
      p_user_id: userId,
      p_status: status,
    })
  );
}

async function sendAccess(deps: Deps, row: Row) {
  const email = row.email as string;
  const firstName = (row.first_name as string | null) ?? "";
  const access = await deps.backend.accessLink(email, firstName, deps.appUrl);
  const membershipId = await attach(deps, row.invitation_id as string, access.userId, "invited");
  await deps.mailer.send(
    invitationEmail({
      kind: "new_account",
      club: clubOf(deps, row),
      to: { email, name: firstName || undefined },
      link: access.link,
    }),
  );
  return { status: "invited", membershipId };
}

export async function handle(body: Body, deps: Deps) {
  if (body.action === "invite") {
    const [row] = await guard(() =>
      deps.backend.userRpc("prepare_member_invitation", {
        p_club_id: body.clubId,
        p_email: body.email,
        p_first_name: body.firstName,
      })
    );
    if (row.existing_user_id && row.existing_user_active) {
      // Same account, one more club (RF-004): no new credentials.
      const membershipId = await attach(
        deps,
        row.invitation_id as string,
        row.existing_user_id as string,
        "active",
      );
      await deps.mailer.send(
        invitationEmail({
          kind: "added_to_club",
          club: clubOf(deps, row),
          to: { email: row.email as string, name: row.first_name as string },
          link: deps.appUrl,
        }),
      );
      return { status: "added", membershipId };
    }
    return await sendAccess(deps, row);
  }

  if (body.action === "resend") {
    const rows = await guard(() =>
      deps.backend.userRpc("prepare_invitation_resend", { p_membership_id: body.membershipId })
    );
    if (rows.length === 0) throw new HttpError(409, "not_pending");
    return await sendAccess(deps, rows[0]);
  }

  throw new HttpError(400, "invalid_action");
}

export function httpBackend(env: (key: string) => string | undefined, authorization: string): Backend {
  const url = env("SUPABASE_URL")!;
  const anonKey = env("SUPABASE_ANON_KEY")!;
  const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY")!;
  return {
    userRpc: (fn, params) => rpc<Row[]>({ url, apiKey: anonKey, bearer: authorization }, fn, params),
    serviceRpc: (fn, params) => rpc({ url, apiKey: serviceKey, bearer: `Bearer ${serviceKey}` }, fn, params),
    async accessLink(email, firstName, redirectTo) {
      try {
        return await generateLink({ url, serviceKey }, {
          type: "invite",
          email,
          data: { first_name: firstName },
          redirectTo,
        });
      } catch {
        // Already registered but never activated: a new magic link replaces
        // the previous one, so older links stop working.
        return await generateLink({ url, serviceKey }, { type: "magiclink", email, redirectTo });
      }
    },
  };
}

function json(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

if (import.meta.main) {
  Deno.serve(async (request) => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (request.method !== "POST") return json(405, { error: "method_not_allowed" });

    const authorization = request.headers.get("Authorization");
    if (!authorization) return json(401, { error: "unauthorized" });

    const env = (key: string) => Deno.env.get(key);
    const deps: Deps = {
      backend: httpBackend(env, authorization),
      mailer: mailerFromEnv(env),
      appUrl: env("APP_URL") ?? "http://localhost:3000",
      publicSupabaseUrl: env("PUBLIC_SUPABASE_URL") ?? env("SUPABASE_URL")!,
    };

    try {
      const body = (await request.json()) as Body;
      return json(200, await handle(body, deps));
    } catch (error) {
      if (error instanceof HttpError) return json(error.status, { error: error.code });
      console.error("invite-member failed", error);
      return json(500, { error: "unavailable" });
    }
  });
}
