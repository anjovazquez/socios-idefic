# CLOSE_TASK — Protocolo de cierre

Una tarea puede cerrarse solo después de pasar `QUALITY_GATES.md`.

## 1. Validar

Ejecutar todos los checks aplicables y registrar el resultado en `WORKING_TASK.md`.

## 2. Revisar diff

Confirmar:

- no hay cambios accidentales;
- no se ha implementado scope futuro;
- nombres y límites reflejan el dominio;
- no hay secretos o credenciales.

## 3. Actualizar backlog

```text
IN_PROGRESS → DONE
```

Promover dependientes desbloqueadas:

```text
TODO → READY
```

## 4. Actualizar memoria

Actualizar `PROJECT_MEMORY.md` solo si apareció información estable.

Actualizar `DECISIONS.md` / ADR si hubo decisiones relevantes.

## 5. Actualizar estado

`CURRENT_STATE.md` debe indicar:

- última tarea completada;
- siguiente tarea READY recomendada;
- estado de milestones;
- bloqueos;
- estado de infraestructura.

## 6. Crear handover

Usar `HANDOVER_TEMPLATE.md` y guardar en:

```text
handovers/YYYY-MM-DD_HHMM_<TASK-ID>.md
```

## 7. Limpiar Working Task

Restablecer `WORKING_TASK.md` a `IDLE` solo después de crear el handover.
