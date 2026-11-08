import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { formEncode, SignatureError, signPayload, stripeRequest, verifyWebhook } from "./stripe.ts";

Deno.test("form-encodes nested params like Stripe", () => {
  assertEquals(
    formEncode({ mode: "payment", line_items: [{ quantity: 1 }], metadata: { payment_id: "p 1" }, skip: undefined }),
    "mode=payment&line_items%5B0%5D%5Bquantity%5D=1&metadata%5Bpayment_id%5D=p%201",
  );
});

Deno.test("sends requests on behalf of the connected account", async () => {
  let seen: Request | undefined;
  const result = await stripeRequest<{ id: string }>(
    {
      secretKey: "sk_test_x",
      fetcher: (input, init) => {
        seen = new Request(input as string, init);
        return Promise.resolve(Response.json({ id: "cs_1" }));
      },
    },
    "POST",
    "/v1/checkout/sessions",
    { mode: "payment" },
    "acct_1",
  );
  assertEquals(result.id, "cs_1");
  assertEquals(seen?.headers.get("Stripe-Account"), "acct_1");
  assertEquals(seen?.headers.get("Authorization"), "Bearer sk_test_x");
});

Deno.test("accepts a correctly signed webhook", async () => {
  const payload = JSON.stringify({ id: "evt_1", type: "checkout.session.completed", data: { object: {} } });
  const header = await signPayload(payload, "whsec_test", 1000);
  const event = await verifyWebhook(payload, header, "whsec_test", 1010);
  assertEquals(event.id, "evt_1");
});

Deno.test("rejects missing, forged, tampered and old signatures", async () => {
  const payload = JSON.stringify({ id: "evt_1" });
  const header = await signPayload(payload, "whsec_test", 1000);
  await assertRejects(() => verifyWebhook(payload, null, "whsec_test", 1000), SignatureError);
  await assertRejects(() => verifyWebhook(payload, header, "whsec_other", 1000), SignatureError);
  await assertRejects(() => verifyWebhook(payload + " ", header, "whsec_test", 1000), SignatureError);
  await assertRejects(() => verifyWebhook(payload, header, "whsec_test", 2000), SignatureError);
  await assertRejects(() => verifyWebhook(payload, "t=1000", "whsec_test", 1000), SignatureError);
});
