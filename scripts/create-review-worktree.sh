#!/usr/bin/env bash
#
# create-review-worktree.sh — creates the review worktree for the current
# feature branch and prints its path/branch.
#
# Must be run from inside the feature branch's own worktree. The review
# worktree is always created under the *main* repository's
# .claude/worktrees/ (resolved via --git-common-dir, which always points at
# the shared main .git dir regardless of which worktree you're in) — never
# relative to CWD, which would nest it inside the feature worktree's own
# .claude dir instead.
set -euo pipefail

branch="$(git branch --show-current)"
if [ -z "$branch" ]; then
  echo "error: not on a branch (detached HEAD?)" >&2
  exit 1
fi

name="$(sed 's/^worktree-//' <<<"$branch" | tr '/+' '--')"

root="$(git rev-parse --path-format=absolute --git-common-dir)"
root="${root%/.git}"

path="${root}/.claude/worktrees/review-${name}"
review_branch="review/${name}"

git worktree add "$path" -b "$review_branch"

echo "path=$path"
echo "branch=$review_branch"
