// Minimal Supabase access over HTTP (no npm dependencies at runtime).

export interface RpcError {
  code?: string;
  message?: string;
  hint?: string;
}

export class RpcFailure extends Error {
  constructor(readonly error: RpcError) {
    super(error.message ?? error.code ?? "rpc failed");
  }
}

type Fetch = typeof fetch;

/** Calls `/rest/v1/rpc/<fn>` with the given bearer (user JWT or service key). */
export async function rpc<T>(
  options: { url: string; apiKey: string; bearer: string; fetcher?: Fetch },
  fn: string,
  params: Record<string, unknown>,
): Promise<T> {
  const response = await (options.fetcher ?? fetch)(`${options.url}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      apikey: options.apiKey,
      Authorization: options.bearer,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(params),
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) throw new RpcFailure((payload ?? {}) as RpcError);
  return payload as T;
}

export interface GeneratedLink {
  userId: string;
  link: string;
}

/** GoTrue admin `generate_link` (service role only). */
export async function generateLink(
  options: { url: string; serviceKey: string; fetcher?: Fetch },
  params: { type: "invite" | "magiclink"; email: string; data?: Record<string, unknown>; redirectTo: string },
): Promise<GeneratedLink> {
  const response = await (options.fetcher ?? fetch)(`${options.url}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: {
      apikey: options.serviceKey,
      Authorization: `Bearer ${options.serviceKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      type: params.type,
      email: params.email,
      data: params.data,
      redirect_to: params.redirectTo,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`generate_link ${response.status}: ${JSON.stringify(payload)}`);
  }
  const user = payload.user ?? payload;
  return { userId: user.id as string, link: payload.action_link as string };
}
