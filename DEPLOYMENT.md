# Despliegue a staging

Arquitectura (igual que Xogalle):

```text
Navegador / móvil ──► Firebase Hosting (web Flutter)
                         │
                         ▼
                 Supabase Cloud (staging)
      Auth · Postgres + RLS · Storage · Edge Functions ──► Resend (emails)
```

El despliegue es **manual** desde GitHub Actions (`Socios CI/CD` →
*Run workflow*), con tres casillas independientes: `deploy_migrations`,
`deploy_functions` y `deploy_hosting`. Cada despliegue solo se ejecuta si sus
tests pasan (`sql-tests`, `edge-functions`, `quality`). Nunca se sube la seed
local.

---

## 1. Supabase (proyecto nuevo de staging)

1. Crea el proyecto en <https://supabase.com/dashboard> (región UE, p. ej.
   Frankfurt). Guarda la contraseña de la base de datos.
2. Anota de *Project Settings*:
   - **Project ref** (`abcdefghijklmnop`).
   - **Project URL** (`https://<ref>.supabase.co`).
   - **Publishable key** (*API Keys*).
   - **Connection string** → *Session pooler*, URI con la contraseña:
     `postgresql://postgres.<ref>:<password>@aws-0-eu-central-1.pooler.supabase.com:5432/postgres`.
3. Crea un **access token** personal en *Account → Access Tokens* (para
   desplegar funciones).

### Ajustes de Auth (en el dashboard; `config.toml` es solo local)

*Authentication → Sign In / Providers*:

- **Allow new users to sign up: OFF** (RN-001; los socios entran por invitación).
- Email: activado. *Email OTP expiration*: `86400` (24 h).
- Google: opcional, ver `docs/AUTH_GOOGLE.md`.

*Authentication → URL Configuration*:

- **Site URL**: `https://<firebase-project>.web.app`
- **Redirect URLs**: `https://<firebase-project>.web.app/**` y
  `es.idefic.socios://login-callback`.

### Secretos de las Edge Functions

*Edge Functions → Secrets* (o `supabase secrets set --project-ref <ref> …`):

| Secreto | Valor |
|---|---|
| `RESEND_API_KEY` | `re_…` (Resend → API Keys) |
| `MAIL_FROM` | `Socios IDEFIC <socios@tu-dominio.es>` (dominio verificado en Resend) |
| `APP_URL` | `https://<firebase-project>.web.app` |
| `PUBLIC_SUPABASE_URL` | `https://<ref>.supabase.co` |

`SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` los pone
Supabase. `validate-card` es pública (se despliega con `--no-verify-jwt`):
la abre quien escanea un QR y solo devuelve los datos de RF-020. Sin
`RESEND_API_KEY` las invitaciones no salen por email (solo
quedan en el log de la función).

## 2. Resend

1. Cuenta en <https://resend.com>, *Domains* → añade tu dominio y crea los
   registros DNS que indica (SPF/DKIM). Hasta verificarlo solo puedes enviar
   a tu propio email desde `onboarding@resend.dev`.
2. *API Keys* → crea una con permiso *Sending access*.

## 3. Firebase Hosting

1. Crea un proyecto en <https://console.firebase.google.com> (p. ej.
   `socios-idefic-staging`) y activa **Hosting**.
2. *Project settings → Service accounts* → *Generate new private key*
   (JSON). Basta con el rol **Firebase Hosting Admin**.

## 4. GitHub

*Settings → Environments → New environment* `staging`, con estos
**environment secrets**:

| Secreto | De dónde sale |
|---|---|
| `SUPABASE_DB_URL_STAGING` | Connection string (Session pooler) con contraseña |
| `SUPABASE_PROJECT_REF_STAGING` | Project ref |
| `SUPABASE_ACCESS_TOKEN` | Access token personal de Supabase |
| `SUPABASE_URL_STAGING` | Project URL |
| `SUPABASE_PUBLISHABLE_KEY_STAGING` | Publishable key |
| `FIREBASE_PROJECT_ID_STAGING` | Id del proyecto Firebase |
| `FIREBASE_SERVICE_ACCOUNT_STAGING` | JSON completo de la cuenta de servicio |

Opcional: en el environment, *Required reviewers* para aprobar cada
despliegue.

## 5. Primer despliegue

1. *Actions → Socios CI/CD → Run workflow* sobre la rama a desplegar, marcando
   las tres casillas. Orden real: migraciones y funciones en paralelo; la web
   cuando pasa `quality`.
2. Crea el primer superadmin (no hay registro público):
   1. *Authentication → Users → Add user*: tu email y una contraseña, con
      *Auto Confirm User*.
   2. *SQL Editor*: ejecuta `scripts/staging/bootstrap_platform_admin.sql`
      con tu email.
3. Entra en `https://<firebase-project>.web.app` con ese usuario: pasarás el
   primer acceso (datos y condiciones) y verás **Plataforma**.
4. Crea el club **IDEFIC** (código `IDEFIC`) con su administrador. Si el email
   del administrador no tiene cuenta queda «pendiente de alta» (todavía sin
   email automático, ver limitaciones). Para el piloto, puedes ser tú mismo el
   administrador o entrar como plataforma.
5. En IDEFIC → Configuración: logo y colores. En Socios: da de alta a alguien
   de prueba y comprueba que llega el email y que activa la cuenta.

## 6. Comprobaciones tras desplegar

- [ ] La web carga y el login muestra «Socios».
- [ ] `POST /auth/v1/signup` responde `signup_disabled`.
- [ ] El superadmin ve Plataforma y crea un club.
- [ ] Una invitación llega por email con la marca del club y el enlace abre
      «Activa tu cuenta» en `https://<firebase-project>.web.app/#/activar…`.
- [ ] El socio activado ve su club.

## Limitaciones conocidas en staging

- Los administradores de club creados desde Plataforma con un email sin cuenta
  no reciben email todavía (backlog).
- Texto de condiciones provisional (revisión legal antes del piloto).
- Sin pagos todavía (fases 5 y 6).

## Local

Valores en `[edge_runtime.secrets]` de `supabase/config.toml`; emails en
Mailpit (`http://127.0.0.1:54324`).
