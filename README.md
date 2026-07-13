# branch-review

A [Claude Code](https://claude.com/claude-code) skill that defines what a
**branch review** is — the diff of the current branch against its base
branch, never the whole codebase — and the expected output format for one.

It does *not* perform the review itself; that's the built-in `/code-review`,
`/security-review`, or `/review` tools' job (dimensions, effort, subagents,
`--comment`/`--fix`). This skill only pins down scope and format, so those
tools' output lands somewhere consistent and re-discoverable.

## What it provides

1. **`scripts/review-diff-range.sh`** — resolves the base branch (tries
   `dev` → `main` → `master`, matching the worktree → dev → main
   convention) and prints the commit log and diffstat for the range.
2. **Output format** (documented in `SKILL.md`): a structured review
   written **directly under `.spec/review/`** — one review per branch, so no
   numbered subdirectory (and no branch-name segment, since `.spec/` is
   already branch-scoped) — split into:
   - `00-overview.md` — summary, stats, and a severity/issue-count table
   - `01-bugs.md` — logic errors, missing functionality, contract violations
   - `02-refactoring.md` — duplication, naming, architecture suggestions
   - `03-security.md` — auth/authz issues, credential leaks, insecure defaults
   - `04-style-docs.md` — typos, dead code, doc/style issues
   - `.spec/review/TODO.md` — tracks this review's open items
3. **A `Stop` hook** (`hooks/ensure-review-specs.sh`, wired via frontmatter):
   while the skill is active, if the repo has no `.spec/review/` by the time
   Claude finishes, it nudges to write the findings there first. Absorbed from
   the former standalone `cc-hook-review-specs` project.

Each issue includes a severity (CRITICAL/HIGH/MEDIUM/LOW), a clickable
relative markdown link to the affected file/lines, an explanation, impact,
and a suggested fix. Reviews are self-contained (no references to prior
reviews).

## Installation

Installed by symlinking into your skills directory:

```bash
ln -s /path/to/cc-skill-branch_review ~/.claude/skills/branch-review
```

It's **manual-invoke-only** (`disable-model-invocation: true`): the model
won't auto-load it — you run `/branch-review` explicitly. That's also what
scopes the `Stop` hook to only fire during a review session you started.

## Usage

Run `/branch-review` to pull in the scope/format convention (and activate the
`Stop` hook), then drive the actual review with a built-in tool
(`/code-review`, `/security-review`, `/review`). `scripts/review-diff-range.sh`
can also be run directly to resolve a branch review's diff range.

## Files

- [`SKILL.md`](./SKILL.md) — the skill definition (frontmatter + scope/format instructions).
- [`scripts/review-diff-range.sh`](./scripts/review-diff-range.sh) — resolves base branch + diff range.
- [`hooks/ensure-review-specs.sh`](./hooks/ensure-review-specs.sh) — `Stop` hook that nudges to write findings into `.spec/review/`.
