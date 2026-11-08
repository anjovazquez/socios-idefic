# Memory Policy

## PROJECT_MEMORY.md

Long-lived facts and constraints only.

Examples:
- selected architecture;
- selected stack;
- domain invariants;
- stable product decisions.

Never:
- raw logs;
- temporary TODOs;
- file-by-file implementation notes;
- transient errors.

## CURRENT_STATE.md

Current operational snapshot.

Examples:
- current milestone;
- active/last task;
- next recommended task;
- global blockers;
- infra readiness.

## WORKING_TASK.md

Ephemeral scratchpad for the active task.

Examples:
- scope;
- execution plan;
- findings;
- test status;
- local blockers.

## handovers/

Historical continuity between loops.

A handover answers:

- what changed?
- what passed?
- what failed?
- what remains?
- where exactly should the next execution resume?

## DECISIONS / ADR

Use for decisions, not progress.
