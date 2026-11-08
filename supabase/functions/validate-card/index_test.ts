import { assertEquals } from "jsr:@std/assert@1";

import { isPlausibleToken, validate, type ValidationBackend } from "./index.ts";

function backend(rows: Record<string, unknown>[]): ValidationBackend & { lookups: string[] } {
  const lookups: string[] = [];
  return {
    lookups,
    validate(token) {
      lookups.push(token);
      return Promise.resolve(rows);
    },
    signPhoto: (path) => Promise.resolve(`https://signed/${path}`),
    logoUrl: (path) => `https://public/${path}`,
  };
}

const row = {
  state: "active",
  club_name: "IDEFIC",
  club_logo_path: "c1/logo.png",
  club_primary_color: "#0B3D91",
  first_name: "Ana",
  last_name: "Pérez",
  photo_path: "u1/photo.jpg",
  member_number: 2,
  season_name: "2026/2027",
  // Even if the database returned more, only RF-020 data goes out.
  phone: "600000000",
  email: "ana@example.com",
};

Deno.test("an active card returns only the allowed data", async () => {
  const result = await validate("abcdefghijklmnopqrstuv", backend([row]));

  assertEquals(result, {
    state: "active",
    club: { name: "IDEFIC", logoUrl: "https://public/c1/logo.png", primaryColor: "#0B3D91" },
    member: { firstName: "Ana", lastName: "Pérez", photoUrl: "https://signed/u1/photo.jpg", memberNumber: 2 },
    seasonName: "2026/2027",
  });
  assertEquals(JSON.stringify(result).includes("600000000"), false);
  assertEquals(JSON.stringify(result).includes("@"), false);
});

Deno.test("a card of another season is not current", async () => {
  const result = await validate("abcdefghijklmnopqrstuv", backend([{ ...row, state: "not_current" }]));
  assertEquals(result.state, "not_current");
});

Deno.test("unknown or malformed tokens are not found and not looked up", async () => {
  const b = backend([]);
  assertEquals((await validate("abcdefghijklmnopqrstuv", b)).state, "not_found");
  assertEquals((await validate("abc123", b)).state, "not_found");
  assertEquals((await validate("'; drop table x;--xxxxxxx", b)).state, "not_found");
  assertEquals((await validate(null, b)).state, "not_found");
  assertEquals(b.lookups, ["abcdefghijklmnopqrstuv"]);
});

Deno.test("plausible tokens", () => {
  assertEquals(isPlausibleToken("Ab3_-cdefghijklmnopqrs"), true);
  assertEquals(isPlausibleToken("short"), false);
});
