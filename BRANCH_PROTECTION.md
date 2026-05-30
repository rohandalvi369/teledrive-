# Branch Protection Rules

This project follows the **Five Professional Development Rules** (Anti-Vibe-Coding + Pre-Commit Checklist). This document covers **Rule 5: Feature branches + PRs — no direct pushes to main**.

## Workflow

```
main (production-ready)
  └── feat/feature-name  (new feature)
  └── fix/bug-description (bug fix)
  └── chore/task-name     (tooling, config)
  └── refactor/area       (code restructuring)
       ↓
  Pull Request → CI checks → merge to main
```

## Branch Naming

- `feat/<short-description>` — new features
- `fix/<short-description>` — bug fixes
- `chore/<short-description>` — tooling, config, dependency updates
- `refactor/<short-description>` — code restructuring
- `docs/<short-description>` — documentation only

Use hyphens, lowercase. Examples:
- `feat/trash-restore`
- `fix/upload-hang`
- `chore/update-gramjs`
- `refactor/dashboard-split`

## Rules

1. **No direct pushes to `main`**. All changes must go through a feature branch and PR.
2. **Keep branches short-lived** (ideally < 1 day, max 3 days). Long-lived branches diverge and cause merge conflicts.
3. **One logical change per branch**. If you find yourself doing two unrelated things, split into two branches.
4. **Rebase before PR** to keep history linear: `git fetch origin && git rebase origin/main`
5. **PR title must follow conventional commits** (same as commit messages): `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`.
6. **PR description should explain what and why**, not just list the files changed.
7. **Squash merge** to main to keep a clean history.

## Git Hooks (enforced locally)

The repo has husky hooks at `.husky/`:
- `pre-commit`: Blocks commits containing `console.log`, `debugPrint`, or hardcoded API credentials (`33624340`, `e91bb3030342033d159f40937522b046`).
- `commit-msg`: Validates conventional commit format via commitlint.

## CI Checks

The CI workflow (`.github/workflows/main.yml`) runs:
- Desktop: `npx tsc -b` (noUnusedLocals)
- Mobile: `dart analyze`
- Mobile: `flutter build apk --debug`

All must pass before merging.

## Example PR Flow

```bash
git checkout -b feat/trash-restore

# make changes, commit with conventional messages
git add -A
git commit -m "feat: add restore from trash button to FileCard"

# rebase on latest main
git fetch origin
git rebase origin/main

# push and create PR
git push -u origin feat/trash-restore
gh pr create --title "feat: add restore from trash" --body "Adds restore button to FileCard and /trash/restore endpoint."
```
