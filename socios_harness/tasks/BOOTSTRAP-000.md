# BOOTSTRAP-000 — Bootstrap Flutter + Supabase local + CI

Status: READY
Milestone: Bootstrap

## Goal

Dejar el repositorio listo para que el loop pueda empezar VS-001. Solo setup técnico.

## In scope

- Proyecto Flutter (`flutter create --org es.idefic --project-name socios_idefic --platforms web,android,ios .`), Flutter 3.35.1 fijado en `.fvmrc`.
- Dependencias iniciales: `provider`, `get_it`, `go_router`, `supabase_flutter`. Nada más.
- Estructura hexagonal vacía: `lib/{bootstrap,core,domain,application,infrastructure,presentation}`.
- `lib/core/config/app_config.dart` con `SUPABASE_URL` / `SUPABASE_ANON_KEY` vía `String.fromEnvironment` y `validate()`.
- `lib/bootstrap/{bootstrap.dart,service_locator.dart}`, `main.dart` que inicializa Supabase y arranca `SociosApp` con un router mínimo (pantalla placeholder).
- Supabase local: `package.json` con `supabase` como devDependency, `npx supabase init`, `config.toml` con:
  - `auth.enable_signup = false` (RN-001) — los usuarios se crean por invitación/admin API;
  - `site_url` y `additional_redirect_urls` para web local;
  - proveedor Google declarado pero deshabilitado (se activa en VS-002).
- `supabase/seed.sql` vacío (comentado).
- Primer test pgTAP trivial en `supabase/tests/000_smoke.sql`.
- Scripts `scripts/flutter-{pub-get,format,analyze,test}.sh` (usan `fvm` si existe) y `scripts/supabase-{start,reset,test}.sh`.
- `.github/workflows/ci.yml`: job `quality` (format, analyze, test con Flutter 3.35.1) y job `sql-tests` (`supabase start` + `supabase test db`).
- `.gitignore`, `.env.example`, `analysis_options.yaml` (flutter_lints).
- Smoke widget test de arranque con config inyectada.

## Out of scope

- Login, tablas de dominio, RLS de producto, pagos, emails, despliegues.

## BDD

```gherkin
Feature: Repositorio preparado

  Scenario: Calidad Flutter en verde
    Given el proyecto Flutter recién creado
    When ejecuto format, analyze y test
    Then todos terminan sin errores

  Scenario: Supabase local reproducible
    Given Docker disponible
    When ejecuto "supabase db reset" y "supabase test db"
    Then la base se crea desde cero y el test smoke pasa

  Scenario: Sin registro público
    Given la configuración local de Supabase
    Then "enable_signup" es false
```

## Done when

Gates 5 y 6 en verde (o Gate 6 documentado como pendiente si no hay Docker y CI lo cubre), harness actualizado, VS-001 READY.
