// Branded transactional emails (§20: communications carry the club identity).

import type { EmailMessage } from "./mailer.ts";

export interface ClubIdentity {
  name: string;
  logoUrl?: string | null;
  primaryColor?: string | null;
}

export type InvitationKind = "new_account" | "added_to_club";

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** Black or white, whichever reads better on [hex] (WCAG luminance). */
export function readableOn(hex: string): string {
  const value = hex.replace("#", "");
  const channel = (offset: number) => {
    const c = parseInt(value.substring(offset, offset + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  const luminance = 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4);
  const contrastWhite = 1.05 / (luminance + 0.05);
  const contrastDark = (luminance + 0.05) / (0.0067 + 0.05);
  return contrastWhite >= contrastDark ? "#FFFFFF" : "#111111";
}

export function invitationEmail(params: {
  kind: InvitationKind;
  club: ClubIdentity;
  to: { email: string; name?: string };
  link: string;
}): EmailMessage {
  const { kind, club, to, link } = params;
  const color = /^#[0-9A-Fa-f]{6}$/.test(club.primaryColor ?? "")
    ? club.primaryColor!
    : "#0B3D91";
  const onColor = readableOn(color);
  const clubName = escapeHtml(club.name);
  const greeting = to.name ? `Hola, ${escapeHtml(to.name)}` : "Hola";
  const isNew = kind === "new_account";

  const subject = isNew
    ? `${club.name} te invita a hacerte socio`
    : `Ahora también eres socio de ${club.name}`;
  const intro = isNew
    ? `${clubName} te ha dado de alta como socio. Activa tu cuenta para ver tu carnet, las noticias del club y tus ventajas.`
    : `${clubName} te ha dado de alta como socio. Entra con tu cuenta de siempre y lo verás junto a tus otros clubes.`;
  const action = isNew ? "Activar mi cuenta" : "Entrar";
  const note = isNew
    ? "El enlace caduca en 24 horas. Si caduca, pide a tu club que te lo reenvíe."
    : "No necesitas crear otra cuenta: usa el mismo email y contraseña.";

  const logo = club.logoUrl
    ? `<img src="${escapeHtml(club.logoUrl)}" alt="${clubName}" width="56" height="56" style="border-radius:28px;background:#FFFFFF;display:block;margin:0 auto 8px">`
    : "";

  const html = `<!doctype html>
<html lang="es"><body style="margin:0;background:#F4F5F7;font-family:Arial,Helvetica,sans-serif;color:#111111">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#FFFFFF;border-radius:12px;overflow:hidden">
<tr><td align="center" style="background:${color};color:${onColor};padding:24px 16px">${logo}<div style="font-size:20px;font-weight:bold">${clubName}</div></td></tr>
<tr><td style="padding:24px">
<p style="font-size:16px;margin:0 0 12px">${greeting}:</p>
<p style="font-size:15px;line-height:1.5;margin:0 0 24px">${intro}</p>
<p style="text-align:center;margin:0 0 24px"><a href="${escapeHtml(link)}" style="background:${color};color:${onColor};padding:12px 24px;border-radius:24px;text-decoration:none;font-weight:bold;display:inline-block">${action}</a></p>
<p style="font-size:13px;color:#555555;margin:0">${note}</p>
</td></tr></table>
<p style="font-size:12px;color:#777777;margin:16px 0 0">Recibes este email porque ${clubName} te ha dado de alta como socio.</p>
</td></tr></table></body></html>`;

  const text = [
    `${isNew ? greeting : greeting}:`,
    "",
    intro.replaceAll(clubName, club.name),
    "",
    `${action}: ${link}`,
    "",
    note,
  ].join("\n");

  return { to, subject, html, text };
}
