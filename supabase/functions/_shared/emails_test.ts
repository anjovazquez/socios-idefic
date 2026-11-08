import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import { escapeHtml, invitationEmail, readableOn } from "./emails.ts";
import { ConsoleMailer, MailpitMailer, mailerFromEnv, parseAddress, ResendMailer } from "./mailer.ts";

Deno.test("invitation for a new account carries the club identity and the link", () => {
  const email = invitationEmail({
    kind: "new_account",
    club: { name: "IDEFIC", logoUrl: "https://cdn/logo.png", primaryColor: "#B3261E" },
    to: { email: "marta@example.com", name: "Marta" },
    link: "https://auth/verify?token=abc&type=invite",
  });

  assertEquals(email.subject, "IDEFIC te invita a hacerte socio");
  assertStringIncludes(email.html, "background:#B3261E");
  assertStringIncludes(email.html, 'src="https://cdn/logo.png"');
  assertStringIncludes(email.html, "token=abc&amp;type=invite");
  assertStringIncludes(email.html, "Activar mi cuenta");
  assertStringIncludes(email.text, "https://auth/verify?token=abc&type=invite");
  assertStringIncludes(email.text, "24 horas");
});

Deno.test("existing accounts get the 'also a member' email", () => {
  const email = invitationEmail({
    kind: "added_to_club",
    club: { name: "Club Demo" },
    to: { email: "luis@example.com" },
    link: "http://localhost:3000",
  });
  assertEquals(email.subject, "Ahora también eres socio de Club Demo");
  assertStringIncludes(email.html, "background:#0B3D91");
});

Deno.test("names are escaped", () => {
  const email = invitationEmail({
    kind: "new_account",
    club: { name: "<b>Club</b>" },
    to: { email: "x@example.com", name: "<script>" },
    link: "http://x",
  });
  assert(!email.html.includes("<script>"));
  assertEquals(escapeHtml(`"a"&'b'`), "&quot;a&quot;&amp;&#39;b&#39;");
});

Deno.test("text color reads on the club color", () => {
  assertEquals(readableOn("#0B3D91"), "#FFFFFF");
  assertEquals(readableOn("#FFF59D"), "#111111");
});

Deno.test("mailer selection: Resend, then Mailpit, then console", () => {
  assert(mailerFromEnv((k) => ({ RESEND_API_KEY: "re_x", MAILPIT_URL: "http://m" } as Record<string, string>)[k]) instanceof ResendMailer);
  assert(mailerFromEnv((k) => ({ MAILPIT_URL: "http://m" } as Record<string, string>)[k]) instanceof MailpitMailer);
  assert(mailerFromEnv(() => undefined) instanceof ConsoleMailer);
});

Deno.test("Resend request shape", async () => {
  let captured: { url: string; init: RequestInit } | undefined;
  const fake = ((url: string, init: RequestInit) => {
    captured = { url, init };
    return Promise.resolve(new Response("{}", { status: 200 }));
  }) as typeof fetch;
  await new ResendMailer("re_key", "Socios <no-reply@x.es>", fake).send({
    to: { email: "a@b.es", name: "Ana" },
    subject: "S",
    html: "<p>h</p>",
    text: "t",
  });
  assertEquals(captured!.url, "https://api.resend.com/emails");
  assertEquals((captured!.init.headers as Record<string, string>).Authorization, "Bearer re_key");
  const body = JSON.parse(captured!.init.body as string);
  assertEquals(body.to, ["Ana <a@b.es>"]);
  assertEquals(body.from, "Socios <no-reply@x.es>");
});

Deno.test("parses addresses", () => {
  assertEquals(parseAddress("Socios <no-reply@x.es>"), { name: "Socios", email: "no-reply@x.es" });
  assertEquals(parseAddress("a@b.es"), { email: "a@b.es" });
});

Deno.test("renewal notice: season, amount, charge date and how to cancel", async () => {
  const { renewalNoticeEmail, longSpanishDate, euros } = await import("./emails.ts");
  const email = renewalNoticeEmail({
    club: { name: "IDEFIC", primaryColor: "#0B3D91" },
    to: { email: "marta@example.com", name: "Marta" },
    seasonName: "2027/2028",
    amountCents: 5000,
    chargeOn: "2027-09-01",
    method: { kind: "card", brand: "visa", last4: "4242" },
    link: "https://socios.example/#/club/subscription",
  });
  assertStringIncludes(
    email.text,
    "Tu suscripción a IDEFIC se renovará para la temporada 2027/2028 por un importe de 50 €. " +
      "El cargo se realizará el 1 de septiembre de 2027 en tu tarjeta Visa terminada en 4242.",
  );
  assertStringIncludes(email.text, "Puedes cancelar la renovación antes de esa fecha");
  assertStringIncludes(email.html, "https://socios.example/#/club/subscription");
  assertEquals(email.subject, "Tu suscripción a IDEFIC se renueva el 1 de septiembre de 2027");
  assertEquals(longSpanishDate("2028-02-29"), "29 de febrero de 2028");
  assertEquals(euros(125050), "1.250,50 €");
});
