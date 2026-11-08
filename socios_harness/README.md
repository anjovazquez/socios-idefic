# Socios IDEFIC — Autonomous Development Harness

Harness de desarrollo agentic, misma metodología que `xogalle_harness/`.

Objetivos: entender el proyecto sin el historial del chat, seleccionar trabajo
de forma determinista, entregar un vertical slice completo por loop, validar
arquitectura/BDD/tests/seguridad y dejar memoria y handover.

## Flujo

```text
BOOT → PROJECT_MEMORY → CURRENT_STATE → BACKLOG → DECISIONS → QUALITY_GATES
     → último handover → tarea READY → INIT_TASK → implementar → validar
     → CLOSE_TASK → handover → commit → NEXT LOOP
```

## Ficheros

| Fichero | Uso |
|---|---|
| `LOOP_PROMPT.md` | Prompt de arranque de cada iteración |
| `PRODUCT_AND_ARCHITECTURE_PLAN.md` | Plan por fases y arquitectura |
| `PROJECT_MEMORY.md` | Hechos estables |
| `CURRENT_STATE.md` | Snapshot operativo |
| `BACKLOG.md` | Slices, estados y dependencias |
| `DECISIONS.md`, `adr/` | Decisiones |
| `QUALITY_GATES.md` | Criterios para DONE |
| `INIT_TASK.md`, `CLOSE_TASK.md` | Protocolos de inicio/cierre |
| `WORKING_TASK.md` | Scratchpad del slice activo |
| `tasks/` | Especificación + BDD de cada slice |
| `handovers/` | Continuidad entre loops |

## Precedencia

1. ADR/decisión explícita más reciente. 2. `PROJECT_MEMORY.md`.
3. Especificación de la tarea. 4. `CURRENT_STATE.md`. 5. Handovers.
