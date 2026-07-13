---
name: branch-review
description: Defines what a "branch review" is (the diff of the current branch against its base branch, not the whole codebase) and the expected output format for one — review files written directly under `.spec/review/` (one review per branch), severity-tagged findings split across files, clickable relative links, self-contained explanations. Use this as a reference for review scope and output format; for the actual review process (dimensions, effort, subagents), use the built-in `/code-review`, `/security-review`, or `/review`.
disable-model-invocation: true
allowed-tools:
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git branch *)
  - Bash(git rev-parse *)
  - Bash(ls *)
  - Bash(test *)
  - Bash(echo *)
  - Bash(*/.claude/skills/branch-review/scripts/review-diff-range.sh)
hooks:
  Stop:
    - hooks:
        - type: command
          command: ${HOME}/.claude/skills/branch-review/hooks/ensure-review-specs.sh
---

# Branch review: scope and output format

A **branch review** is scoped to the diff between the current branch and
its base branch — never the whole codebase as it stands on the branch.
Reviewing the whole codebase requires saying so explicitly; it's a
different, much larger task than a branch review.

**One branch = one review.** A branch review lives on its own review branch,
and its findings go in that branch's `.spec/review/`. Do the review on a dedicated
branch; creating that branch is the `feature-branching` skill's job, not this one.

## This review

Current branch: !`git branch --show-current`

Existing `.spec/review/`: !`test -d .spec/review && echo "present — a review already exists on this branch; you're revising it" || echo "none yet — this will be a fresh review"`

Resolve the base branch and the diff range with:

```sh
${CLAUDE_SKILL_DIR}/scripts/review-diff-range.sh
```

This tries `dev` → `main` → `master` in that order (the worktree → dev →
main convention — `dev` is the shared integration branch and almost always
the right diff target) and prints the resolved base, the commit log, and a
diffstat for the range.

For the actual review process — what to look at, how much effort to spend,
whether to fan out subagents per dimension — that's the built-in
`/code-review` / `/security-review` / `/review` tools' job. This skill only
defines scope and the output format below.

## Core Principles

**Reviews are standalone.** Every review must be fully self-contained. Never reference, carry over, or assume familiarity with previous reviews. A reader with zero context must understand every issue. If a similar issue appears in multiple places, explain it fully each time — do not say "same as above" or "see previous review."

**Reviews are fresh.** Do not rely on the results of any prior review. Re-examine all code independently. Prior reviews may have missed issues or had incorrect analysis — your job is to produce an accurate, complete review from scratch.

**Links must be clickable.** Every file path reference must be a markdown link that opens the file when clicked in VSCode or similar editors.

## Output location and format

Write the review **directly under `.spec/review/`** in the repo root. The files
below live at `.spec/review/00-overview.md`, `.spec/review/01-bugs.md`, and so on.
`.spec/` is scoped to this branch — tracked in git on the branch, dropped before
landing to `dev` per global CLAUDE.md's "Ephemeral specs" rule.

Maintain `.spec/review/TODO.md` tracking this review's open items, so
unresolved findings are easy to pick back up.

Write exactly these files under `.spec/review/`:

### `00-overview.md`

```markdown
# Code Review: <branch_name> vs <base_branch>

**Reviewer:** Claude Code\
**Date:** <YYYY-MM-DD>\
**Scope:** Full <branch_name> branch relative to <base_branch>\
**Stats:** <N> commits, <M> files changed, ~<X> additions, ~<Y> deletions

## Summary

<2-3 paragraph summary of what the branch introduces. Cover the main features, the architecture, and call out anything well-done.>

However, there are several issues that should be addressed.

## Issue Summary

| Severity    | Count | Key Issues |
|-------------|-------|------------|
| CRITICAL    | <N>   | <comma-separated brief descriptions> |
| HIGH        | <N>   | <comma-separated brief descriptions> |
| MEDIUM      | <N>   | <comma-separated brief descriptions> |
| LOW         | <N>   | <comma-separated brief descriptions> |

Detailed findings are in the following files:
- [Bug Issues](./01-bugs.md)
- [Refactoring Suggestions](./02-refactoring.md)
- [Security Issues](./03-security.md)
- [Style & Documentation Issues](./04-style-docs.md)
```

### `01-bugs.md`

Logic errors, missing functionality, incorrect behavior, contract violations, silent failures, misleading error messages.

### `02-refactoring.md`

Code duplication, naming issues, missing features that aren't bugs but would improve the codebase, architecture suggestions, missing background tasks.

### `03-security.md`

All security-relevant issues: authentication bypasses, credential leaks, timing attacks, session vulnerabilities, missing security checks, insecure defaults, etc.

### `04-style-docs.md`

Typos, dead code, doc comment errors, missing Debug implementations, style inconsistencies.

## How to write each issue

Every issue must follow this structure:

```markdown
## <ID>. <SEVERITY> -- <Short title>

**File:** [<repo_relative_path>](<relative_path_from_review_file>), lines <start>-<end>

<Explanation of the problem. Include relevant code snippets.>

**Impact:** <What goes wrong if this isn't fixed.>

**Suggested fix:**
<Code or description of the fix.>
```

### Severity guidelines

- **CRITICAL** — Security vulnerabilities, data loss, complete feature breakage. Must fix before merge.
- **HIGH** — Significant bugs, security weaknesses, incomplete security features. Should fix before merge.
- **MEDIUM** — Moderate bugs, missing safeguards, unclear behavior. Should fix soon.
- **LOW** — Typos, dead code, doc errors, style issues. Nice to fix.

### Issue IDs

Use prefixed sequential IDs per file:
- Bugs: B1, B2, B3, ...
- Refactoring: R1, R2, R3, ...
- Security: S1, S2, S3, ...
- Style/Docs: (use table format, no IDs needed)

## Clickable link format

All file path references must be markdown links. Review files live at
`.spec/review/`, which is 2 directory levels deep from the repo root
(`.spec` → `review`). Use relative paths:

```
[crates/foo/src/bar.rs](../../crates/foo/src/bar.rs)
```

The `../../` prefix navigates from the review file up to the repo root.

Apply this to every file reference:
- In `**File:**` lines
- In code comments that reference other files
- In tables (make the file column clickable)

For files in the `test/` or `examples/` directories at the repo root, the format is the same: `[test/foo.py](../../test/foo.py)`.

## Self-contained explanations

Every issue explanation must stand alone. Do not:
- Reference other issues by ID and assume the reader knows the details ("same root cause as S1")
- Say "as mentioned above" or "see previous review"
- Use shorthand that requires reading another file in the review

If two issues share a root cause, explain the root cause in both. Repetition is better than forcing the reader to cross-reference.

## Review completeness checklist

Before finishing, verify:
- [ ] Every changed file has been read in full (not just the diff)
- [ ] Every file path reference is a clickable markdown link with the correct `../../` relative path
- [ ] Every issue has: file link, line numbers, explanation, impact, and suggested fix
- [ ] No issue references another issue or prior review for its full explanation
- [ ] Security issues are separated from bugs
- [ ] The overview file has accurate counts and matches the detail files
- [ ] `.spec/review/TODO.md` is updated
- [ ] Review files are written directly under `.spec/review/`
