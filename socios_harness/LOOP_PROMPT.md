# Autonomous Loop Prompt

Use este prompt como instrucción de arranque para cada iteración autónoma.

---

You are working on the Socios IDEFIC repository using the autonomous development harness.

Your job is to complete exactly one READY vertical slice (BOOTSTRAP-000 counts as one) unless it becomes genuinely blocked.

Before making changes:

1. Read `socios_harness/PROJECT_MEMORY.md`.
2. Read `socios_harness/CURRENT_STATE.md`.
3. Read `socios_harness/BACKLOG.md`.
4. Read `socios_harness/DECISIONS.md`.
5. Read `socios_harness/QUALITY_GATES.md`.
6. Read the latest file under `socios_harness/handovers/` if one exists.
7. Select the highest-priority READY task whose dependencies are DONE.
8. Read its specification under `socios_harness/tasks/`.
9. Follow `socios_harness/INIT_TASK.md`.
10. If the task touches `lib/presentation/`, read `DESIGN.md` (repo root).

During implementation:

- deliver the slice vertically end-to-end;
- preserve hexagonal boundaries;
- do not implement future slices unless technically inseparable;
- treat BDD scenarios as acceptance criteria;
- prefer constructor injection;
- never call Supabase directly from presentation;
- enforce sensitive rules server-side;
- add/update tests with the slice;
- make migrations reproducible;
- do not silently change product/architecture decisions;
- any new/changed widget in `lib/presentation/` follows `DESIGN.md`
  (semantic color tokens, theme text styles, shared components, tone of
  voice) instead of inventing ad-hoc styling.

If a structural decision is required:

- make the smallest safe decision consistent with project memory;
- create/update an ADR when appropriate;
- update `DECISIONS.md` and `PROJECT_MEMORY.md` only if the decision is stable and cross-cutting.

Before finishing:

1. Follow `socios_harness/QUALITY_GATES.md`.
2. Follow `socios_harness/CLOSE_TASK.md`.
3. Write a handover using `socios_harness/HANDOVER_TEMPLATE.md`.
4. Leave `CURRENT_STATE.md` and `BACKLOG.md` consistent.
5. Do not claim DONE if applicable tests or gates are failing.

If blocked:

- mark the task BLOCKED;
- document the exact blocker, evidence and smallest unblocking action;
- create a PARTIAL/BLOCKED handover;
- do not start another slice unless the blocker is external and the backlog explicitly contains an independent READY task.

Specific to Socios IDEFIC:

- Functional source of truth: `docs/PROPUESTA_FUNCIONAL_MVP.md` (RF/RN ids).
- If the next READY slice depends on a PROPOSED decision (e.g. ADR-001),
  mark it BLOCKED and take the next independent READY slice.
- Commit at the end of the slice (`feat(vs-0xx): ...`) and push only to the
  session's designated working branch.
- When no READY task remains, stop the loop and report pending decisions.
