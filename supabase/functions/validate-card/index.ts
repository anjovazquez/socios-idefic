// VS-016: public validation of a membership card QR (RF-020, RN-017).
// Opened by whoever scans the QR (no session). Returns only: club, photo
// (signed for 2 minutes), name, member number, season and the card state.
// Never phone, email, birth date or payments.
//
// POST { token } (or GET ?token=…) →
//   { state: "active" | "not_current", club, member, seasonName }
//   { state: "not_found" }

import { rpc, signStorageUrl } from "../_shared/supabase_rest.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

type Row = Record<string, unknown>;

export interface ValidationBackend {
  validate(token: string): Promise<Row[]>;
  signPhoto(path: string): Promise<string | null>;
  logoUrl(path: string): string;
}

export interface Validation {
  state: "active" | "not_current" | "not_found";
  club?: { name: string; logoUrl: string | null; primaryColor: string | null };
  member?: {
    firstName: string | null;
    lastName: string | null;
    photoUrl: string | null;
    memberNumber: number | null;
  };
  seasonName?: string | null;
}

/** Tokens are 22 url-safe characters; anything else is not looked up. */
export function isPlausibleToken(token: string | null | undefined): token is string {
  return typeof token === "string" && /^[A-Za-z0-9_-]{16,64}$/.test(token);
}

export async function validate(token: string | null | undefined, backend: ValidationBackend): Promise<Validation> {
  if (!isPlausibleToken(token)) return { state: "not_found" };
  const [row] = await backend.validate(token);
  if (!row) return { state: "not_found" };
  const photoPath = row.photo_path as string | null;
  const logoPath = row.club_logo_path as string | null;
  return {
    state: row.state === "active" ? "active" : "not_current",
    club: {
      name: row.club_name as string,
      logoUrl: logoPath ? backend.logoUrl(logoPath) : null,
      primaryColor: (row.club_primary_color as string | null) ?? null,
    },
    member: {
      firstName: (row.first_name as string | null) ?? null,
      lastName: (row.last_name as string | null) ?? null,
      photoUrl: photoPath ? await backend.signPhoto(photoPath) : null,
      memberNumber: (row.member_number as number | null) ?? null,
    },
    seasonName: (row.season_name as string | null) ?? null,
  };
}

function httpBackend(env: (key: string) => string | undefined): ValidationBackend {
  const url = env("SUPABASE_URL")!;
  const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY")!;
  const publicUrl = env("PUBLIC_SUPABASE_URL") ?? url;
  return {
    validate: (token) =>
      rpc<Row[]>({ url, apiKey: serviceKey, bearer: `Bearer ${serviceKey}` }, "validate_card", {
        p_token: token,
      }),
    signPhoto: (path) => signStorageUrl({ url, serviceKey, publicUrl }, "profile-photos", path, 120),
    logoUrl: (path) => `${publicUrl}/storage/v1/object/public/club-assets/${path}`,
  };
}

function json(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

if (import.meta.main) {
  Deno.serve(async (request) => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    try {
      const token = request.method === "GET"
        ? new URL(request.url).searchParams.get("token")
        : ((await request.json().catch(() => ({}))) as { token?: string }).token;
      return json(200, await validate(token, httpBackend((key) => Deno.env.get(key))));
    } catch (error) {
      console.error("validate-card failed", error);
      return json(500, { error: "unavailable" });
    }
  });
}
