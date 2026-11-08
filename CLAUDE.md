# Socios IDEFIC — Agent Instructions

Plataforma multi-club de gestión de socios (baloncesto amateur). Especificación:
`docs/PROPUESTA_FUNCIONAL_MVP.md`.

El harness de desarrollo autónomo vive en `socios_harness/`. Antes de modificar código, leer en orden:

1. `socios_harness/LOOP_PROMPT.md`
2. `socios_harness/PROJECT_MEMORY.md`
3. `socios_harness/CURRENT_STATE.md`
4. `socios_harness/BACKLOG.md`
5. `socios_harness/DECISIONS.md`
6. `socios_harness/QUALITY_GATES.md`
7. último handover en `socios_harness/handovers/`
8. tarea seleccionada en `socios_harness/tasks/`
9. `DESIGN.md` si la tarea toca `lib/presentation/`

Completar exactamente **un vertical slice por loop**, siguiendo `INIT_TASK.md` y `CLOSE_TASK.md`.

## Arquitectura

Hexagonal: `presentation → application → domain ← infrastructure`.
Widget → ViewModel (ChangeNotifier) → Use case → Port → Adapter → Supabase.
Sin lógica de negocio/persistencia en ViewModels. RLS en todo lo protegido.

## Seguridad

Sin aprobación explícita: nada de force push, `git reset --hard`, `git clean`,
`supabase link`, `supabase db push`, despliegues, cambios de credenciales ni
operaciones contra producción/remoto.
