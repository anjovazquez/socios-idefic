// Minimal Stripe REST client and webhook signature check (ADR-001), with no
// npm dependencies at runtime. Charges go to the club's connected account
// (`Stripe-Account` header, direct charges, no platform fee).

type Fetch = typeof fetch;

export interface StripeOptions {
  secretKey: string;
  apiUrl?: string;
  fetcher?: Fetch;
}

export class StripeError extends Error {
  constructor(readonly status: number, readonly code: string | undefined, message: string) {
    super(message);
  }
}

/** `{ a: { b: 1 }, c: [x, y] }` → `a[b]=1&c[0]=x&c[1]=y` (Stripe form format). */
export function formEncode(params: Record<string, unknown>): string {
  const pairs: string[] = [];
  const add = (key: string, value: unknown) => {
    if (value === undefined || value === null) return;
    if (Array.isArray(value)) {
      value.forEach((item, index) => add(`${key}[${index}]`, item));
    } else if (typeof value === "object") {
      for (const [child, nested] of Object.entries(value as Record<string, unknown>)) {
        add(`${key}[${child}]`, nested);
      }
    } else {
      pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
    }
  };
  for (const [key, value] of Object.entries(params)) add(key, value);
  return pairs.join("&");
}

export async function stripeRequest<T>(
  options: StripeOptions,
  method: "GET" | "POST",
  path: string,
  params: Record<string, unknown> = {},
  account?: string,
): Promise<T> {
  const body = method === "POST" ? formEncode(params) : undefined;
  const query = method === "GET" && Object.keys(params).length ? `?${formEncode(params)}` : "";
  const headers: Record<string, string> = {
    Authorization: `Bearer ${options.secretKey}`,
    "Content-Type": "application/x-www-form-urlencoded",
    "Stripe-Version": "2024-06-20",
  };
  if (account) headers["Stripe-Account"] = account;
  const response = await (options.fetcher ?? fetch)(
    `${options.apiUrl ?? "https://api.stripe.com"}${path}${query}`,
    { method, headers, body },
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = (payload as { error?: { code?: string; message?: string } }).error ?? {};
    throw new StripeError(response.status, error.code, error.message ?? "stripe request failed");
  }
  return payload as T;
}

export interface StripeEvent {
  id: string;
  type: string;
  account?: string;
  data: { object: Record<string, unknown> };
}

export class SignatureError extends Error {}

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return [...new Uint8Array(signature)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Checks the `Stripe-Signature` header (`t=…,v1=…`) of the raw body and
 * returns the event. Rejects unsigned, forged and old (> tolerance) events.
 */
export async function verifyWebhook(
  payload: string,
  header: string | null,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
  toleranceSeconds = 300,
): Promise<StripeEvent> {
  if (!header || !secret) throw new SignatureError("missing signature");
  const parts = header.split(",").map((part) => part.trim().split("="));
  const timestamp = Number(parts.find(([k]) => k === "t")?.[1]);
  const signatures = parts.filter(([k]) => k === "v1").map(([, v]) => v ?? "");
  if (!Number.isFinite(timestamp) || signatures.length === 0) {
    throw new SignatureError("malformed signature");
  }
  if (Math.abs(nowSeconds - timestamp) > toleranceSeconds) {
    throw new SignatureError("timestamp outside tolerance");
  }
  const expected = await hmacHex(secret, `${timestamp}.${payload}`);
  if (!signatures.some((signature) => safeEqual(signature, expected))) {
    throw new SignatureError("signature mismatch");
  }
  return JSON.parse(payload) as StripeEvent;
}

/** Builds a valid `Stripe-Signature` header (tests and local simulation). */
export async function signPayload(payload: string, secret: string, timestamp: number): Promise<string> {
  return `t=${timestamp},v1=${await hmacHex(secret, `${timestamp}.${payload}`)}`;
}
