# INIT_TASK — Protocolo de inicio

Antes de modificar código:

## 1. Cargar contexto

Leer, en este orden:

- `PROJECT_MEMORY.md`
- `CURRENT_STATE.md`
- `BACKLOG.md`
- `DECISIONS.md`
- `QUALITY_GATES.md`
- último handover disponible
- fichero de la tarea seleccionada en `tasks/`
- `../DESIGN.md` (si existe) si la tarea toca `lib/presentation/`

## 2. Seleccionar tarea

Elegir la primera tarea `READY` de mayor prioridad.

No seleccionar una tarea si:

- tiene dependencias no completadas;
- hay otra tarea `IN_PROGRESS` sin handover que explique por qué quedó abierta;
- requiere una decisión de producto no resuelta y no puede aplicarse un default seguro.

## 3. Declarar scope

Antes de implementar, escribir en `WORKING_TASK.md`:

```text
Task ID:
Goal:
In scope:
Out of scope:
BDD scenarios:
Expected files/areas touched:
Risks:
```

## 4. Verificar repo

- `git status`
- rama actual
- tests actuales
- analyzer/linter actual
- migraciones pendientes

No sobrescribir cambios ajenos no relacionados.

## 5. Crear plan mínimo

Máximo 5-7 pasos, siempre orientados a entregar el slice completo.

Evitar planes horizontales tipo "crear todas las entidades".

## 6. Marcar tarea

Actualizar `BACKLOG.md`:

```text
READY → IN_PROGRESS
```

Actualizar `CURRENT_STATE.md` con la tarea activa.
