# Despliegue y secretos

Nada de esto se ejecuta sin aprobación explícita del usuario (ver `AGENTS.md`).
El pipeline de staging llega en VS-033.

## Edge Functions

| Función | Desde | Qué hace |
|---|---|---|
| `invite-member` | VS-006 | Alta de socio y reenvío de invitación (GoTrue `generate_link` + email) |

Secretos de función (`supabase secrets set ...`, nunca en el repo):

| Secreto | Ejemplo | Uso |
|---|---|---|
| `RESEND_API_KEY` | `re_...` | Envío de emails con Resend (D-013). Sin él se usa Mailpit (local) o consola |
| `MAIL_FROM` | `Socios IDEFIC <socios@tu-dominio.es>` | Remitente; el dominio debe estar verificado en Resend |
| `APP_URL` | `https://socios.tu-dominio.es` | Destino de los enlaces de los emails; debe estar en *Redirect URLs* de Auth |
| `PUBLIC_SUPABASE_URL` | `https://<ref>.supabase.co` | URL pública para logos en los emails |

`SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` los inyecta
Supabase automáticamente.

En local, los valores están en `[edge_runtime.secrets]` de
`supabase/config.toml` y los emails se ven en Mailpit
(`http://127.0.0.1:54324`).

## Auth

- `enable_signup = false` (sin registro público).
- Caducidad de enlaces de email: 24 h (`otp_expiry = 86400`).
- Google: ver `docs/AUTH_GOOGLE.md`.
