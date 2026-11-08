# Login con Google (VS-002)

## Cómo funciona

- Supabase Auth tiene el registro público cerrado (`enable_signup = false`).
  Una cuenta de Google cuyo email **no** existe en la plataforma se rechaza
  en el servidor (`signup_disabled`) y la app muestra «Tu club todavía no te
  ha dado de alta con ese email». Nunca se crea usuario ni pertenencia a club.
- Si el email ya existe (dado de alta por un club), Supabase vincula la
  identidad de Google a ese usuario (mismo email verificado): mismas
  credenciales, mismos clubes.
- Web: el proveedor vuelve al origen de la app. Móvil: deep link
  `es.idefic.socios://login-callback` (Android `intent-filter`, iOS
  `CFBundleURLTypes`).

## Configurar credenciales (lo hace el usuario)

1. Google Cloud Console → APIs y servicios → Credenciales → «ID de cliente de
   OAuth» de tipo **Aplicación web**.
2. URI de redirección autorizada:
   - local: `http://127.0.0.1:54321/auth/v1/callback`
   - staging/producción: `https://<project-ref>.supabase.co/auth/v1/callback`
3. Local: exportar antes de `npx supabase start`:
   ```bash
   export SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=...
   export SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=...
   ```
4. Staging: Dashboard de Supabase → Authentication → Providers → Google, y
   añadir `es.idefic.socios://login-callback` y la URL web a *Redirect URLs*.

Nunca commitear el client secret.

## Prueba manual pendiente

Con credenciales configuradas:

- [ ] `ana@...` (dada de alta) entra con Google y ve sus clubes.
- [ ] Una cuenta Google no dada de alta ve el mensaje de alta pendiente.
- [ ] Ana entra después con contraseña y ve la misma cuenta.
