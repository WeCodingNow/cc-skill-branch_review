---
name: branch-review
description: Review all code changes on the current git branch compared to master/main, producing a structured markdown review with categorized findings. Use this skill whenever the user asks to review a branch, do a code review, review an MR/PR, check changes on a branch, or find issues in their code. Also trigger when the user mentions "review" in the context of git branches, merge requests, or pull requests.
---

# Branch Code Review Skill

You are performing a thorough code review of all changes on the current git branch. You will examine every commit, read the changed files in full context, and produce a structured review document.

## Core Principles

**Reviews are standalone.** Every review must be fully self-contained. Never reference, carry over, or assume familiarity with previous reviews. A reader with zero context must understand every issue. If a similar issue appears in multiple places, explain it fully each time — do not say "same as above" or "see previous review."

**Reviews are fresh.** Do not rely on the results of any prior review. Re-examine all code independently. Prior reviews may have missed issues or had incorrect analysis — your job is to produce an accurate, complete review from scratch.

**Links must be clickable.** Every file path reference must be a markdown link that opens the file when clicked in VSCode or similar editors.

## Step 1: Identify the branch and diff range

1. Run `git branch --show-current` to get the current branch name.
2. Determine the base branch: run `git rev-parse --verify master` and `git rev-parse --verify main`. Use whichever exists (prefer `master`).
3. Run `git log --oneline <base>..HEAD` to see all commits on the branch.
4. Run `git diff --stat <base>...HEAD` to see which files changed and how much.
5. Summarize the scope: number of commits, files changed, lines added/removed.

## Step 2: Read the changed code in depth

For every file that changed:

1. Read the full file (not just the diff) to understand context. A diff shows what changed, but reviewing requires understanding the surrounding code.
2. Pay special attention to:
   - New modules, types, and traits — do they have sound designs?
   - Middleware, protocol handlers, and request processing — is the ordering correct?
   - Authentication and authorization code — are there timing attacks, credential leaks, or missing checks?
   - Error handling — are errors propagated correctly? Are internal details leaked to clients?
   - Concurrency — are locks held during I/O? Are there race conditions?
   - Configuration — are security-relevant settings actually enforced?
   - Tests — do they test the right things? Do they codify insecure behavior?
3. Also read files that are *referenced* by changed files (e.g., a new middleware is used in a router — read the router to check the integration).

## Step 3: Determine review number and create output directory

1. Check if `.claude/artifacts/review/<branch_name>/` exists.
2. Find the highest existing review number (0, 1, 2, ...). The new review number is one higher.
3. If no reviews exist, start at 0.
4. Create the output directory: `.claude/artifacts/review/<branch_name>/<review_number>/`

## Step 4: Write the review files

Write exactly these files in the output directory:

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

All file path references must be markdown links. The review files live at `.claude/artifacts/review/<branch_name>/<N>/`, which is 4 directory levels deep from the repo root. Use relative paths:

```
[crates/foo/src/bar.rs](../../../../crates/foo/src/bar.rs)
```

The `../../../../` prefix navigates from the review file up to the repo root.

Apply this to every file reference:
- In `**File:**` lines
- In code comments that reference other files
- In tables (make the file column clickable)

For files in the `test/` or `examples/` directories at the repo root, the format is the same: `[test/foo.py](../../../../test/foo.py)`.

## Self-contained explanations

Every issue explanation must stand alone. Do not:
- Reference other issues by ID and assume the reader knows the details ("same root cause as S1")
- Say "as mentioned above" or "see previous review"
- Use shorthand that requires reading another file in the review

If two issues share a root cause, explain the root cause in both. Repetition is better than forcing the reader to cross-reference.

## Review completeness checklist

Before finishing, verify:
- [ ] Every changed file has been read in full (not just the diff)
- [ ] Every file path reference is a clickable markdown link with correct relative path
- [ ] Every issue has: file link, line numbers, explanation, impact, and suggested fix
- [ ] No issue references another issue or prior review for its full explanation
- [ ] Security issues are separated from bugs
- [ ] The overview file has accurate counts and matches the detail files
- [ ] Review number is correct (incremented from any existing reviews)
