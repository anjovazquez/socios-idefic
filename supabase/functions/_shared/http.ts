// Shared HTTP helpers of the Edge Functions called by the app.
import { type RpcError, RpcFailure } from "./supabase_rest.ts";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class HttpError extends Error {
  constructor(readonly status: number, readonly code: string) {
    super(code);
  }
}

/** PostgREST error of an RPC → HTTP error for the app (403, 404, 409 <hint>). */
export function httpErrorOf(error: RpcError): HttpError {
  switch (error.code) {
    case "42501":
      return new HttpError(403, "forbidden");
    case "P0002":
      return new HttpError(404, "not_found");
    case "P0001":
      return new HttpError(409, error.hint ?? "conflict");
    default:
      return new HttpError(500, "unavailable");
  }
}

export async function guardRpc<T>(action: () => Promise<T>): Promise<T> {
  try {
    return await action();
  } catch (error) {
    if (error instanceof RpcFailure) throw httpErrorOf(error.error);
    throw error;
  }
}

export function json(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}
