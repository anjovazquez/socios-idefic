import { assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert@1";

import { ConsoleMailer } from "../_shared/mailer.ts";
import { RpcFailure } from "../_shared/supabase_rest.ts";
import { type Backend, type Deps, handle, HttpError, rpcError } from "./index.ts";

function fakeDeps(rows: Record<string, Record<string, unknown>[]>, failure?: RpcFailure) {
  const calls: string[] = [];
  const mailer = new ConsoleMailer();
  const backend: Backend = {
    userRpc(fn) {
      calls.push(fn);
      if (failure) return Promise.reject(failure);
      return Promise.resolve(rows[fn] ?? []);
    },
    serviceRpc<T>(fn: string, params: Record<string, unknown>) {
      calls.push(`${fn}:${params.p_status}`);
      return Promise.resolve("membership-1" as T);
    },
    accessLink(email) {
      calls.push(`link:${email}`);
      return Promise.resolve({ userId: "user-new", link: "http://auth/verify?token=t1" });
    },
  };
  const deps: Deps = {
    backend,
    mailer,
    appUrl: "http://app",
    publicSupabaseUrl: "http://sb",
  };
  return { deps, calls, mailer };
}

const club = { club_name: "IDEFIC", club_logo_path: "c1/logo.png", club_primary_color: "#B3261E" };

Deno.test("a new person gets an account, an invited membership and the email", async () => {
  const { deps, calls, mailer } = fakeDeps({
    prepare_member_invitation: [{
      invitation_id: "inv-1",
      email: "marta@example.com",
      first_name: "Marta",
      existing_user_id: null,
      existing_user_active: false,
      ...club,
    }],
  });

  const result = await handle(
    { action: "invite", clubId: "c1", email: "marta@example.com", firstName: "Marta" },
    deps,
  );

  assertEquals(result, { status: "invited", membershipId: "membership-1" });
  assertEquals(calls, ["prepare_member_invitation", "link:marta@example.com", "attach_invited_member:invited"]);
  assertEquals(mailer.sent[0].to.email, "marta@example.com");
  assertStringIncludes(mailer.sent[0].html, "http://auth/verify?token=t1");
  assertStringIncludes(mailer.sent[0].html, "http://sb/storage/v1/object/public/club-assets/c1/logo.png");
});

Deno.test("an existing active account joins directly without new credentials", async () => {
  const { deps, calls, mailer } = fakeDeps({
    prepare_member_invitation: [{
      invitation_id: "inv-2",
      email: "luis@example.com",
      first_name: "Luis",
      existing_user_id: "user-luis",
      existing_user_active: true,
      ...club,
    }],
  });

  const result = await handle(
    { action: "invite", clubId: "c1", email: "luis@example.com", firstName: "Luis" },
    deps,
  );

  assertEquals(result.status, "added");
  assertEquals(calls, ["prepare_member_invitation", "attach_invited_member:active"]);
  assertEquals(mailer.sent[0].subject, "Ahora también eres socio de IDEFIC");
});

Deno.test("resend issues a new link", async () => {
  const { deps, calls, mailer } = fakeDeps({
    prepare_invitation_resend: [{ invitation_id: "inv-1", email: "marta@example.com", first_name: "Marta", ...club }],
  });

  await handle({ action: "resend", membershipId: "m1" }, deps);

  assertEquals(calls, ["prepare_invitation_resend", "link:marta@example.com", "attach_invited_member:invited"]);
  assertEquals(mailer.sent.length, 1);
});

Deno.test("database refusals become HTTP errors", async () => {
  const { deps, mailer } = fakeDeps({}, new RpcFailure({ code: "42501", message: "club admin required" }));

  const error = await assertRejects(
    () => handle({ action: "invite", clubId: "c1", email: "x@example.com", firstName: "X" }, deps),
    HttpError,
  );
  assertEquals(error.status, 403);
  assertEquals(mailer.sent.length, 0);
});

Deno.test("maps RPC errors to HTTP errors", () => {
  assertEquals(rpcError({ code: "42501" }).status, 403);
  assertEquals(rpcError({ code: "22023", message: "invalid member email" }).code, "invalid_email");
  assertEquals(rpcError({ code: "22023", message: "member name required" }).code, "invalid_name");
  assertEquals(rpcError({ code: "P0001", hint: "already_member" }).code, "already_member");
  assertEquals(rpcError({ code: "XX000" }).status, 500);
});
