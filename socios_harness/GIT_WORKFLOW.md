# Git Workflow for Autonomous Loops

- Local (Windows/WSL): `main` + `feature/vs-0xx-<slug>`, PR por slice o por milestone.
- Claude Code cloud: trabajar en la rama designada de la sesión; un commit por slice (o varios coherentes) y `git push -u origin <rama>` al cerrar.
- Estilo: `feat(vs-003): superadmin can create clubs`, `test(vs-003): cover clubs RLS`, `chore(harness): ...`.
- Nunca: force push, reescribir historia ajena, `supabase link`/`db push` ni despliegues sin aprobación explícita.
