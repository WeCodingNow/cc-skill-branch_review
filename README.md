# branch-review

A [Claude Code](https://claude.com/claude-code) skill that reviews all code changes on the current git branch compared to `master`/`main`, producing a structured, multi-file markdown code review.

## What it does

When invoked, the skill instructs Claude to:

1. Detect the current branch and diff it against `master` or `main` (whichever exists).
2. Read every changed file in full (not just the diff) for proper context, including files referenced by the changes.
3. Write a structured review to `.claude/artifacts/review/<branch_name>/<review_number>/`, split into:
   - `00-overview.md` — summary, stats, and a severity/issue-count table
   - `01-bugs.md` — logic errors, missing functionality, contract violations
   - `02-refactoring.md` — duplication, naming, architecture suggestions
   - `03-security.md` — auth/authz issues, credential leaks, insecure defaults
   - `04-style-docs.md` — typos, dead code, doc/style issues

Each issue includes a severity (CRITICAL/HIGH/MEDIUM/LOW), a clickable relative markdown link to the affected file/lines, an explanation, impact, and a suggested fix. Reviews are self-contained (no references to prior reviews) and numbered incrementally so repeated reviews of the same branch don't overwrite each other.

## Installation

Copy this skill into your Claude Code skills directory:

```bash
cp -r cc-skill-branch_review ~/.claude/skills/branch-review
```

Or symlink it if you're iterating on the skill itself:

```bash
ln -s /path/to/cc-skill-branch_review ~/.claude/skills/branch-review
```

## Usage

From within a git repository, in Claude Code, ask Claude to review the branch, e.g.:

- "review this branch"
- "do a code review of my current branch"
- "review this PR/MR"

Claude Code will pick up the `branch-review` skill automatically (see `SKILL.md`'s `description` for the trigger phrases), and the review output will be written under `.claude/artifacts/review/<branch>/<N>/` in the target repository.

## Files

- [`SKILL.md`](./SKILL.md) — the skill definition consumed by Claude Code (frontmatter + instructions).
