# Quality Gates

Una tarea no puede marcarse `DONE` si falla un gate aplicable.

## Entornos soportados

| Entorno | Flutter | Supabase/Docker |
|---|---|---|
| Local Windows + WSL2 (como Xogalle) | `fvm flutter` en Windows (delegar vía `powershell.exe` desde WSL) | Docker Engine en WSL2, `npx supabase` |
| Claude Code cloud (Linux) | Flutter 3.35.1 instalado en `$HOME/flutter` (ver BOOTSTRAP-000) o `fvm` si existe | `dockerd` local si está disponible; si no, Gate 6 queda documentado como pendiente |

Preparación en una sesión cloud nueva (el contenedor es efímero):

```bash
curl -sSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.35.1-stable.tar.xz | tar -xJ -C $HOME
export PATH=$HOME/flutter/bin:$PATH
git config --global --add safe.directory '*'
(dockerd > /tmp/dockerd.log 2>&1 &)   # luego: docker ps
npm ci
npx supabase start -x studio,imgproxy,vector,logflare,edge-runtime,realtime,pooler,postgres-meta
```

Los wrappers `scripts/*.sh` eligen `fvm flutter` si `fvm` existe y `flutter` si no.
Flutter fijado: **3.35.1** (`.fvmrc`).

---

## Gate 1 — BDD
- Todos los escenarios del slice cubiertos (test automatizado o verificación manual documentada).
- Lo pospuesto queda fuera de scope **antes** de implementar.

## Gate 2 — Arquitectura
- `domain` sin Flutter/Supabase/Provider/GetIt/SDKs de pago.
- `application` sin Supabase/Flutter.
- GetIt solo en `lib/bootstrap/`.
- UI sin `SupabaseClient`.
- Sin repositorios genéricos innecesarios.

## Gate 2.1 — UI/UX (`DESIGN.md`, desde VS-004)
- Colores desde el tema del club activo y tokens semánticos; nada de `Colors.*`/hex sueltos.
- Texto con `Theme.of(context).textTheme.*`.
- Reutilizar componentes compartidos; documentar patrones nuevos en `DESIGN.md`.
- Copys en español, segunda persona, sin jerga técnica.

## Gate 3 — Tests
- Unit tests de domain/use cases; mappers; widget tests de comportamiento relevante.
- pgTAP para RLS/RPC de cada tabla o función nueva.

## Gate 4 — Seguridad
- RLS habilitada y policy por operación necesaria; aislamiento entre clubes probado.
- Sin service role ni claves de proveedor en el cliente.
- Cobros, avisos y validez calculados en servidor.
- Operaciones atómicas en una sola RPC.
- La validación pública del QR solo expone los campos de RF-020.

## Gate 5 — Calidad Flutter
```bash
./scripts/flutter-format.sh   # dart format --set-exit-if-changed .
./scripts/flutter-analyze.sh  # flutter analyze
./scripts/flutter-test.sh     # flutter test
```

## Gate 6 — Base de datos / Supabase local
Si el slice toca schema, RLS, RPC, triggers o migraciones:
```bash
npx supabase start
npx supabase db reset
npx supabase test db
```
- Migraciones reproducibles desde cero; seed separada de schema; fechas de prueba relativas a `now()`.
- Tests pgTAP: `begin; select plan(N); …; select * from finish(); rollback;`.
- Nunca `supabase link`, `db push` ni `functions deploy` sin aprobación.
- Si Docker no está disponible en el entorno, el gate queda **PENDIENTE** (no superado): documentarlo en handover y `CURRENT_STATE`; la CI (`sql-tests`) lo cubre al hacer push.

## Gate 7 — Scope
- Un slice por loop; nada de features futuras; abstracciones tras el segundo caso real.

## Gate 8 — Handover
- `CURRENT_STATE`, `BACKLOG`, memoria/ADR si aplica, handover y commit.
